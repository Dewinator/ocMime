import SwiftUI

@main
struct OpenClawDisplayApp: App {

    @StateObject private var engine = LottieAnimationEngine()
    @StateObject private var client = BonjourClient()
    @StateObject private var animator = EmotionAnimator()
    @State private var displayMode: DisplayMode = .lottie
    @State private var customConfig = CustomAvatarConfig.default

    var body: some Scene {
        WindowGroup {
            FaceView(
                engine: engine,
                client: client,
                animator: animator,
                displayMode: $displayMode,
                customConfig: $customConfig
            )
            .onAppear {
                client.onEmotionReceived = { [weak engine, weak animator] command in
                    switch command.cmd {
                    case "emotion":
                        if let stateStr = command.state,
                           let state = EmotionState(rawValue: stateStr) {
                            engine?.setEmotion(state, intensity: command.intensity ?? 0.5)
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
