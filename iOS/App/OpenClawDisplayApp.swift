import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Speech

@main
struct OpenClawDisplayApp: App {

    @StateObject private var client = BonjourClient()
    @StateObject private var audioCoordinator: AudioSessionCoordinator
    @StateObject private var animator = EmotionAnimator()
    @StateObject private var abstractAnimator = AbstractAnimator()
    @StateObject private var ttsService: TTSService
    @StateObject private var sttService: STTService
    @StateObject private var presenceService = PresenceService()
    @StateObject private var soundService = SoundAnalysisService()
    @State private var displayMode: DisplayMode
    @State private var customConfig: CustomAvatarConfig
    @State private var abstractConfig: AbstractAvatarConfig
    @Environment(\.scenePhase) private var scenePhase

    // UserDefaults keys — the iPad remembers the last avatar it was told to
    // show, so a cold launch or a Bonjour reconnect doesn't snap back to
    // defaults before the bridge has a chance to re-push.
    private static let storedDisplayModeKey = "display.mode"
    private static let storedCustomKey = "display.customConfig"
    private static let storedAbstractKey = "display.abstractConfig"

    init() {
        let coordinator = AudioSessionCoordinator()
        _audioCoordinator = StateObject(wrappedValue: coordinator)
        _ttsService = StateObject(wrappedValue: TTSService(audioCoordinator: coordinator))
        _sttService = StateObject(wrappedValue: STTService(audioCoordinator: coordinator))

        let defaults = UserDefaults.standard
        let storedMode = (defaults.string(forKey: Self.storedDisplayModeKey)).flatMap(DisplayMode.init(rawValue:))
        _displayMode = State(initialValue: storedMode ?? .abstract)

        if let data = defaults.data(forKey: Self.storedCustomKey),
           let decoded = try? JSONDecoder().decode(CustomAvatarConfig.self, from: data) {
            _customConfig = State(initialValue: decoded)
        } else {
            _customConfig = State(initialValue: .default)
        }

        if let data = defaults.data(forKey: Self.storedAbstractKey),
           let decoded = try? JSONDecoder().decode(AbstractAvatarConfig.self, from: data) {
            _abstractConfig = State(initialValue: decoded)
        } else {
            _abstractConfig = State(initialValue: .default)
        }
    }

    var body: some Scene {
        WindowGroup {
            FaceView(
                client: client,
                animator: animator,
                abstractAnimator: abstractAnimator,
                ttsService: ttsService,
                sttService: sttService,
                presenceService: presenceService,
                soundService: soundService,
                displayMode: $displayMode,
                customConfig: $customConfig,
                abstractConfig: $abstractConfig
            )
            .onAppear {
                setupEmotionHandler()
                setupSensorCallbacks()
                requestPermissions()
                client.startBrowsing()
                setIdleTimer(disabled: true)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    setIdleTimer(disabled: true)
                    client.restart()
                    startSTTIfPossible()
                case .inactive, .background:
                    setIdleTimer(disabled: false)
                    sttService.stopListening()
                @unknown default:
                    break
                }
            }
            .onChange(of: sttService.authorizationStatus) { _, status in
                if status == .authorized {
                    startSTTIfPossible()
                }
            }
            .onChange(of: displayMode) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: Self.storedDisplayModeKey)
            }
            .onChange(of: customConfig) { _, newValue in
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: Self.storedCustomKey)
                }
            }
            .onChange(of: abstractConfig) { _, newValue in
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: Self.storedAbstractKey)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Emotion Handler (macOS → iOS)

    private func setupEmotionHandler() {
        client.onEmotionReceived = { [weak animator, weak abstractAnimator, weak ttsService] command in
            switch command.cmd {
            case "emotion":
                if let stateStr = command.state,
                   let state = EmotionState(rawValue: stateStr) {
                    animator?.setEmotion(state)
                    abstractAnimator?.setEmotion(state)
                }
            case "customAvatar":
                if let config = command.customAvatar {
                    Task { @MainActor in
                        customConfig = config
                        displayMode = .custom
                    }
                }
            case "abstractAvatar":
                if let config = command.abstractAvatar {
                    Task { @MainActor in
                        abstractConfig = config
                        displayMode = .abstract
                    }
                }
            case "tts":
                if let text = command.ttsText {
                    let locale = command.context ?? "de-DE"
                    let rate = command.intensity ?? 0.5
                    ttsService?.speak(text: text, locale: locale, rate: rate)
                }
            case "ttsStop":
                ttsService?.stop()
            default:
                break
            }
        }
    }

    // MARK: - Sensor Callbacks (iOS → macOS)

    private func setupSensorCallbacks() {
        ttsService.onSpeakingChanged = { [weak animator, weak sttService] isSpeaking in
            if isSpeaking {
                animator?.setEmotion(.responding)
                // Mute STT while we're playing back the agent's reply — the
                // speaker feeds straight into the mic on most iPhones/iPads
                // and would otherwise be transcribed and sent back as a new
                // chat, triggering an infinite chatter loop.
                sttService?.stopListening()
            } else {
                animator?.setEmotion(.idle)
                // Brief settle delay so the tail of the utterance isn't picked
                // up the moment STT comes back online.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    if sttService?.authorizationStatus == .authorized,
                       sttService?.isListening == false {
                        sttService?.startListening()
                    }
                }
            }
        }

        sttService.onTranscript = { [weak client] text, isFinal in
            let command = SensorCommand.stt(text: text, isFinal: isFinal)
            client?.sendSensorCommand(command)
        }

        presenceService.onPresenceChanged = { [weak client] detected, count, confidence in
            let command = SensorCommand.presence(detected: detected, personCount: count, confidence: confidence)
            client?.sendSensorCommand(command)
        }

        soundService.onSoundDetected = { [weak client] soundType, confidence in
            let command = SensorCommand.sound(type: soundType, confidence: confidence)
            client?.sendSensorCommand(command)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        sttService.requestAuthorization()
    }

    private func setIdleTimer(disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }

    private func startSTTIfPossible() {
        guard sttService.authorizationStatus == .authorized else { return }
        guard !sttService.isListening else { return }
        sttService.startListening()
    }
}
