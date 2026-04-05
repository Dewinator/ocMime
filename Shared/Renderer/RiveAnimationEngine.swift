import Foundation
import RiveRuntime

@MainActor
final class RiveAnimationEngine: ObservableObject {

    @Published private(set) var currentState: EmotionState = .idle
    @Published private(set) var currentConfig: RiveAvatarConfig?
    @Published private(set) var viewModel: RiveViewModel?
    @Published private(set) var loadError: String?

    private var intensity: Double = 0.5
    private(set) var hasLoadedOnce = false

    init() {
        // Lazy: do NOT load on init — wait for explicit setConfig/setType
    }

    // MARK: - Avatar

    func setConfig(_ config: RiveAvatarConfig) {
        guard config != currentConfig || !hasLoadedOnce else { return }
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
        hasLoadedOnce = true
        loadError = nil

        // Check if file exists in bundle before loading
        guard Bundle.main.url(forResource: config.riveFile, withExtension: "riv") != nil else {
            viewModel = nil
            loadError = "Datei '\(config.riveFile).riv' nicht im Bundle gefunden"
            return
        }

        viewModel = RiveViewModel(
            fileName: config.riveFile,
            stateMachineName: config.stateMachine
        )
        loadError = nil
        applyEmotion()
    }

    private func applyEmotion() {
        guard let vm = viewModel else { return }
        vm.setInput("emotionState", value: currentState.riveStateValue)
        vm.setInput("intensity", value: intensity)
    }

    func fireTrigger(_ name: String) {
        viewModel?.triggerInput(name)
    }
}
