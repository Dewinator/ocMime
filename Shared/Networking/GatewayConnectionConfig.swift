import Foundation

struct GatewayConnectionConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var nickname: String
    var host: String
    var port: Int
    var gatewayToken: String
    var useSSL: Bool
    var isDefault: Bool

    var wsURL: URL? {
        let scheme = useSSL ? "wss" : "ws"
        return URL(string: "\(scheme)://\(host):\(port)")
    }

    var displayURL: String {
        let scheme = useSSL ? "wss" : "ws"
        return "\(scheme)://\(host):\(port)"
    }

    init(id: UUID = UUID(), nickname: String = "", host: String = "", port: Int = 18789, gatewayToken: String = "", useSSL: Bool = false, isDefault: Bool = true) {
        self.id = id
        self.nickname = nickname
        self.host = host
        self.port = port
        self.gatewayToken = gatewayToken
        self.useSSL = useSSL
        self.isDefault = isDefault
    }

    var isLikelyLocal: Bool {
        host.starts(with: "100.") ||
        host.starts(with: "10.") ||
        host.starts(with: "192.168.") ||
        host.starts(with: "172.") ||
        host == "localhost" ||
        host.starts(with: "127.")
    }
}
