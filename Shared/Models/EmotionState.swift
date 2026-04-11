import Foundation

enum EmotionState: String, CaseIterable, Identifiable, Codable {
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

/// JSON command sent from macOS Bridge to iOS Display via Bonjour.
/// After the Rive/Lottie rip this is the only per-face-style command left:
/// `customAvatar` for the SwiftUI-Bezier face and `abstractAvatar` for the
/// Canvas aura family.
struct EmotionCommand: Codable {
    let cmd: String                           // "emotion" | "ping" | "customAvatar" | "abstractAvatar" | "tts" | "ttsStop"
    let state: String?                        // EmotionState rawValue
    let intensity: Double?
    let context: String?
    let customAvatar: CustomAvatarConfig?
    let abstractAvatar: AbstractAvatarConfig?
    let ttsText: String?

    static func emotion(_ state: EmotionState, intensity: Double = 0.5, context: String? = nil) -> EmotionCommand {
        EmotionCommand(cmd: "emotion", state: state.rawValue, intensity: intensity, context: context, customAvatar: nil, abstractAvatar: nil, ttsText: nil)
    }

    static var ping: EmotionCommand {
        EmotionCommand(cmd: "ping", state: nil, intensity: nil, context: nil, customAvatar: nil, abstractAvatar: nil, ttsText: nil)
    }

    static func customAvatarUpdate(_ config: CustomAvatarConfig) -> EmotionCommand {
        EmotionCommand(cmd: "customAvatar", state: nil, intensity: nil, context: nil, customAvatar: config, abstractAvatar: nil, ttsText: nil)
    }

    static func abstractAvatarUpdate(_ config: AbstractAvatarConfig) -> EmotionCommand {
        EmotionCommand(cmd: "abstractAvatar", state: nil, intensity: nil, context: nil, customAvatar: nil, abstractAvatar: config, ttsText: nil)
    }

    static func tts(text: String, locale: String = "de-DE", rate: Double = 0.5) -> EmotionCommand {
        EmotionCommand(cmd: "tts", state: nil, intensity: rate, context: locale, customAvatar: nil, abstractAvatar: nil, ttsText: text)
    }

    static var ttsStop: EmotionCommand {
        EmotionCommand(cmd: "ttsStop", state: nil, intensity: nil, context: nil, customAvatar: nil, abstractAvatar: nil, ttsText: nil)
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
