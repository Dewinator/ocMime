import Foundation
import Network
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class BonjourServer: ObservableObject {

    @Published var isRunning = false
    @Published var connectedDevice: String?
    @Published var lastError: String?
    @Published private(set) var diagnostics: [LinkDiagnostic] = []
    @Published private(set) var pathStatus: String = "unknown"

    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.eab.openclawface.bonjour.path")
    private var heartbeatTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    /// Callback for sensor data received from iOS (STT, presence, sound)
    var onSensorReceived: ((SensorCommand) -> Void)?

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        startListener()
        startPathMonitor()
        installWakeObserver()
        startHeartbeat()
    }

    func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        pathMonitor.cancel()
        if let wakeObserver {
            #if canImport(AppKit)
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            #endif
            self.wakeObserver = nil
        }
        listener?.cancel()
        listener = nil
        activeConnection?.cancel()
        activeConnection = nil
        isRunning = false
        connectedDevice = nil
        log(.info, "stopped")
    }

    private func startListener() {
        // If a previous listener is still around, kill it before re-creating.
        listener?.cancel()
        listener = nil

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true
        let framerOptions = NWProtocolFramer.Options(definition: EmotionFramerProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)

        do {
            listener = try NWListener(using: parameters)
        } catch {
            lastError = "Listener erstellen fehlgeschlagen: \(error.localizedDescription)"
            log(.error, "listener init failed: \(error.localizedDescription)")
            return
        }

        listener?.service = NWListener.Service(
            name: BonjourConstants.serviceName,
            type: BonjourConstants.serviceType
        )

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.lastError = nil
                    self.log(.info, "listener ready, advertising")
                case .failed(let error):
                    self.isRunning = false
                    self.lastError = "Listener Fehler: \(error.localizedDescription)"
                    self.log(.error, "listener failed: \(error.localizedDescription)")
                    // Try to recover after a short delay
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .seconds(2))
                        self?.startListener()
                    }
                case .cancelled:
                    self.isRunning = false
                    self.log(.info, "listener cancelled")
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }

        listener?.start(queue: .main)
    }

    // MARK: - Network path monitoring

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let desc: String
                switch path.status {
                case .satisfied:   desc = "satisfied"
                case .unsatisfied: desc = "unsatisfied"
                case .requiresConnection: desc = "requiresConnection"
                @unknown default:  desc = "unknown"
                }
                self.pathStatus = desc
                self.log(.info, "path \(desc)")
                if path.status == .satisfied {
                    // Network came back — make sure the listener is alive.
                    if !self.isRunning {
                        self.startListener()
                    }
                }
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    // MARK: - Wake / Sleep

    private func installWakeObserver() {
        #if canImport(AppKit)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.log(.info, "wake from sleep — restarting listener")
                self?.startListener()
            }
        }
        #endif
    }

    // MARK: - Heartbeat

    /// Sends a ping every 5 seconds while a client is connected. If the
    /// underlying TCP connection silently dies (NAT timeout, sleep), the next
    /// ping will fail and surface the issue immediately instead of having
    /// updates queue up against a half-open socket.
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                if self.activeConnection != nil {
                    self.send(.ping, label: "ping")
                }
            }
        }
    }

    // MARK: - Public sends

    func sendEmotion(_ state: EmotionState, intensity: Double = 0.5, context: String? = nil) {
        send(.emotion(state, intensity: intensity, context: context), label: "emotion=\(state.rawValue)")
    }

    func sendPing() {
        send(.ping, label: "ping")
    }

    func sendAvatarConfig(_ config: AvatarConfig) {
        send(.avatarUpdate(config), label: "avatar=\(config.avatarType.rawValue)")
    }

    func sendCustomAvatarConfig(_ config: CustomAvatarConfig) {
        send(.customAvatarUpdate(config), label: "customAvatar")
    }

    func sendRiveAvatarConfig(_ config: RiveAvatarConfig) {
        send(.riveAvatarUpdate(config), label: "riveAvatar")
    }

    func sendAbstractAvatarConfig(_ config: AbstractAvatarConfig) {
        send(.abstractAvatarUpdate(config), label: "abstractAvatar=\(config.style.rawValue)")
    }

    func sendTTS(text: String, locale: String = "de-DE", rate: Double = 0.5) {
        send(.tts(text: text, locale: locale, rate: rate), label: "tts")
    }

    func sendTTSStop() {
        send(.ttsStop, label: "ttsStop")
    }

    // MARK: - Send pipeline

    private func send(_ command: EmotionCommand, label: String) {
        guard let connection = activeConnection else {
            log(.warning, "drop \(label): no client")
            return
        }
        guard connection.state == .ready else {
            log(.warning, "drop \(label): connection not ready (\(connection.state))")
            return
        }
        guard let data = command.toData() else {
            log(.error, "drop \(label): encode failed")
            return
        }

        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "emotion", metadata: [message])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = "Send Fehler: \(error.localizedDescription)"
                    self.log(.error, "send \(label) failed: \(error.localizedDescription)")
                    // The connection is broken — drop it so the iOS side can re-discover.
                    self.activeConnection?.cancel()
                    self.activeConnection = nil
                    self.connectedDevice = nil
                }
            }
        })
    }

    // MARK: - Connection handling

    private func handleNewConnection(_ connection: NWConnection) {
        // Only one display at a time. Cancel any older one.
        activeConnection?.cancel()
        activeConnection = connection
        log(.info, "client connecting from \(connection.endpoint)")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .ready:
                    self.connectedDevice = "\(connection.endpoint)"
                    self.lastError = nil
                    self.log(.info, "client ready: \(connection.endpoint)")
                case .failed(let error):
                    self.connectedDevice = nil
                    self.lastError = "Verbindung verloren: \(error.localizedDescription)"
                    self.log(.warning, "client failed: \(error.localizedDescription)")
                    if self.activeConnection === connection {
                        self.activeConnection = nil
                    }
                case .cancelled:
                    if self.activeConnection === connection {
                        self.activeConnection = nil
                        self.connectedDevice = nil
                    }
                    self.log(.info, "client cancelled")
                case .waiting(let error):
                    self.log(.warning, "client waiting: \(error.localizedDescription)")
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        receiveLoop(connection)
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            // The receive completion fires on the connection's queue (.main).
            // Hop to MainActor to mutate state.
            Task { @MainActor in
                guard let self else { return }
                if let data {
                    if let sensor = SensorCommand.from(data: data) {
                        self.onSensorReceived?(sensor)
                    } else if let ack = EmotionAck.from(data: data) {
                        if !ack.ack {
                            self.lastError = "Display Error: \(ack.error ?? "unknown")"
                            self.log(.error, "ack-failure: \(ack.error ?? "?")")
                        }
                    }
                }
                if error == nil, self.activeConnection === connection {
                    self.receiveLoop(connection)
                } else if let error {
                    self.log(.warning, "receive error: \(error.localizedDescription)")
                }
            }
        }
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
