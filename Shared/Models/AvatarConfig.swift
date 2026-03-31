import Foundation

// MARK: - Avatar Type (Lottie-based)

enum AvatarType: String, CaseIterable, Codable, Identifiable {
    // Nur Augen
    case eyesRound   = "eyes_round"
    case eyesCyber   = "eyes_cyber"
    case eyesMinimal = "eyes_minimal"
    case eyesNeon    = "eyes_neon"
    case eyesAngry   = "eyes_angry"
    case eyesCute    = "eyes_cute"
    // Gesichter
    case faceRobot   = "face_robot"
    case faceCat     = "face_cat"
    case faceGhost   = "face_ghost"
    case faceOwl     = "face_owl"
    case faceSkull   = "face_skull"
    case faceAlien   = "face_alien"
    // Sphere
    case sphereRGB   = "sphere_rgb"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eyesRound:   return "Round Eyes"
        case .eyesCyber:   return "Cyber Eyes"
        case .eyesMinimal: return "Minimal Dots"
        case .eyesNeon:    return "Neon Eyes"
        case .eyesAngry:   return "Angry Eyes"
        case .eyesCute:    return "Cute Eyes"
        case .faceRobot:   return "Robot"
        case .faceCat:     return "Cat"
        case .faceGhost:   return "Ghost"
        case .faceOwl:     return "Owl"
        case .faceSkull:   return "Skull"
        case .faceAlien:   return "Alien"
        case .sphereRGB:   return "RGB Sphere"
        }
    }

    var fileName: String { rawValue }

    var category: String {
        switch self {
        case .eyesRound, .eyesCyber, .eyesMinimal, .eyesNeon, .eyesAngry, .eyesCute:
            return "Nur Augen"
        case .faceRobot, .faceCat, .faceGhost, .faceOwl, .faceSkull, .faceAlien:
            return "Gesichter"
        case .sphereRGB:
            return "Sphere"
        }
    }

    static var categories: [String] {
        ["Nur Augen", "Gesichter", "Sphere"]
    }

    var description: String {
        switch self {
        case .eyesRound:   return "Runde Augen mit Pupillen, klassisch"
        case .eyesCyber:   return "Diamant-LEDs, Cyberpunk-Stil"
        case .eyesMinimal: return "Zwei Punkte, ultrareduziert"
        case .eyesNeon:    return "Farbe wechselt mit Emotion"
        case .eyesAngry:   return "Schraege wuetende Schlitze, rot"
        case .eyesCute:    return "Grosse Kawaii-Augen mit Iris und Glanz"
        case .faceRobot:   return "Eckiger Kopf, Mund, Schrauben"
        case .faceCat:     return "Ohren, Schnurrhaare, gruene Augen"
        case .faceGhost:   return "Schwebend, welliger Koerper"
        case .faceOwl:     return "Augenringe, Schnabel, Federohren"
        case .faceSkull:   return "Totenschaedel mit Zaehnen"
        case .faceAlien:   return "Grosser Kopf, riesige dunkle Augen"
        case .sphereRGB:   return "Siri-aehnliche RGB-Kugel, Farbe = Emotion"
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
