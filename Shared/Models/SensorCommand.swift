import Foundation

// ════════════════════════════════════════════
// MARK: - Sensor Command (iOS → macOS)
// ════════════════════════════════════════════

/// Commands sent from iOS Display back to macOS Bridge (sensor data, STT results, etc.)
struct SensorCommand: Codable {
    let cmd: String           // "stt", "presence", "sound"
    let text: String?         // STT: recognized text
    let isFinal: Bool?        // STT: final vs. partial result
    let locale: String?       // STT/TTS: language locale (e.g. "de-DE")
    let detected: Bool?       // Presence: person detected?
    let personCount: Int?     // Presence: number of persons
    let confidence: Double?   // Presence/Sound: detection confidence
    let soundType: String?    // Sound: classified sound type (e.g. "knock", "speech")

    // MARK: - STT Factories

    static func stt(text: String, isFinal: Bool, locale: String = "de-DE") -> SensorCommand {
        SensorCommand(cmd: "stt", text: text, isFinal: isFinal, locale: locale, detected: nil, personCount: nil, confidence: nil, soundType: nil)
    }

    // MARK: - Presence Factories

    static func presence(detected: Bool, personCount: Int = 0, confidence: Double = 0.9) -> SensorCommand {
        SensorCommand(cmd: "presence", text: nil, isFinal: nil, locale: nil, detected: detected, personCount: personCount, confidence: confidence, soundType: nil)
    }

    // MARK: - Sound Factories

    static func sound(type: String, confidence: Double) -> SensorCommand {
        SensorCommand(cmd: "sound", text: nil, isFinal: nil, locale: nil, detected: nil, personCount: nil, confidence: confidence, soundType: type)
    }

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> SensorCommand? {
        try? JSONDecoder().decode(SensorCommand.self, from: data)
    }
}

// ════════════════════════════════════════════
// MARK: - TTS Command (macOS → iOS)
// ════════════════════════════════════════════

/// Extension to EmotionCommand for TTS commands sent from macOS to iOS
extension EmotionCommand {

    static func tts(text: String, locale: String = "de-DE", rate: Double = 0.5) -> EmotionCommand {
        EmotionCommand(
            cmd: "tts",
            state: nil,
            intensity: rate,
            context: locale,
            avatar: nil,
            customAvatar: nil,
            riveAvatar: nil,
            abstractAvatar: nil,
            ttsText: text
        )
    }

    static var ttsStop: EmotionCommand {
        EmotionCommand(
            cmd: "ttsStop",
            state: nil,
            intensity: nil,
            context: nil,
            avatar: nil,
            customAvatar: nil,
            riveAvatar: nil,
            abstractAvatar: nil,
            ttsText: nil
        )
    }
}
