import Foundation

// MARK: - Sensor Command (iOS → macOS)
//
// Commands sent from iOS Display back to macOS Bridge — sensor data, STT
// results, presence events, sound classifications.

struct SensorCommand: Codable {
    let cmd: String           // "stt" | "presence" | "sound"
    let text: String?         // STT: recognized text
    let isFinal: Bool?        // STT: final vs. partial
    let locale: String?       // STT locale (e.g. "de-DE")
    let detected: Bool?       // Presence: person detected
    let personCount: Int?
    let confidence: Double?
    let soundType: String?    // Sound: classified type (knock, doorbell, speech, ...)

    static func stt(text: String, isFinal: Bool, locale: String = "de-DE") -> SensorCommand {
        SensorCommand(cmd: "stt", text: text, isFinal: isFinal, locale: locale, detected: nil, personCount: nil, confidence: nil, soundType: nil)
    }

    static func presence(detected: Bool, personCount: Int = 0, confidence: Double = 0.9) -> SensorCommand {
        SensorCommand(cmd: "presence", text: nil, isFinal: nil, locale: nil, detected: detected, personCount: personCount, confidence: confidence, soundType: nil)
    }

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
