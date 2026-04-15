import AVFoundation
import Foundation
import Speech

@MainActor
final class STTService: ObservableObject {

    @Published var isListening = false
    @Published var lastTranscript: String = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastError: String?

    var onTranscript: ((String, Bool) -> Void)?  // (text, isFinal)

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var locale: String = "de-DE"
    private weak var audioCoordinator: AudioSessionCoordinator?
    private var isRestarting = false
    private var silenceTimer: Timer?
    private var pendingPartial: String = ""
    private var hasEmittedFinal = false
    private let silenceTimeout: TimeInterval = 1.2

    init(locale: String = "de-DE", audioCoordinator: AudioSessionCoordinator? = nil) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        self.audioCoordinator = audioCoordinator
    }

    // MARK: - Authorization

    func requestAuthorization() {
        Task { [weak self] in
            let status = await Self.awaitAuthorization()
            await MainActor.run {
                self?.authorizationStatus = status
            }
        }
    }

    private nonisolated static func awaitAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    // MARK: - Start / Stop

    func startListening() {
        guard !isListening else { return }
        guard authorizationStatus == .authorized else {
            lastError = "Speech recognition not authorized"
            return
        }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            lastError = "Speech recognizer not available"
            return
        }

        do {
            try startRecognitionSession()
            isListening = true
            lastError = nil
        } catch {
            lastError = "Start failed: \(error.localizedDescription)"
            isListening = false
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        audioCoordinator?.deactivateIfIdle(expected: .listening)
    }

    func setLocale(_ localeId: String) {
        let wasListening = isListening
        if wasListening { stopListening() }
        self.locale = localeId
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))
        if wasListening { startListening() }
    }

    // MARK: - Recognition Session

    private func startRecognitionSession() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        pendingPartial = ""
        hasEmittedFinal = false

        audioCoordinator?.activateListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }

        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                var needsRestart = false

                if let result {
                    let text = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    self.lastTranscript = text
                    self.pendingPartial = text
                    self.onTranscript?(text, isFinal)
                    if isFinal {
                        self.hasEmittedFinal = true
                        self.silenceTimer?.invalidate()
                        self.silenceTimer = nil
                        needsRestart = true
                    } else if !text.isEmpty {
                        // Reset silence window — we're still hearing speech.
                        self.scheduleSilenceEnd()
                    }
                }

                if let error {
                    let nsError = error as NSError
                    // If the recognizer bailed with a transcript still
                    // pending, promote it to final now so the bridge can
                    // forward it to the agent instead of dropping it.
                    if !self.hasEmittedFinal, !self.pendingPartial.isEmpty {
                        self.onTranscript?(self.pendingPartial, true)
                        self.hasEmittedFinal = true
                    }
                    // Code 1110 = "No speech detected" — silence, not a bug.
                    if nsError.code != 1110 {
                        self.lastError = error.localizedDescription
                    }
                    needsRestart = true
                }

                if needsRestart { self.restartSession() }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        Self.installTap(on: inputNode, format: recordingFormat, request: request)

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Force-finalise the recognition after a short stretch of silence.
    /// On-device SFSpeechRecognizer does not emit `isFinal=true` reliably
    /// on end-of-speech, so we call `endAudio()` ourselves once the partial
    /// results stop streaming. The recognizer responds with a proper final.
    private func scheduleSilenceEnd() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.silenceTimer = nil
                self.recognitionRequest?.endAudio()
            }
        }
    }

    /// Install the audio tap from a nonisolated scope so the block closure is
    /// not inferred as @MainActor. The audio realtime thread invokes it, which
    /// otherwise trips Swift 6's executor-isolation assertion.
    private nonisolated static func installTap(
        on node: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    /// Restart recognition session (Apple limits sessions to ~1 minute).
    /// Guarded: repeat callbacks (final + error in the same turn) collapse
    /// into a single restart instead of stacking tear-down/start-up pairs.
    private func restartSession() {
        guard isListening, !isRestarting else { return }
        isRestarting = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                guard let self else { return }
                self.isRestarting = false
                guard self.isListening else { return }
                do {
                    try self.startRecognitionSession()
                } catch {
                    self.lastError = "Restart failed: \(error.localizedDescription)"
                    self.isListening = false
                }
            }
        }
    }
}
