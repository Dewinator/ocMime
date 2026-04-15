import Foundation

// MARK: - Generic WebSocket Response

struct OCResponse: @unchecked Sendable {
    let type: String?
    let id: String?
    let method: String?
    let ok: Bool?
    let error: OCErrorPayload?
    let event: String?
    let raw: [String: Any]

    init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        self.raw = json
        self.type = json["type"] as? String
        self.id = json["id"] as? String
        self.method = json["method"] as? String
        self.ok = json["ok"] as? Bool
        self.event = json["event"] as? String
        if let err = json["error"] as? [String: Any] {
            self.error = OCErrorPayload(
                message: err["message"] as? String,
                code: err["code"] as? String
            )
        } else {
            self.error = nil
        }
    }

    /// Unwraps `payload` / `result` / `data` wrappers when present, otherwise
    /// returns the top-level object. OpenClaw's `broadcast("chat", payload)`
    /// flattens its payload onto the top level, so events like chat deltas
    /// have `state`, `message`, `sessionKey` at the root.
    var responseData: [String: Any]? {
        if let payload = raw["payload"] as? [String: Any] { return payload }
        if let result = raw["result"] as? [String: Any] { return result }
        if let data = raw["data"] as? [String: Any] { return data }
        return raw
    }
}

struct OCErrorPayload: Decodable, Sendable {
    let message: String?
    let code: String?
}

// MARK: - Gateway Errors

enum GatewayError: Error, LocalizedError {
    case invalidURL
    case notConnected
    case notConfigured
    case unexpectedFrame
    case authenticationFailed
    case timeout
    case serverError(String)

    var isTimeout: Bool {
        if case .timeout = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "Invalid gateway URL"
        case .notConnected:           return "Not connected"
        case .notConfigured:          return "No target agent configured"
        case .unexpectedFrame:        return "Unexpected gateway frame"
        case .authenticationFailed:   return "Authentication failed"
        case .timeout:                return "Connection timeout"
        case .serverError(let msg):   return msg
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}
