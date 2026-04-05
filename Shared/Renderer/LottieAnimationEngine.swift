import Foundation
import Lottie

@MainActor
final class LottieAnimationEngine: ObservableObject {

    @Published private(set) var currentState: EmotionState = .idle
    @Published private(set) var currentAvatar: AvatarType = .eyesRound
    @Published var animationSource: LottieAnimation?

    private var intensity: Double = 0.5

    /// When true, the Lottie view should freeze on the first frame of each emotion segment
    /// rather than looping. Propagated from the hosting view's accessibilityReduceMotion environment.
    var reduceMotion: Bool = false

    init() {
        loadAnimation(for: .eyesRound)
    }

    // MARK: - Avatar

    func setAvatar(_ type: AvatarType) {
        guard type != currentAvatar else { return }
        currentAvatar = type
        loadAnimation(for: type)
    }

    func setConfig(_ config: AvatarConfig) {
        setAvatar(config.avatarType)
    }

    // MARK: - Emotion

    func setEmotion(_ state: EmotionState, intensity: Double = 0.5) {
        self.currentState = state
        self.intensity = intensity
    }

    // MARK: - Frame Range for Current Emotion

    var currentFrameRange: ClosedRange<AnimationFrameTime> {
        let start = AnimationFrameTime(currentState.lottieStartFrame)
        let end = AnimationFrameTime(currentState.lottieEndFrame)
        return start...end
    }

    // MARK: - Load

    private func loadAnimation(for type: AvatarType) {
        animationSource = LottieAnimation.named(type.fileName, bundle: .main)
    }
}
