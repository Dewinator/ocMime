import Foundation
import Network

@MainActor
final class BonjourServer: ObservableObject {

    @Published var isRunning = false
    @Published var connectedDevice: String?
    @Published var lastError: String?

    private var listener: NWListener?
    private var activeConnection: NWConnection?

    func start() {
        guard !isRunning else { return }

        let parameters = NWParameters.tcp
        let framerOptions = NWProtocolFramer.Options(definition: EmotionFramerProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)

        do {
            listener = try NWListener(using: parameters)
        } catch {
            lastError = "Listener erstellen fehlgeschlagen: \(error.localizedDescription)"
            return
        }

        listener?.service = NWListener.Service(name: BonjourConstants.serviceName, type: BonjourConstants.serviceType)

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isRunning = true
                    self?.lastError = nil
                case .failed(let error):
                    self?.isRunning = false
                    self?.lastError = "Listener Fehler: \(error.localizedDescription)"
                case .cancelled:
                    self?.isRunning = false
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

    func stop() {
        listener?.cancel()
        listener = nil
        activeConnection?.cancel()
        activeConnection = nil
        isRunning = false
        connectedDevice = nil
    }

    func sendEmotion(_ state: EmotionState, intensity: Double = 0.5, context: String? = nil) {
        let command = EmotionCommand.emotion(state, intensity: intensity, context: context)
        send(command)
    }

    func sendPing() {
        send(.ping)
    }

    func sendAvatarConfig(_ config: AvatarConfig) {
        send(.avatarUpdate(config))
    }

    func sendCustomAvatarConfig(_ config: CustomAvatarConfig) {
        send(.customAvatarUpdate(config))
    }

    func sendRiveAvatarConfig(_ config: RiveAvatarConfig) {
        send(.riveAvatarUpdate(config))
    }

    func sendTTS(text: String, locale: String = "de-DE", rate: Double = 0.5) {
        send(.tts(text: text, locale: locale, rate: rate))
    }

    func sendTTSStop() {
        send(.ttsStop)
    }

    /// Callback for sensor data received from iOS (STT, presence, sound)
    var onSensorReceived: ((SensorCommand) -> Void)?

    private func send(_ command: EmotionCommand) {
        guard let connection = activeConnection, let data = command.toData() else { return }

        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "emotion", metadata: [message])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.lastError = "Send Fehler: \(error.localizedDescription)"
                }
            }
        })
    }

    private func handleNewConnection(_ connection: NWConnection) {
        // Nur eine Verbindung gleichzeitig
        activeConnection?.cancel()
        activeConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    let endpoint = connection.endpoint
                    self?.connectedDevice = "\(endpoint)"
                    self?.lastError = nil
                case .failed(let error):
                    self?.connectedDevice = nil
                    self?.lastError = "Verbindung verloren: \(error.localizedDescription)"
                    self?.activeConnection = nil
                case .cancelled:
                    self?.connectedDevice = nil
                    self?.activeConnection = nil
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        receiveLoop(connection)
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receiveMessage { data, context, isComplete, error in
            if let data {
                // Try parsing as SensorCommand first (STT, presence, sound)
                if let sensor = SensorCommand.from(data: data) {
                    Task { @MainActor [weak self] in
                        self?.onSensorReceived?(sensor)
                    }
                } else if let ack = EmotionAck.from(data: data) {
                    if !ack.ack {
                        Task { @MainActor [weak self] in
                            self?.lastError = "Display Error: \(ack.error ?? "unknown")"
                        }
                    }
                }
            }

            if error == nil {
                Task { @MainActor [weak self] in
                    self?.receiveLoop(connection)
                }
            }
        }
    }
}
