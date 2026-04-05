import Combine
import Foundation

@MainActor
final class EmotionRouter: ObservableObject {

    @Published private(set) var currentEmotion: EmotionEvent = EmotionEvent(state: .idle)
    @Published private(set) var emotionLog: [EmotionEvent] = []

    private var cancellables = Set<AnyCancellable>()
    private weak var bonjourServer: BonjourServer?

    func subscribe(to gateway: GatewayService, bonjourServer: BonjourServer) {
        self.bonjourServer = bonjourServer

        gateway.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.handleGatewayEvent(response)
            }
            .store(in: &cancellables)

        gateway.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connecting:
                    self?.setEmotion(.thinking, intensity: 0.3, context: "connecting")
                case .connected:
                    self?.setEmotion(.success, intensity: 0.8, context: "connected")
                case .disconnected:
                    self?.setEmotion(.sleeping, intensity: 0.2, context: "disconnected")
                case .error:
                    self?.setEmotion(.error, intensity: 0.9, context: "connection_error")
                }
            }
            .store(in: &cancellables)
    }

    func setEmotion(_ state: EmotionState, intensity: Double = 0.5, context: String? = nil) {
        let event = EmotionEvent(state: state, intensity: intensity, context: context)
        currentEmotion = event
        emotionLog.append(event)

        if emotionLog.count > 100 {
            emotionLog.removeFirst(emotionLog.count - 100)
        }

        // Forward to iOS display via Bonjour
        bonjourServer?.sendEmotion(state, intensity: intensity, context: context)
    }

    // MARK: - Gateway Event Mapping

    private func handleGatewayEvent(_ response: OCResponse) {
        guard let event = response.event else { return }

        switch event {
        case "chat":
            handleChatEvent(response)
        case "agent.status":
            handleAgentStatusEvent(response)
        default:
            break
        }
    }

    private func handleChatEvent(_ response: OCResponse) {
        guard let payload = response.responseData,
              let state = payload["state"] as? String else { return }

        switch state {
        case "delta":
            setEmotion(.responding, intensity: 0.7, context: "streaming")
        case "final":
            setEmotion(.success, intensity: 0.6, context: "response_complete")
            if let text = payload["text"] as? String, !text.isEmpty {
                bonjourServer?.sendTTS(text: text, locale: payload["locale"] as? String ?? "de-DE", rate: 0.5)
            }
        case "error":
            setEmotion(.error, intensity: 0.8, context: "chat_error")
        default:
            break
        }
    }

    private func handleAgentStatusEvent(_ response: OCResponse) {
        guard let payload = response.responseData,
              let status = payload["status"] as? String else { return }

        switch status {
        case "thinking", "planning":
            setEmotion(.thinking, intensity: 0.6, context: status)
        case "executing", "running":
            setEmotion(.focused, intensity: 0.8, context: status)
        case "idle", "ready":
            setEmotion(.idle, intensity: 0.3, context: status)
        case "waiting":
            setEmotion(.listening, intensity: 0.4, context: status)
        case "error":
            setEmotion(.error, intensity: 0.9, context: status)
        case "done", "complete":
            setEmotion(.success, intensity: 0.7, context: status)
        default:
            break
        }
    }
}
