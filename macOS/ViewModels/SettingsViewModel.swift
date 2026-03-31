import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {

    let gateway: GatewayService

    @Published var host: String = ""
    @Published var port: String = "18789"
    @Published var token: String = ""
    @Published var useSSL: Bool = false
    @Published var nickname: String = "My OpenClaw"

    @Published var isTesting: Bool = false
    @Published var testResult: String?

    private var savedConfigID: UUID?

    init(gateway: GatewayService) {
        self.gateway = gateway
        loadSavedConfig()
    }

    func save() {
        let config = GatewayConnectionConfig(
            id: savedConfigID ?? UUID(),
            nickname: nickname,
            host: host,
            port: Int(port) ?? 18789,
            gatewayToken: token,
            useSSL: useSSL
        )
        savedConfigID = config.id

        // Persist to UserDefaults (config without token)
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "gateway.config")
        }

        // Token to Keychain
        if !token.isEmpty {
            try? KeychainService.save(token, for: KeychainService.gatewayTokenKey(for: config.id))
        }
    }

    func connect() async {
        save()
        let config = buildConfig()
        do {
            try await gateway.connect(to: config)
        } catch {
            // Error is reflected in gateway.connectionState
        }
    }

    func disconnect() {
        gateway.disconnect()
    }

    func testConnection() async {
        isTesting = true
        testResult = nil
        let config = buildConfig()
        let result = await checkReachability(config: config)
        switch result {
        case .success:
            testResult = "OK — Gateway erreichbar"
        case .failure(let msg):
            testResult = "FAIL — \(msg)"
        }
        isTesting = false
    }

    private func buildConfig() -> GatewayConnectionConfig {
        GatewayConnectionConfig(
            id: savedConfigID ?? UUID(),
            nickname: nickname,
            host: host,
            port: Int(port) ?? 18789,
            gatewayToken: token,
            useSSL: useSSL
        )
    }

    private func loadSavedConfig() {
        guard let data = UserDefaults.standard.data(forKey: "gateway.config"),
              let config = try? JSONDecoder().decode(GatewayConnectionConfig.self, from: data) else { return }
        savedConfigID = config.id
        host = config.host
        port = String(config.port)
        useSSL = config.useSSL
        nickname = config.nickname

        // Load token from Keychain
        if let savedToken = try? KeychainService.load(for: KeychainService.gatewayTokenKey(for: config.id)) {
            token = savedToken
        }
    }
}

// MARK: - Reachability Check

func checkReachability(config: GatewayConnectionConfig) async -> ReachabilityResult {
    guard let url = config.wsURL else {
        return .failure("Invalid URL: \(config.displayURL)")
    }

    let session = URLSession(configuration: {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 5
        c.timeoutIntervalForResource = 5
        return c
    }())

    let task = session.webSocketTask(with: url)
    task.resume()

    do {
        let message = try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask { try await task.receive() }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw GatewayError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        task.cancel(with: .normalClosure, reason: nil)

        switch message {
        case .string(let text):
            if text.contains("nonce") || text.contains("challenge") {
                return .success
            }
            return .success
        case .data:
            return .success
        @unknown default:
            return .failure("Unknown frame type")
        }
    } catch {
        task.cancel(with: .normalClosure, reason: nil)
        if let gwError = error as? GatewayError, gwError.isTimeout {
            return .failure("Timeout — Gateway antwortet nicht")
        }
        return .failure(error.localizedDescription)
    }
}

enum ReachabilityResult {
    case success
    case failure(String)
}
