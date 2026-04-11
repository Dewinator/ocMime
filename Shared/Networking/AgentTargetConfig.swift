import Foundation

// MARK: - Agent Target Config
//
// Tells the Bridge which agent should receive voice input captured by the
// iOS display and whether the agent's replies should automatically play
// back as TTS. The method and parameter names are intentionally exposed as
// editable fields because OpenClaw's chat RPC shape isn't fully locked in —
// a user running a custom gateway can override them without rebuilding.

struct AgentTargetConfig: Codable, Equatable {
    /// Empty string disables the voice-upstream path entirely. When empty, the
    /// iPad still listens and the Bridge still shows transcripts, but nothing
    /// is forwarded to the agent as chat.
    var agentId: String

    /// Human-friendly label, cached from the last successful agents.list so
    /// the settings UI can show the name even when the gateway is offline.
    var agentLabel: String

    /// RPC method name to invoke on the gateway when voice input arrives.
    /// Default is an educated guess; users tweak if their gateway exposes a
    /// different surface.
    var chatMethod: String

    /// Parameter name for the agent identifier in the outgoing RPC payload.
    var paramNameForAgentId: String

    /// Parameter name for the user-provided text.
    var paramNameForText: String

    /// When true, the final chat response from the agent is automatically
    /// spoken back through the iPad's TTS (respecting `SensorRouter.ttsEnabled`).
    var autoTTSResponse: Bool

    /// When true, entry of a person into the room triggers a short chat
    /// request asking the agent to greet the newcomer. Off by default — some
    /// users will find this spooky.
    var proactiveGreetOnEntry: Bool

    static let `default` = AgentTargetConfig(
        agentId: "",
        agentLabel: "",
        chatMethod: "agents.chat",
        paramNameForAgentId: "agentId",
        paramNameForText: "text",
        autoTTSResponse: true,
        proactiveGreetOnEntry: false
    )

    var isConfigured: Bool { !agentId.isEmpty }

    func toData() -> Data? { try? JSONEncoder().encode(self) }
    static func from(data: Data) -> AgentTargetConfig? {
        try? JSONDecoder().decode(AgentTargetConfig.self, from: data)
    }
}
