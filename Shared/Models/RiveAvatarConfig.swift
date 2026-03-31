import Foundation

// MARK: - Rive Avatar Configuration

/// Predefined Rive avatar types bundled with the app
enum RiveAvatarType: String, CaseIterable, Codable, Identifiable {
    case robotFace = "robot_face"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .robotFace: return "Robot Face"
        }
    }

    /// File name of the .riv asset (without extension)
    var fileName: String { rawValue }

    var description: String {
        switch self {
        case .robotFace: return "State-Machine-gesteuerter Roboter mit 8 Emotionen"
        }
    }

    /// Name of the Rive state machine that handles emotion inputs
    var stateMachineName: String { "emotions" }
}

/// Maps EmotionState to a numeric value for Rive state machine input
extension EmotionState {
    var riveStateValue: Double {
        switch self {
        case .idle:       return 0
        case .thinking:   return 1
        case .focused:    return 2
        case .responding: return 3
        case .error:      return 4
        case .success:    return 5
        case .listening:  return 6
        case .sleeping:   return 7
        }
    }
}

/// Configuration sent via Bonjour to switch the iOS display to a Rive avatar
struct RiveAvatarConfig: Codable, Equatable {
    var riveFile: String          // File name (without .riv extension)
    var stateMachine: String      // State machine name inside the .riv

    init(riveFile: String, stateMachine: String = "emotions") {
        self.riveFile = riveFile
        self.stateMachine = stateMachine
    }

    init(type: RiveAvatarType) {
        self.riveFile = type.fileName
        self.stateMachine = type.stateMachineName
    }

    static let `default` = RiveAvatarConfig(type: .robotFace)

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> RiveAvatarConfig? {
        try? JSONDecoder().decode(RiveAvatarConfig.self, from: data)
    }
}
