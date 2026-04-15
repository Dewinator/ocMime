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
        utterance.voice = Self.preferredVoice(for: locale)
        // Map the 0…1 slider around AVSpeechUtteranceDefaultSpeechRate so the
        // midpoint (0.5) lands on natural speed. Using the raw slider value
        // as `rate` hit close to the maximum on iOS 17+ and sounded hectic.
        let clamped = Float(min(max(rate, 0), 1))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (0.5 + clamped)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        currentLocale = locale
        synthesizer.speak(utterance)
    }

    /// Pick the best voice installed on the device for the requested locale,
    /// preferring Siri/Personal/Neural voices over the generic 2010-era TTS
    /// that `AVSpeechSynthesisVoice(language:)` returns by default. Users can
    /// install premium voices via Settings → Accessibility → Spoken Content
    /// → Voices; we'll pick those automatically once downloaded.
    private static func preferredVoice(for locale: String) -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let target = locale.lowercased()
        let prefix = String(target.prefix(2))

        // Narrow to the requested language; prefer exact region match (de-DE)
        // but fall back to language-only (de-*) so a user with "de-AT" Siri
        // still beats a generic "de-DE" legacy voice.
        let exact = all.filter { $0.language.lowercased() == target }
        let languageOnly = all.filter { $0.language.lowercased().hasPrefix(prefix) }
        let pool = exact.isEmpty ? languageOnly : exact
        guard !pool.isEmpty else {
            return AVSpeechSynthesisVoice(language: locale)
        }

        // Siri voices carry "siri" in their identifier on modern iOS.
        if let siri = pool.filter({ $0.identifier.lowercased().contains("siri") })
            .max(by: { qualityRank($0) < qualityRank($1) }) {
            return siri
        }
        // Otherwise the highest-quality voice available — premium > enhanced
        // > default — which still sounds much better than the legacy default.
        return pool.max(by: { qualityRank($0) < qualityRank($1) })
            ?? AVSpeechSynthesisVoice(language: locale)
    }

    private static func qualityRank(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
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
