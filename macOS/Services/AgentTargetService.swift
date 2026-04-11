import Foundation

/// Owns the persistent `AgentTargetConfig` that describes how voice input
/// reaches the chosen agent and how its replies come back. It's a thin
/// `@Published` wrapper around a UserDefaults-stored codable so the settings
/// view can bind directly.
@MainActor
final class AgentTargetService: ObservableObject {

    @Published var config: AgentTargetConfig {
        didSet { save() }
    }

    private static let defaultsKey = "agent.target"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let loaded = AgentTargetConfig.from(data: data) {
            self.config = loaded
        } else {
            self.config = .default
        }
    }

    private func save() {
        if let data = config.toData() {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Remember the most recently seen label for the current agentId so the
    /// settings UI can render a friendly name even if the gateway is offline
    /// and agents.list hasn't returned yet.
    func updateLabel(for agentId: String, label: String?) {
        guard config.agentId == agentId else { return }
        guard let label, config.agentLabel != label else { return }
        config.agentLabel = label
    }
}
