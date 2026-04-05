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

    init(locale: String = "de-DE", audioCoordinator: AudioSessionCoordinator? = nil) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        self.audioCoordinator = audioCoordinator
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
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

        audioCoordinator?.activateListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true  // Force on-device

        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    self?.lastTranscript = text
                    self?.onTranscript?(text, isFinal)

                    if isFinal {
                        self?.restartSession()
                    }
                }

                if let error {
                    // Session expired or error — restart
                    let nsError = error as NSError
                    // Code 1110 = "No speech detected" — normal, just restart
                    if nsError.code != 1110 {
                        self?.lastError = error.localizedDescription
                    }
                    self?.restartSession()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        // Capture `request` directly — avoids crossing the @MainActor isolation
        // boundary from the audio thread that drives the tap callback.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [request] buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    /// Restart recognition session (Apple limits sessions to ~1 minute)
    private func restartSession() {
        guard isListening else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        audioCoordinator?.deactivateIfIdle(expected: .listening)

        // Brief pause then restart
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if isListening {
                do {
                    try startRecognitionSession()
                } catch {
                    lastError = "Restart failed: \(error.localizedDescription)"
                    isListening = false
                }
            }
        }
    }
}
