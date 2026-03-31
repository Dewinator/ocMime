import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var isConnected: Bool { self == .connected }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .error(let m): return "Error: \(m)"
        }
    }

    var statusColor: String {
        switch self {
        case .connected:    return "online"
        case .connecting:   return "active"
        case .disconnected: return "ready"
        case .error:        return "error"
        }
    }
}
