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

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var desiredMode: Mode = .idle

    init() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                self?.handleRouteChange(reasonRaw: reasonRaw)
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
            desiredMode = .listening
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
            desiredMode = .speaking
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
            desiredMode = .idle
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
                switch desiredMode {
                case .listening:
                    activateListening()
                case .speaking:
                    activateSpeaking()
                case .idle:
                    break
                }
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

        switch reason {
        case .oldDeviceUnavailable, .newDeviceAvailable, .categoryChange:
            guard desiredMode != .idle else { return }
            switch desiredMode {
            case .listening:
                activateListening()
            case .speaking:
                activateSpeaking()
            case .idle:
                break
            }
        default:
            break
        }
    }
    #endif
}
