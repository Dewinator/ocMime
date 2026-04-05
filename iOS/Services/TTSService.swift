import AVFoundation
import Foundation

@MainActor
final class TTSService: NSObject, ObservableObject {

    @Published var isSpeaking = false
    @Published var currentLocale: String = "de-DE"

    private let synthesizer = AVSpeechSynthesizer()
    private weak var audioCoordinator: AudioSessionCoordinator?
    var onSpeakingChanged: ((Bool) -> Void)?

    init(audioCoordinator: AudioSessionCoordinator? = nil) {
        self.audioCoordinator = audioCoordinator
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    func speak(text: String, locale: String = "de-DE", rate: Double = 0.5) {
        synthesizer.stopSpeaking(at: .immediate)
        audioCoordinator?.activateSpeaking()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        utterance.rate = Float(min(max(rate, 0), 1))
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentLocale = locale
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioCoordinator?.deactivateIfIdle(expected: .speaking)
    }

    private func configureAudioSession() {
        // Defer activation until actual speech starts so STT can own the session while idle.
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
            onSpeakingChanged?(true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onSpeakingChanged?(false)
            audioCoordinator?.deactivateIfIdle(expected: .speaking)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onSpeakingChanged?(false)
            audioCoordinator?.deactivateIfIdle(expected: .speaking)
        }
    }
}
