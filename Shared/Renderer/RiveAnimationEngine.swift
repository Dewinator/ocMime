import Foundation
import RiveRuntime

@MainActor
final class RiveAnimationEngine: ObservableObject {

    @Published private(set) var currentState: EmotionState = .idle
    @Published private(set) var currentConfig: RiveAvatarConfig = .default
    @Published private(set) var viewModel: RiveViewModel?

    private var intensity: Double = 0.5

    init() {
        loadRiveFile(config: .default)
    }

    // MARK: - Avatar

    func setConfig(_ config: RiveAvatarConfig) {
        guard config != currentConfig else { return }
        currentConfig = config
        loadRiveFile(config: config)
    }

    func setType(_ type: RiveAvatarType) {
        setConfig(RiveAvatarConfig(type: type))
    }

    // MARK: - Emotion

    func setEmotion(_ state: EmotionState, intensity: Double = 0.5) {
        self.currentState = state
        self.intensity = min(max(intensity, 0), 1)
        applyEmotion()
    }

    // MARK: - Private

    private func loadRiveFile(config: RiveAvatarConfig) {
        viewModel = RiveViewModel(
            fileName: config.riveFile,
            stateMachineName: config.stateMachine
        )
        applyEmotion()
    }

    private func applyEmotion() {
        guard let vm = viewModel else { return }
        do {
            try vm.setInput("emotionState", value: currentState.riveStateValue)
            try vm.setInput("intensity", value: intensity)
        } catch {
            // Inputs may not exist in all .riv files — silently ignore
        }
    }

    /// Trigger a one-shot event (e.g. blink)
    func fireTrigger(_ name: String) {
        guard let vm = viewModel else { return }
        do {
            try vm.triggerInput(name)
        } catch {
            // Trigger may not exist — silently ignore
        }
    }
}
