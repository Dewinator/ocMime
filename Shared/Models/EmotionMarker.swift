import Foundation

// MARK: - Emotion Marker
//
// Emotion markers are a lightweight inline protocol the agent uses to tell
// the Bridge what face to show. They're embedded in normal chat text so they
// work with any OpenClaw build — no new API, no new tool calls, just text.
//
// Format:
//   [emotion:state]
//   [emotion:state,0.8]           // explicit intensity
//   [emotion:state,0.8,context]   // intensity + short context tag
//
// The Bridge strips markers out of the text before it's fed to TTS, so the
// display reacts to them but the user never hears "[emotion thinking]".

struct EmotionMarker: Equatable, Hashable {
    let state: EmotionState
    let intensity: Double
    let context: String?

    /// Regex: `[emotion:name]` or `[emotion:name,0.8]` or `[emotion:name,0.8,ctx]`
    /// Case-insensitive on the state name. Whitespace around fields allowed.
    private static let pattern: NSRegularExpression = {
        let expr = #"\[emotion:\s*([a-zA-Z_]+)\s*(?:,\s*([0-9.]+))?\s*(?:,\s*([^\]]*))?\]"#
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: expr, options: [])
    }()

    /// Parse all markers out of `text`. Returns the markers in document order
    /// plus the text with markers removed (ready for TTS or logging).
    static func parse(_ text: String) -> (markers: [EmotionMarker], cleanedText: String) {
        guard !text.isEmpty else { return ([], text) }

        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = pattern.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return ([], text) }

        var markers: [EmotionMarker] = []
        var cleaned = ""
        var cursor = 0

        for match in matches {
            let matchRange = match.range
            // Append text before the marker verbatim.
            if matchRange.location > cursor {
                cleaned += ns.substring(with: NSRange(location: cursor, length: matchRange.location - cursor))
            }
            cursor = matchRange.location + matchRange.length

            // Group 1: state name
            let stateRange = match.range(at: 1)
            guard stateRange.location != NSNotFound else { continue }
            let rawState = ns.substring(with: stateRange).lowercased()
            guard let state = EmotionState(rawValue: rawState) else { continue }

            // Group 2: intensity (optional)
            var intensity: Double = 0.7
            let intensityRange = match.range(at: 2)
            if intensityRange.location != NSNotFound {
                let intensityStr = ns.substring(with: intensityRange)
                if let parsed = Double(intensityStr) {
                    intensity = min(max(parsed, 0), 1)
                }
            }

            // Group 3: context tag (optional)
            var context: String? = nil
            let contextRange = match.range(at: 3)
            if contextRange.location != NSNotFound {
                let trimmed = ns.substring(with: contextRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { context = trimmed }
            }

            markers.append(EmotionMarker(state: state, intensity: intensity, context: context))
        }

        // Append any trailing text after the last marker.
        if cursor < ns.length {
            cleaned += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
        }

        // Collapse any double whitespace left behind where markers used to be.
        let collapsed = cleaned
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (markers, collapsed)
    }
}
