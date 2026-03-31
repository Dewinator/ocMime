import Foundation
import Network

@MainActor
final class BonjourClient: ObservableObject {

    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastEmotion: EmotionCommand?
    @Published var serverName: String?

    private var browser: NWBrowser?
    private var connection: NWConnection?

    var onEmotionReceived: ((EmotionCommand) -> Void)?

    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: BonjourConstants.serviceType, domain: nil), using: parameters)

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                if let result = results.first {
                    self?.connectTo(result.endpoint)
                }
            }
        }

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    break
                case .failed(let error):
                    self?.connectionState = .error("Browse Fehler: \(error.localizedDescription)")
                default:
                    break
                }
            }
        }

        connectionState = .connecting
        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        serverName = nil
    }

    private func connectTo(_ endpoint: NWEndpoint) {
        // Schon verbunden?
        if connection != nil { return }

        let parameters = NWParameters.tcp
        let framerOptions = NWProtocolFramer.Options(definition: EmotionFramerProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(framerOptions, at: 0)

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.connectionState = .connected
                    self?.serverName = "\(endpoint)"
                    self?.receiveLoop()
                case .failed(let error):
                    self?.connectionState = .error(error.localizedDescription)
                    self?.connection = nil
                    // Retry
                    try? await Task.sleep(for: .seconds(2))
                    self?.connectTo(endpoint)
                case .cancelled:
                    self?.connectionState = .disconnected
                    self?.connection = nil
                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    private func receiveLoop() {
        guard let connection else { return }

        connection.receiveMessage { [weak self] data, context, isComplete, error in
            Task { @MainActor in
                if let data, let command = EmotionCommand.from(data: data) {
                    self?.lastEmotion = command
                    self?.onEmotionReceived?(command)

                    // ACK zurueck
                    self?.sendAck(.ok)

                    if command.cmd == "ping" {
                        // Ping beantwortet
                    }
                }

                if error == nil {
                    self?.receiveLoop()
                }
            }
        }
    }

    // MARK: - Send to macOS

    private func sendAck(_ ack: EmotionAck) {
        guard let connection, let data = ack.toData() else { return }

        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "ack", metadata: [message])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    /// Send a sensor command back to macOS Bridge (STT, presence, sound)
    func sendSensorCommand(_ command: SensorCommand) {
        guard let connection, let data = command.toData() else { return }

        let message = NWProtocolFramer.Message(definition: EmotionFramerProtocol.definition)
        let context = NWConnection.ContentContext(identifier: "sensor", metadata: [message])

        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.connectionState = .error("Send Fehler: \(error.localizedDescription)")
                }
            }
        })
    }
}
