import Foundation

// ════════════════════════════════════════════
// MARK: - Shape Variants per Component
// ════════════════════════════════════════════

enum FaceOutlineVariant: String, CaseIterable, Codable, Identifiable {
    case circle, roundedRect, oval, square, hexagon, none
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum EyeVariant: String, CaseIterable, Codable, Identifiable {
    case round, oval, almond, droopy, wide, slit
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum EyebrowVariant: String, CaseIterable, Codable, Identifiable {
    case straight, arched, angry, worried, thick, none
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum PupilVariant: String, CaseIterable, Codable, Identifiable {
    case round, vertical, horizontal, star, dot, none
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum NoseVariant: String, CaseIterable, Codable, Identifiable {
    case triangle, round, line, dot, none
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum MouthVariant: String, CaseIterable, Codable, Identifiable {
    case line, smile, open, small, wide, none
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum AccessoryVariant: String, CaseIterable, Codable, Identifiable {
    case none, ears, horns, antenna, halo, glasses, bow
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

// ════════════════════════════════════════════
// MARK: - Color (Codable wrapper for RGB)
// ════════════════════════════════════════════

struct FaceColor: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    static let white = FaceColor(r: 1, g: 1, b: 1, a: 1)
    static let black = FaceColor(r: 0, g: 0, b: 0, a: 1)
    static let green = FaceColor(r: 0.2, g: 0.9, b: 0.4, a: 1)
    static let red = FaceColor(r: 1, g: 0.2, b: 0.2, a: 1)
    static let blue = FaceColor(r: 0.3, g: 0.5, b: 1, a: 1)
    static let cyan = FaceColor(r: 0, g: 0.8, b: 1, a: 1)
    static let yellow = FaceColor(r: 1, g: 0.9, b: 0.2, a: 1)
    static let pink = FaceColor(r: 1, g: 0.4, b: 0.7, a: 1)
    static let purple = FaceColor(r: 0.6, g: 0.3, b: 1, a: 1)
    static let orange = FaceColor(r: 1, g: 0.5, b: 0.1, a: 1)
    static let dim = FaceColor(r: 0.4, g: 0.4, b: 0.4, a: 1)

    static let presets: [FaceColor] = [.white, .green, .cyan, .blue, .purple, .pink, .red, .orange, .yellow, .dim]
}

// ════════════════════════════════════════════
// MARK: - Component Config
// ════════════════════════════════════════════

struct FaceOutlineConfig: Codable, Equatable {
    var variant: FaceOutlineVariant = .circle
    var color: FaceColor = .white
    var size: Double = 1.0          // 0.5 ... 1.5 multiplier
    var strokeWidth: Double = 2.5
    var fillOpacity: Double = 0.0   // 0 = outline only, 1 = solid
}

struct EyeConfig: Codable, Equatable {
    var variant: EyeVariant = .round
    var color: FaceColor = .white
    var size: Double = 1.0
    var offsetX: Double = 0         // user can shift eyes closer/apart
    var offsetY: Double = 0         // user can shift eyes up/down
}

struct EyebrowConfig: Codable, Equatable {
    var variant: EyebrowVariant = .arched
    var color: FaceColor = .white
    var thickness: Double = 1.0     // 0.5 ... 2.0
    var offsetY: Double = 0         // distance from eye
}

struct PupilConfig: Codable, Equatable {
    var variant: PupilVariant = .round
    var color: FaceColor = .black
    var size: Double = 1.0
}

struct NoseConfig: Codable, Equatable {
    var variant: NoseVariant = .none
    var color: FaceColor = .white
    var size: Double = 1.0
}

struct MouthConfig: Codable, Equatable {
    var variant: MouthVariant = .line
    var color: FaceColor = .white
    var size: Double = 1.0
    var offsetY: Double = 0
}

struct AccessoryConfig: Codable, Equatable {
    var variant: AccessoryVariant = .none
    var color: FaceColor = .white
    var size: Double = 1.0
}

// ════════════════════════════════════════════
// MARK: - Complete Custom Avatar
// ════════════════════════════════════════════

struct CustomAvatarConfig: Codable, Equatable {
    var name: String = "Custom"
    var backgroundColor: FaceColor = .black

    var faceOutline: FaceOutlineConfig = FaceOutlineConfig()
    var eyeLeft: EyeConfig = EyeConfig()
    var eyeRight: EyeConfig = EyeConfig()
    var eyebrowLeft: EyebrowConfig = EyebrowConfig()
    var eyebrowRight: EyebrowConfig = EyebrowConfig()
    var pupilLeft: PupilConfig = PupilConfig()
    var pupilRight: PupilConfig = PupilConfig()
    var nose: NoseConfig = NoseConfig()
    var mouth: MouthConfig = MouthConfig()
    var accessory: AccessoryConfig = AccessoryConfig()

    /// Mirror left eye settings to right
    var mirrorEyes: Bool = true
    var mirrorEyebrows: Bool = true
    var mirrorPupils: Bool = true

    static let `default` = CustomAvatarConfig()

    /// Quick presets
    static let robot = CustomAvatarConfig(
        name: "Robot",
        faceOutline: FaceOutlineConfig(variant: .roundedRect, color: .white, strokeWidth: 3),
        eyeLeft: EyeConfig(variant: .round, color: .cyan, size: 0.9),
        eyeRight: EyeConfig(variant: .round, color: .cyan, size: 0.9),
        eyebrowLeft: EyebrowConfig(variant: .straight, color: .cyan),
        eyebrowRight: EyebrowConfig(variant: .straight, color: .cyan),
        pupilLeft: PupilConfig(variant: .dot, color: .white),
        pupilRight: PupilConfig(variant: .dot, color: .white),
        nose: NoseConfig(variant: .dot, color: .cyan, size: 0.5),
        mouth: MouthConfig(variant: .line, color: .cyan),
        accessory: AccessoryConfig(variant: .antenna, color: .cyan)
    )

    static let kawaii = CustomAvatarConfig(
        name: "Kawaii",
        faceOutline: FaceOutlineConfig(variant: .circle, color: .pink, size: 1.1, strokeWidth: 2, fillOpacity: 0.05),
        eyeLeft: EyeConfig(variant: .wide, color: .white, size: 1.3),
        eyeRight: EyeConfig(variant: .wide, color: .white, size: 1.3),
        eyebrowLeft: EyebrowConfig(variant: .worried, color: .pink, thickness: 0.7),
        eyebrowRight: EyebrowConfig(variant: .worried, color: .pink, thickness: 0.7),
        pupilLeft: PupilConfig(variant: .round, color: .purple, size: 1.2),
        pupilRight: PupilConfig(variant: .round, color: .purple, size: 1.2),
        nose: NoseConfig(variant: .dot, color: .pink, size: 0.4),
        mouth: MouthConfig(variant: .small, color: .pink),
        accessory: AccessoryConfig(variant: .bow, color: .pink)
    )

    static let demon = CustomAvatarConfig(
        name: "Demon",
        faceOutline: FaceOutlineConfig(variant: .hexagon, color: .red, strokeWidth: 2),
        eyeLeft: EyeConfig(variant: .slit, color: .red, size: 1.1),
        eyeRight: EyeConfig(variant: .slit, color: .red, size: 1.1),
        eyebrowLeft: EyebrowConfig(variant: .angry, color: .red, thickness: 1.5),
        eyebrowRight: EyebrowConfig(variant: .angry, color: .red, thickness: 1.5),
        pupilLeft: PupilConfig(variant: .vertical, color: .yellow),
        pupilRight: PupilConfig(variant: .vertical, color: .yellow),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .wide, color: .red),
        accessory: AccessoryConfig(variant: .horns, color: .red)
    )

    static let hacker = CustomAvatarConfig(
        name: "Hacker",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .almond, color: .green),
        eyeRight: EyeConfig(variant: .almond, color: .green),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .dot, color: .black),
        pupilRight: PupilConfig(variant: .dot, color: .black),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    // ════════════════════════════════════════════
    // MARK: - Eyes-Only Presets (curated)
    // ════════════════════════════════════════════
    //
    // The pivot from full heads to "eyes + mimicry" relies on the rich
    // EmotionAnimator pipeline to do the heavy lifting. These presets all
    // hide face/mouth/nose/brows so only the eyes carry the expression.

    static let eyesPhosphor = CustomAvatarConfig(
        name: "Phosphor",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .round, color: .green, size: 1.15),
        eyeRight: EyeConfig(variant: .round, color: .green, size: 1.15),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .dot, color: .black, size: 0.95),
        pupilRight: PupilConfig(variant: .dot, color: .black, size: 0.95),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    static let eyesArc = CustomAvatarConfig(
        name: "Arc",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .almond, color: .cyan, size: 1.05),
        eyeRight: EyeConfig(variant: .almond, color: .cyan, size: 1.05),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .round, color: .white, size: 0.7),
        pupilRight: PupilConfig(variant: .round, color: .white, size: 0.7),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    static let eyesEmber = CustomAvatarConfig(
        name: "Ember",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .slit, color: .orange, size: 1.1),
        eyeRight: EyeConfig(variant: .slit, color: .orange, size: 1.1),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .vertical, color: .yellow, size: 0.85),
        pupilRight: PupilConfig(variant: .vertical, color: .yellow, size: 0.85),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    static let eyesSerene = CustomAvatarConfig(
        name: "Serene",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .wide, color: .white, size: 1.2),
        eyeRight: EyeConfig(variant: .wide, color: .white, size: 1.2),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .round, color: .blue, size: 1.1),
        pupilRight: PupilConfig(variant: .round, color: .blue, size: 1.1),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    static let eyesVoid = CustomAvatarConfig(
        name: "Void",
        faceOutline: FaceOutlineConfig(variant: .none),
        eyeLeft: EyeConfig(variant: .oval, color: .purple, size: 1.0),
        eyeRight: EyeConfig(variant: .oval, color: .purple, size: 1.0),
        eyebrowLeft: EyebrowConfig(variant: .none),
        eyebrowRight: EyebrowConfig(variant: .none),
        pupilLeft: PupilConfig(variant: .round, color: .pink, size: 0.8),
        pupilRight: PupilConfig(variant: .round, color: .pink, size: 0.8),
        nose: NoseConfig(variant: .none),
        mouth: MouthConfig(variant: .none),
        accessory: AccessoryConfig(variant: .none)
    )

    static let eyesPresets: [CustomAvatarConfig] = [
        .eyesPhosphor, .eyesArc, .eyesEmber, .eyesSerene, .eyesVoid
    ]

    static let presets: [CustomAvatarConfig] = [.default, .robot, .kawaii, .demon, .hacker]

    func toData() -> Data? { try? JSONEncoder().encode(self) }
    static func from(data: Data) -> CustomAvatarConfig? { try? JSONDecoder().decode(CustomAvatarConfig.self, from: data) }
}
