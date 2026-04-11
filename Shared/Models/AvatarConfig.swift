import Foundation

// MARK: - Avatar Type (Lottie-based, eyes-only)
//
// The original project shipped six full-head avatars (face_robot, face_cat,
// face_ghost, face_owl, face_skull, face_alien). They never reached the level
// of polish we wanted, so the project pivoted to: only-eyes presets, the
// custom SwiftUI eye renderer, and the new abstract / aura avatars.

enum AvatarType: String, CaseIterable, Codable, Identifiable {
    case eyesRound   = "eyes_round"
    case eyesCyber   = "eyes_cyber"
    case eyesMinimal = "eyes_minimal"
    case eyesNeon    = "eyes_neon"
    case eyesAngry   = "eyes_angry"
    case eyesCute    = "eyes_cute"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eyesRound:   return "Round"
        case .eyesCyber:   return "Cyber"
        case .eyesMinimal: return "Minimal"
        case .eyesNeon:    return "Neon"
        case .eyesAngry:   return "Sharp"
        case .eyesCute:    return "Soft"
        }
    }

    var fileName: String { rawValue }

    var category: String { "Eyes" }

    static var categories: [String] { ["Eyes"] }

    var description: String {
        switch self {
        case .eyesRound:   return "Klassisch runde Augen mit Pupillen"
        case .eyesCyber:   return "Diamant-LEDs, Cyberpunk-Stil"
        case .eyesMinimal: return "Zwei Punkte, ultrareduziert"
        case .eyesNeon:    return "Farbe wechselt mit Emotion"
        case .eyesAngry:   return "Schmale, intensive Schlitze"
        case .eyesCute:    return "Grosse Augen mit Iris-Glanz"
        }
    }
}

// MARK: - Emotion Segments (frame ranges in Lottie)

extension EmotionState {

    /// Start frame in the Lottie animation (30 frames per segment)
    var lottieStartFrame: Int {
        switch self {
        case .idle:       return 0
        case .thinking:   return 30
        case .focused:    return 60
        case .responding: return 90
        case .error:      return 120
        case .success:    return 150
        case .listening:  return 180
        case .sleeping:   return 210
        }
    }

    var lottieEndFrame: Int {
        lottieStartFrame + 29
    }
}

// MARK: - Avatar Config

struct AvatarConfig: Codable, Equatable {
    var avatarType: AvatarType

    static let `default` = AvatarConfig(avatarType: .eyesRound)

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> AvatarConfig? {
        try? JSONDecoder().decode(AvatarConfig.self, from: data)
    }
}
