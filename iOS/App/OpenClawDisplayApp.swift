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
    @State private var displayMode: DisplayMode = .abstract
    @State private var customConfig = CustomAvatarConfig.default
    @State private var abstractConfig = AbstractAvatarConfig.default
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let coordinator = AudioSessionCoordinator()
        _audioCoordinator = StateObject(wrappedValue: coordinator)
        _ttsService = StateObject(wrappedValue: TTSService(audioCoordinator: coordinator))
        _sttService = StateObject(wrappedValue: STTService(audioCoordinator: coordinator))
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
