import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class BonjourClient: ObservableObject {

    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastEmotion: EmotionCommand?
    @Published var serverName: String?
    @Published private(set) var diagnostics: [LinkDiagnostic] = []
    @Published private(set) var pathStatus: String = "unknown"
    @Published private(set) var discoveredCount: Int = 0

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var connectedEndpoint: NWEndpoint?
    private var isConnecting = false
    private var attemptCount: Int = 0
    private var reconnectTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.eab.openclawdisplay.bonjour.path")

    var onEmotionReceived: ((EmotionCommand) -> Void)?

    // MARK: - Lifecycle

    func startBrowsing() {
        startPathMonitor()
        startBrowser()
    }

    func stopBrowsing() {
        reconnectTask?.cancel()
        reconnectTask = nil
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        pathMonitor.cancel()
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        connectedEndpoint = nil
        isConnecting = false
        attemptCount = 0
        connectionState = .disconnected
        serverName = nil
        log(.info, "stopped")
    }

    /// Hard reset of discovery — used by scenePhase observer when the app
    /// returns to the foreground or when the user manually triggers it.
    func restart() {
        log(.info, "restart requested")
        connection?.cancel()
        connection = nil
        connectedEndpoint = nil
        isConnecting = false
        browser?.cancel()
        browser = nil
        attemptCount = 0
        connectionState = .connecting
        startBrowser()
    }

    private func startBrowser() {
        browser?.cancel()

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let newBrowser = NWBrowser(
            for: .bonjour(type: BonjourConstants.serviceType, domain: nil),
            using: parameters
        )

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                self.discoveredCount = results.count
                self.log(.info, "browse results=\(results.count)")
                // Only try to connect if we don't already have a live one.
                guard self.connection == nil, !self.isConnecting else { return }
                if let endpoint = self.pickBestEndpoint(results) {
                    self.connectTo(endpoint)
                }
            }
        }

        newBrowser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    self.log(.info, "browser ready")
                case .failed(let error):
                    self.connectionState = .error("Browse: \(error.localizedDescription)")
                    self.log(.error, "browser failed: \(error.localizedDescription)")
                    // Try again in a moment.
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        self?.startBrowser()
                    }
                case .cancelled:
                    self.log(.info, "browser cancelled")
                default:
                    break
                }
            }
        }

        browser = newBrowser
        connectionState = .connecting
        newBrowser.start(queue: .main)
    }

    /// Order endpoints so we always try IPv4 / hostname routes first
    /// (more universally reachable across Wi-Fi <-> USB switches).
    private func pickBestEndpoint(_ results: Set<NWBrowser.Result>) -> NWEndpoint? {
        let sorted = results.sorted { lhs, rhs in
            endpointRank(lhs.endpoint) < endpointRank(rhs.endpoint)
        }
        return sorted.first?.endpoint
    }

    private func endpointRank(_ endpoint: NWEndpoint) -> Int {
        switch endpoint {
        case .service:        return 0  // mDNS service — let Network.framework resolve
        case .hostPort:       return 1
        case .url:            return 2
        case .unix:           return 3
        case .opaque:         return 4
        @unknown default:     return 5
        }
    }

    // MARK: - Network path

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let desc: String
                switch path.status {
                case .satisfied:          desc = "satisfied"
                case .unsatisfied:        desc = "unsatisfied"
                case .requiresConnection: desc = "requiresConnection"
                @unknown default:         desc = "unknown"
                }
                self.pathStatus = desc
                self.log(.info, "path \(desc)")
                if path.status == .satisfied {
                    // Network path back — make sure we're actively browsing.
                    if self.browser == nil {
                        self.startBrowser()
                    } else if self.connection == nil && !self.isConnecting {
                        // Already browsing but no link — give it a kick.
                        self.scheduleReconnect()
                    }
                } else {
                    self.connectionState = .error("offline")
                }
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    // MARK: - Connect

    private func connectTo(_ endpoint: NWEndpoint) {
        if connection != nil || isConnecting { return }

        isConnecting = true
        connectedEndpoint = endpoint
        attemptCount += 1
        log(.info, "connect attempt #\(attemptCount) -> \(endpoint)")

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let framerOptions = NWProtocolFramer.Options(definition: EmotionFramerProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)

        let newConnection = NWConnection(to: endpoint, using: parameters)
        connection = newConnection

        // Hard timeout: if the connection doesn't reach .ready in 6s, drop it
        // and try again. NWConnection's own .waiting state can otherwise sit
        // forever on a stale endpoint after Wi-Fi <-> USB switches.
        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { @MainActor [weak self, weak newConnection] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, let newConnection, self.connection === newConnection else { return }
            if newConnection.state != .ready {
                self.log(.warning, "connect timeout, dropping endpoint")
                newConnection.cancel()
                self.connection = nil
                self.isConnecting = false
                self.connectedEndpoint = nil
                self.scheduleReconnect()
            }
        }

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            Task { @MainActor in
                guard let self, let newConnection, self.connection === newConnection else { return }
                switch state {
                case .ready:
                    self.connectTimeoutTask?.cancel()
                    self.connectTimeoutTask = nil
                    self.isConnecting = false
                    self.attemptCount = 0
                    self.connectionState = .connected
                    self.serverName = "\(newConnection.endpoint)"
                    self.log(.info, "connected to \(newConnection.endpoint)")
                    self.receiveLoop()
                case .failed(let error):
                    self.log(.warning, "connection failed: \(error.localizedDescription)")
                    self.handleDrop(error: error.localizedDescription)
                case .cancelled:
                    self.log(.info, "connection cancelled")
                    if self.connection === newConnection {
                        self.connection = nil
                        self.isConnecting = false
                        self.connectedEndpoint = nil
                    }
                case .waiting(let error):
                    self.log(.warning, "waiting: \(error.localizedDescription)")
                default:
                    break
                }
            }
        }

        newConnection.start(queue: .main)
    }

    private func handleDrop(error: String) {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        connection?.cancel()
        connection = nil
        connectedEndpoint = nil
        isConnecting = false
        connectionState = .error(error)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        // Exponential backoff capped at 8s, then re-browse.
        let delay = min(8, 1 << min(attemptCount, 3))
        log(.info, "reconnect in \(delay)s (attempt \(attemptCount + 1))")
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Int(delay)))
            guard let self, !Task.isCancelled else { return }
            // Force a fresh browse — old endpoint may be stale.
            self.startBrowser()
        }
    }

    // MARK: - Receive

    private func receiveLoop() {
        guard let connection else { return }
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, let command = EmotionCommand.from(data: data) {
                    self.lastEmotion = command
                    self.onEmotionReceived?(command)
                    self.sendAck(.ok)
                }
                if let error {
                    self.log(.warning, "receive error: \(error.localizedDescription)")
                    self.handleDrop(error: error.localizedDescription)
                    return
                }
                if self.connection != nil {
                    self.receiveLoop()
                }
            }
        }
    }

    // MARK: - Send

    private func sendAck(_ ack: EmotionAck) {
        guard let connection, connection.state == .ready, let data = ack.toData() else { return }
        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "ack", metadata: [message])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    /// Send a sensor command back to macOS Bridge (STT, presence, sound)
    func sendSensorCommand(_ command: SensorCommand) {
        guard let connection, let data = command.toData() else { return }
        guard connection.state == .ready else {
            log(.warning, "drop sensor=\(command.cmd): connection not ready")
            return
        }

        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "sensor", metadata: [message])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                guard let self, let error else { return }
                self.log(.warning, "send sensor=\(command.cmd) failed: \(error.localizedDescription)")
                self.handleDrop(error: error.localizedDescription)
            }
        })
    }

    // MARK: - Diagnostics

    private func log(_ level: LinkDiagnostic.Level, _ message: String) {
        let entry = LinkDiagnostic(level: level, message: message, timestamp: Date())
        diagnostics.append(entry)
        if diagnostics.count > 60 {
            diagnostics.removeFirst(diagnostics.count - 60)
        }
    }
}
