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

    func activateListening() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP, .allowBluetoothA2DP])
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
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
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
}
