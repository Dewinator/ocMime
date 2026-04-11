import Foundation

// MARK: - Abstract Avatar
//
// "Abstract" avatars are the bot's non-anthropomorphic face: pure light,
// motion, and color. The Custom renderer covers expressive eyes; the Lottie
// presets cover fixed eye styles; everything in this file is the third pillar
// — auras, orbs, neural rings, particle fields, waveforms.
//
// They live entirely in SwiftUI Canvas + TimelineView for smooth 60fps
// rendering on both iOS and macOS without any pre-baked assets.

enum AbstractAvatarStyle: String, CaseIterable, Codable, Identifiable {
    case pulseOrb     = "pulse_orb"
    case neuralRing   = "neural_ring"
    case plasmaCore   = "plasma_core"
    case particleHalo = "particle_halo"
    case waveform     = "waveform"
    case gradientFlow = "gradient_flow"
    case ringBars     = "ring_bars"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pulseOrb:     return "Pulse Orb"
        case .neuralRing:   return "Neural Ring"
        case .plasmaCore:   return "Plasma Core"
        case .particleHalo: return "Particle Halo"
        case .waveform:     return "Waveform"
        case .gradientFlow: return "Gradient Flow"
        case .ringBars:     return "Ring Bars"
        }
    }

    var description: String {
        switch self {
        case .pulseOrb:     return "Atmender Lichtkern, weiches Glow"
        case .neuralRing:   return "Konzentrische Ringe, Synapsen-Look"
        case .plasmaCore:   return "Energetisches Plasma, Fluss"
        case .particleHalo: return "Schwebende Partikel um den Fokus"
        case .waveform:     return "Sprach-Wellenform, audio-reaktiv"
        case .gradientFlow: return "Fluessiges Farbverlaufs-Feld"
        case .ringBars:     return "Siri-aehnlicher Ring aus Bars"
        }
    }
}

// MARK: - Color palette per emotion
//
// One palette is shared across all abstract avatars so the visual language
// stays consistent — only the geometry changes. Tuned for an OLED look on a
// black background.

struct EmotionPalette {
    let primary: (r: Double, g: Double, b: Double)
    let secondary: (r: Double, g: Double, b: Double)
    let glow: Double           // 0 ... 1, how bright the glow halo is
    let speed: Double          // 0 ... 2, how energetic the motion is

    static func forEmotion(_ state: EmotionState) -> EmotionPalette {
        switch state {
        case .idle:
            return EmotionPalette(
                primary:   (0.20, 0.85, 0.50),
                secondary: (0.05, 0.45, 0.30),
                glow: 0.45, speed: 0.55
            )
        case .thinking:
            return EmotionPalette(
                primary:   (0.35, 0.65, 1.00),
                secondary: (0.10, 0.30, 0.70),
                glow: 0.65, speed: 1.05
            )
        case .focused:
            return EmotionPalette(
                primary:   (0.70, 0.40, 1.00),
                secondary: (0.25, 0.10, 0.55),
                glow: 0.80, speed: 0.75
            )
        case .responding:
            return EmotionPalette(
                primary:   (0.20, 0.95, 0.75),
                secondary: (0.05, 0.55, 0.45),
                glow: 0.85, speed: 1.40
            )
        case .error:
            return EmotionPalette(
                primary:   (1.00, 0.30, 0.30),
                secondary: (0.55, 0.05, 0.05),
                glow: 0.95, speed: 1.80
            )
        case .success:
            return EmotionPalette(
                primary:   (0.50, 1.00, 0.40),
                secondary: (0.10, 0.55, 0.10),
                glow: 0.90, speed: 0.65
            )
        case .listening:
            return EmotionPalette(
                primary:   (0.30, 0.80, 1.00),
                secondary: (0.05, 0.35, 0.55),
                glow: 0.70, speed: 0.85
            )
        case .sleeping:
            return EmotionPalette(
                primary:   (0.30, 0.30, 0.55),
                secondary: (0.05, 0.05, 0.20),
                glow: 0.20, speed: 0.20
            )
        }
    }
}

// MARK: - Codable config

struct AbstractAvatarConfig: Codable, Equatable {
    var style: AbstractAvatarStyle
    /// Background color is fixed black for the abstract set; we keep it as a
    /// field anyway so users can tint it later without a schema migration.
    var blackBackground: Bool

    static let `default` = AbstractAvatarConfig(style: .pulseOrb, blackBackground: true)

    func toData() -> Data? { try? JSONEncoder().encode(self) }
    static func from(data: Data) -> AbstractAvatarConfig? {
        try? JSONDecoder().decode(AbstractAvatarConfig.self, from: data)
    }
}
