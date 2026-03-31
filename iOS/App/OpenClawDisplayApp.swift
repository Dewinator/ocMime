import SwiftUI

@main
struct OpenClawDisplayApp: App {

    @StateObject private var engine = LottieAnimationEngine()
    @StateObject private var riveEngine = RiveAnimationEngine()
    @StateObject private var client = BonjourClient()
    @StateObject private var animator = EmotionAnimator()
    @StateObject private var ttsService = TTSService()
    @StateObject private var sttService = STTService()
    @StateObject private var presenceService = PresenceService()
    @StateObject private var soundService = SoundAnalysisService()
    @State private var displayMode: DisplayMode = .lottie
    @State private var customConfig = CustomAvatarConfig.default

    var body: some Scene {
        WindowGroup {
            FaceView(
                engine: engine,
                riveEngine: riveEngine,
                client: client,
                animator: animator,
                ttsService: ttsService,
                sttService: sttService,
                presenceService: presenceService,
                soundService: soundService,
                displayMode: $displayMode,
                customConfig: $customConfig
            )
            .onAppear {
                setupEmotionHandler()
                setupSensorCallbacks()
                requestPermissions()
                client.startBrowsing()
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Emotion Handler (macOS → iOS)

    private func setupEmotionHandler() {
        client.onEmotionReceived = { [weak engine, weak riveEngine, weak animator, weak ttsService] command in
            switch command.cmd {
            case "emotion":
                if let stateStr = command.state,
                   let state = EmotionState(rawValue: stateStr) {
                    let intensity = command.intensity ?? 0.5
                    engine?.setEmotion(state, intensity: intensity)
                    riveEngine?.setEmotion(state, intensity: intensity)
                    animator?.setEmotion(state)
                }
            case "avatar":
                if let config = command.avatar {
                    engine?.setConfig(config)
                    Task { @MainActor in
                        displayMode = .lottie
                    }
                }
            case "customAvatar":
                if let config = command.customAvatar {
                    Task { @MainActor in
                        customConfig = config
                        displayMode = .custom
                    }
                }
            case "riveAvatar":
                if let config = command.riveAvatar {
                    riveEngine?.setConfig(config)
                    Task { @MainActor in
                        displayMode = .rive
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
        // TTS: sync emotion state with speaking
        ttsService.onSpeakingChanged = { [weak animator] isSpeaking in
            if isSpeaking {
                animator?.setEmotion(.responding)
            } else {
                animator?.setEmotion(.idle)
            }
        }

        // STT: send transcripts to macOS
        sttService.onTranscript = { [weak client] text, isFinal in
            let command = SensorCommand.stt(text: text, isFinal: isFinal)
            client?.sendSensorCommand(command)
        }

        // Presence: send detection events to macOS
        presenceService.onPresenceChanged = { [weak client] detected, count, confidence in
            let command = SensorCommand.presence(detected: detected, personCount: count, confidence: confidence)
            client?.sendSensorCommand(command)
        }

        // Sound: send classified sounds to macOS
        soundService.onSoundDetected = { [weak client] soundType, confidence in
            let command = SensorCommand.sound(type: soundType, confidence: confidence)
            client?.sendSensorCommand(command)
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        sttService.requestAuthorization()
        // Camera and microphone permissions are requested when services start
    }
}
