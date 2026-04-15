import Combine
import Foundation

@MainActor
final class GatewayService: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: String?
    @Published private(set) var reconnectAttempt: Int = 0

    // MARK: - Private

    private var webSocketTask: URLSessionWebSocketTask?
    private var pendingRequests: [String: CheckedContinuation<OCResponse, Error>] = [:]
    private var config: GatewayConnectionConfig?
    private var deviceToken: String?
    private var shouldReconnect = false
    private var reconnectTask: Task<Void, Never>?

    let eventSubject = PassthroughSubject<OCResponse, Never>()

    init() {}

    // MARK: - Connect

    func connect(to config: GatewayConnectionConfig) async throws {
        self.config = config
        self.shouldReconnect = true
        reconnectAttempt = 0
        try await performConnect(config)
    }

    private func performConnect(_ config: GatewayConnectionConfig) async throws {
        connectionState = .connecting
        lastError = nil

        do {
            guard let url = config.wsURL else { throw GatewayError.invalidURL }

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            var request = URLRequest(url: url)
            request.setValue("OpenClawFace/\(version) macOS", forHTTPHeaderField: "User-Agent")

            let session = URLSession(configuration: .default)
            webSocketTask = session.webSocketTask(with: request)
            webSocketTask?.resume()

            let challenge = try await waitForNonce()

            let identity = DeviceIdentity.current
            let signedAt = Int64(Date().timeIntervalSince1970 * 1000)
            let scopes = ["operator.admin", "operator.approvals", "operator.pairing"]
            let signature = identity.signConnect(nonce: challenge.nonce, token: config.gatewayToken, signedAtMs: signedAt)

            let connectFrame: [String: Any] = [
                "type": "req",
                "id": UUID().uuidString,
                "method": "connect",
                "params": [
                    "minProtocol": 3,
                    "maxProtocol": 3,
                    "client": [
                        "id": "openclaw-macos",
                        "version": version,
                        "platform": "macos",
                        "mode": "ui"
                    ] as [String: Any],
                    "role": "operator",
                    "scopes": scopes,
                    "auth": [
                        "token": config.gatewayToken
                    ] as [String: Any],
                    "device": [
                        "id": identity.id,
                        "publicKey": identity.publicKey,
                        "signature": signature,
                        "signedAt": signedAt,
                        "nonce": challenge.nonce
                    ] as [String: Any],
                    "locale": Locale.current.identifier,
                    "userAgent": "OpenClawFace/\(version) macOS"
                ] as [String: Any]
            ]

            Task { await receiveLoop() }
            try await Task.sleep(for: .milliseconds(50))

            let connectID = connectFrame["id"] as? String ?? ""
            let connectData = try JSONSerialization.data(withJSONObject: connectFrame)
            let connectString = String(data: connectData, encoding: .utf8)!

            let connectResponse: OCResponse = try await withCheckedThrowingContinuation { continuation in
                pendingRequests[connectID] = continuation
                Task {
                    do {
                        try await webSocketTask?.send(.string(connectString))
                    } catch {
                        pendingRequests.removeValue(forKey: connectID)
                        continuation.resume(throwing: error)
                    }
                }
            }

            if connectResponse.ok == false || connectResponse.error != nil {
                let code = connectResponse.error?.code ?? "auth-failed"
                let message = connectResponse.error?.message ?? "Authentication failed"
                throw GatewayError.serverError("\(code): \(message)")
            }

            if let payload = connectResponse.responseData,
               let token = payload["deviceToken"] as? String {
                self.deviceToken = token
            }

            connectionState = .connected
            reconnectAttempt = 0

        } catch {
            connectionState = .error(error.localizedDescription)
            lastError = error.localizedDescription
            throw error
        }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        deviceToken = nil
        pendingRequests.values.forEach { $0.resume(throwing: GatewayError.notConnected) }
        pendingRequests.removeAll()
        connectionState = .disconnected
    }

    // MARK: - Auto-Connect

    func autoConnect() {
        guard let data = UserDefaults.standard.data(forKey: "gateway.config"),
              let config = try? JSONDecoder().decode(GatewayConnectionConfig.self, from: data),
              !config.host.isEmpty else { return }

        // Load token from Keychain
        var fullConfig = config
        if let token = try? KeychainService.load(for: KeychainService.gatewayTokenKey(for: config.id)) {
            fullConfig = GatewayConnectionConfig(
                id: config.id,
                nickname: config.nickname,
                host: config.host,
                port: config.port,
                gatewayToken: token,
                useSSL: config.useSSL,
                isDefault: config.isDefault
            )
        }

        guard !fullConfig.gatewayToken.isEmpty else { return }

        Task {
            do {
                try await connect(to: fullConfig)
            } catch {
                // Auto-connect failed — reconnect will handle it
            }
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard shouldReconnect, let config else { return }

        reconnectTask?.cancel()
        reconnectAttempt += 1

        // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt - 1)))

        reconnectTask = Task {
            do {
                try await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, shouldReconnect else { return }
                try await performConnect(config)
            } catch {
                guard !Task.isCancelled, shouldReconnect else { return }
                scheduleReconnect()
            }
        }
    }

    // MARK: - Request / Response

    func sendRequest(_ method: String, params: [String: Any]? = nil) async throws -> OCResponse {
        guard connectionState.isConnected else { throw GatewayError.notConnected }

        let reqID = UUID().uuidString
        var envelope: [String: Any] = [
            "type": "req",
            "id": reqID,
            "method": method
        ]
        if let params { envelope["params"] = params }

        let data = try JSONSerialization.data(withJSONObject: envelope)
        let string = String(data: data, encoding: .utf8)!

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[reqID] = continuation
            Task {
                do {
                    try await webSocketTask?.send(.string(string))
                } catch {
                    pendingRequests.removeValue(forKey: reqID)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Convenience

    func fetchStatus() async throws -> OCResponse {
        return try await sendRequest("status")
    }

    func sendSensorEvent(_ event: String, payload: [String: Any]) async throws -> OCResponse {
        try await sendRequest("sensor.event", params: [
            "event": event,
            "payload": payload
        ])
    }

    /// Voice-to-chat upstream. Uses the user-configured RPC method and field
    /// names so this still works against gateways with a non-standard chat
    /// surface. The caller supplies the target agent + the user-provided text.
    /// Returns the gateway's immediate ack; the actual agent reply arrives
    /// asynchronously via `eventSubject` like any other chat event.
    func sendChatMessage(target: AgentTargetConfig, text: String) async throws -> OCResponse {
        guard target.isConfigured else { throw GatewayError.notConfigured }
        let params: [String: Any] = [
            target.paramNameForAgentId: target.agentId,
            target.paramNameForText: text,
            "idempotencyKey": UUID().uuidString
        ]
        let response = try await sendRequest(target.chatMethod, params: params)
        if response.ok == false || response.error != nil {
            let code = response.error?.code ?? "chat-failed"
            let message = response.error?.message ?? "Gateway refused chat request"
            throw GatewayError.serverError("\(code): \(message)")
        }
        return response
    }

    // MARK: - Wait for Nonce

    struct ChallengeInfo {
        let nonce: String
        let ts: Int64
    }

    private func waitForNonce() async throws -> ChallengeInfo {
        guard let task = webSocketTask else { throw GatewayError.notConnected }

        let message: URLSessionWebSocketTask.Message = try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask { try await task.receive() }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw GatewayError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let d): data = d
        @unknown default: throw GatewayError.unexpectedFrame
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayError.unexpectedFrame
        }

        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? String ?? "gateway-error"
            let message = error["message"] as? String ?? "Gateway rejected connection"
            throw GatewayError.serverError("\(code): \(message)")
        }

        guard let payload = json["payload"] as? [String: Any],
              let nonce = payload["nonce"] as? String else {
            let preview = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            throw GatewayError.serverError("unexpected-frame: \(preview)")
        }

        let ts = (payload["ts"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
        return ChallengeInfo(nonce: nonce, ts: ts)
    }

    // MARK: - Receive Loop

    private func receiveLoop() async {
        while let task = webSocketTask {
            do {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let d):
                    data = d
                @unknown default:
                    continue
                }

                if let response = OCResponse(data: data) {
                    handleResponse(response)
                }

            } catch {
                if connectionState == .connected {
                    connectionState = .disconnected
                    lastError = "Connection lost: \(error.localizedDescription)"
                    webSocketTask = nil
                    scheduleReconnect()
                }
                break
            }
        }
    }

    private func handleResponse(_ response: OCResponse) {
        if let id = response.id, let continuation = pendingRequests.removeValue(forKey: id) {
            continuation.resume(returning: response)
            return
        }
        eventSubject.send(response)
    }
}
