import SwiftUI

@main
struct OpenClawDisplayApp: App {

    @StateObject private var engine = LottieAnimationEngine()
    @StateObject private var riveEngine = RiveAnimationEngine()
    @StateObject private var client = BonjourClient()
    @StateObject private var animator = EmotionAnimator()
    @State private var displayMode: DisplayMode = .lottie
    @State private var customConfig = CustomAvatarConfig.default

    var body: some Scene {
        WindowGroup {
            FaceView(
                engine: engine,
                riveEngine: riveEngine,
                client: client,
                animator: animator,
                displayMode: $displayMode,
                customConfig: $customConfig
            )
            .onAppear {
                client.onEmotionReceived = { [weak engine, weak riveEngine, weak animator] command in
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
                    default:
                        break
                    }
                }
                client.startBrowsing()
            }
            .preferredColorScheme(.dark)
        }
    }
}
