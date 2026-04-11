import Combine
import Foundation

@MainActor
final class EmotionRouter: ObservableObject {

    @Published private(set) var currentEmotion: EmotionEvent = EmotionEvent(state: .idle)
    @Published private(set) var emotionLog: [EmotionEvent] = []
    @Published private(set) var lastMarkerState: EmotionState?

    private var cancellables = Set<AnyCancellable>()
    private weak var bonjourServer: BonjourServer?
    private weak var sensorRouter: SensorRouter?
    private weak var agentTarget: AgentTargetService?

    // Remember every marker we've fired in the current chat response, in
    // order. Reset on `final` or `error`. This lets us handle both cumulative
    // deltas (each delta repeats all previous markers) and incremental deltas
    // (each delta carries only new text) correctly, including responses where
    // the agent legitimately revisits the same state multiple times like
    // `thinking -> focused -> thinking`.
    private var firedMarkers: [EmotionMarker] = []
    private var lastAppliedMarker: EmotionMarker?

    func subscribe(to gateway: GatewayService, bonjourServer: BonjourServer, sensorRouter: SensorRouter, agentTarget: AgentTargetService) {
        self.bonjourServer = bonjourServer
        self.sensorRouter = sensorRouter
        self.agentTarget = agentTarget

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

        // Agent-driven markers take priority over the passive mapping below.
        // They apply to both `delta` (streaming) and `final` (completed) events
        // so the display can react mid-sentence.
        let rawText = payload["text"] as? String ?? ""
        let (markers, cleanedText) = EmotionMarker.parse(rawText)
        applyMarkers(markers)

        switch state {
        case "delta":
            // Fall back to the generic "responding" pose only if the agent
            // hasn't already specified something more precise via a marker.
            if lastAppliedMarker == nil {
                setEmotion(.responding, intensity: 0.7, context: "streaming")
            }
        case "final":
            // If the agent explicitly said `[emotion:success]` or similar we
            // respect that; otherwise default to a gentle success.
            if lastAppliedMarker == nil {
                setEmotion(.success, intensity: 0.6, context: "response_complete")
            }
            if !cleanedText.isEmpty, agentTarget?.config.autoTTSResponse ?? true {
                // Route through SensorRouter so the ttsEnabled toggle is
                // respected and the TTS appears in the sensor log.
                sensorRouter?.speak(cleanedText)
            }
            // Reset the marker memory so the next response starts fresh.
            resetMarkerMemory()
        case "error":
            setEmotion(.error, intensity: 0.8, context: "chat_error")
            resetMarkerMemory()
        default:
            break
        }
    }

    /// Apply inline `[emotion:...]` markers extracted from the chat stream.
    ///
    /// Two delta conventions are handled transparently:
    ///
    ///   - **Cumulative** — each delta carries the full text-so-far, so the
    ///     new marker list is a prefix-extension of what we already fired.
    ///     We fire only the tail.
    ///   - **Incremental** — each delta carries only new text, so its marker
    ///     list won't match our history. We fall back to appending and firing
    ///     any marker we haven't already seen at this position.
    private func applyMarkers(_ markers: [EmotionMarker]) {
        guard !markers.isEmpty else { return }

        // Case 1: cumulative deltas — the new list starts with everything
        // we've already fired, and adds more at the tail.
        if markers.count >= firedMarkers.count,
           Array(markers.prefix(firedMarkers.count)) == firedMarkers {
            for marker in markers[firedMarkers.count..<markers.count] {
                fire(marker)
            }
            return
        }

        // Case 2: incremental deltas (or out-of-order) — fire any marker whose
        // state differs from the last one we fired. This matches human
        // intuition: the agent said something new, show it.
        for marker in markers {
            if lastAppliedMarker?.state == marker.state { continue }
            fire(marker)
        }
    }

    private func fire(_ marker: EmotionMarker) {
        let ctx = marker.context ?? "agent_marker"
        setEmotion(marker.state, intensity: marker.intensity, context: ctx)
        lastAppliedMarker = marker
        lastMarkerState = marker.state
        firedMarkers.append(marker)
    }

    private func resetMarkerMemory() {
        firedMarkers.removeAll()
        lastAppliedMarker = nil
        lastMarkerState = nil
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
