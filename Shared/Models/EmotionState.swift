import Foundation

enum EmotionState: String, CaseIterable, Identifiable {
    case idle
    case thinking
    case focused
    case responding
    case error
    case success
    case listening
    case sleeping

    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:       return "Idle"
        case .thinking:   return "Thinking"
        case .focused:    return "Focused"
        case .responding: return "Responding"
        case .error:      return "Error"
        case .success:    return "Success"
        case .listening:  return "Listening"
        case .sleeping:   return "Sleeping"
        }
    }
}

struct EmotionEvent: Equatable {
    let state: EmotionState
    let intensity: Double
    let context: String?
    let timestamp: Date

    init(state: EmotionState, intensity: Double = 0.5, context: String? = nil) {
        self.state = state
        self.intensity = min(max(intensity, 0), 1)
        self.context = context
        self.timestamp = Date()
    }
}

// MARK: - Bonjour Protocol Command

/// JSON command sent from macOS Bridge to iOS Display via Bonjour
struct EmotionCommand: Codable {
    let cmd: String           // "emotion", "ping", "avatar", "customAvatar", "riveAvatar", "tts", "ttsStop"
    let state: String?        // EmotionState rawValue
    let intensity: Double?
    let context: String?
    let avatar: AvatarConfig?             // Only for cmd:"avatar"
    let customAvatar: CustomAvatarConfig? // Only for cmd:"customAvatar"
    let riveAvatar: RiveAvatarConfig?     // Only for cmd:"riveAvatar"
    let ttsText: String?                  // Only for cmd:"tts"

    static func emotion(_ state: EmotionState, intensity: Double = 0.5, context: String? = nil) -> EmotionCommand {
        EmotionCommand(cmd: "emotion", state: state.rawValue, intensity: intensity, context: context, avatar: nil, customAvatar: nil, riveAvatar: nil, ttsText: nil)
    }

    static var ping: EmotionCommand {
        EmotionCommand(cmd: "ping", state: nil, intensity: nil, context: nil, avatar: nil, customAvatar: nil, riveAvatar: nil, ttsText: nil)
    }

    static func avatarUpdate(_ config: AvatarConfig) -> EmotionCommand {
        EmotionCommand(cmd: "avatar", state: nil, intensity: nil, context: nil, avatar: config, customAvatar: nil, riveAvatar: nil, ttsText: nil)
    }

    static func customAvatarUpdate(_ config: CustomAvatarConfig) -> EmotionCommand {
        EmotionCommand(cmd: "customAvatar", state: nil, intensity: nil, context: nil, avatar: nil, customAvatar: config, riveAvatar: nil, ttsText: nil)
    }

    static func riveAvatarUpdate(_ config: RiveAvatarConfig) -> EmotionCommand {
        EmotionCommand(cmd: "riveAvatar", state: nil, intensity: nil, context: nil, avatar: nil, customAvatar: nil, riveAvatar: config, ttsText: nil)
    }

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> EmotionCommand? {
        try? JSONDecoder().decode(EmotionCommand.self, from: data)
    }
}

/// Response from iOS Display back to macOS Bridge
struct EmotionAck: Codable {
    let ack: Bool
    let error: String?

    static var ok: EmotionAck { EmotionAck(ack: true, error: nil) }

    static func fail(_ msg: String) -> EmotionAck {
        EmotionAck(ack: false, error: msg)
    }

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> EmotionAck? {
        try? JSONDecoder().decode(EmotionAck.self, from: data)
    }
}
