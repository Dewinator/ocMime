import AVFoundation
import Foundation

@MainActor
final class AudioSessionCoordinator: ObservableObject {

    enum Mode: Equatable {
        case idle
        case listening
        case speaking
    }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var lastError: String?

    init() {
        #if os(iOS)
        _ = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }
        #endif
    }

    func activateListening() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            mode = .listening
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func activateSpeaking() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            mode = .speaking
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    func deactivateIfIdle(expected: Mode) {
        guard mode == expected else { return }
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            mode = .idle
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        #endif
    }

    #if os(iOS)
    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let raw = typeRaw,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            lastError = "Audio interrupted by system"
            mode = .idle
        case .ended:
            if let optionsRaw,
               AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
                lastError = nil
            }
        @unknown default:
            break
        }
    }
    #endif
}
