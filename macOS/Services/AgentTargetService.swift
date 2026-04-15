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
            self.config = Self.migrateLegacyRPCFields(loaded)
        } else {
            self.config = .default
        }
    }

    /// Older builds defaulted the chat RPC to `agents.chat` with `agentId` /
    /// `text`; the current gateway uses `chat.send` with `sessionKey` /
    /// `message`. Upgrade stale persisted configs silently so the voice path
    /// keeps working after an update without the user having to reconfigure
    /// the SKILL tab.
    private static func migrateLegacyRPCFields(_ config: AgentTargetConfig) -> AgentTargetConfig {
        var migrated = config
        if migrated.chatMethod == "agents.chat" { migrated.chatMethod = "chat.send" }
        if migrated.paramNameForAgentId == "agentId" { migrated.paramNameForAgentId = "sessionKey" }
        if migrated.paramNameForText == "text" { migrated.paramNameForText = "message" }
        return migrated
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
