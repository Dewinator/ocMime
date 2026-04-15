import Combine
import Foundation

/// Receives and processes sensor data from the iOS Display (STT, presence, sound).
/// Bridges sensor events to the Gateway and EmotionRouter.
@MainActor
final class SensorRouter: ObservableObject {

    // MARK: - Published State

    @Published private(set) var sttLog: [STTEntry] = []
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var isPersonPresent = false
    @Published private(set) var personCount = 0
    @Published private(set) var lastSoundType: String?
    @Published private(set) var lastSoundConfidence: Double = 0
    @Published private(set) var sensorLog: [SensorLogEntry] = []

    // MARK: - Configuration

    @Published var sttEnabled = true
    @Published var presenceEnabled = true
    @Published var soundEnabled = true
    @Published var ttsEnabled = true
    @Published var ttsLocale: String = "de-DE"
    @Published var ttsRate: Double = 0.5

    private weak var bonjourServer: BonjourServer?
    private weak var emotionRouter: EmotionRouter?
    private weak var gateway: GatewayService?
    private weak var agentTarget: AgentTargetService?

    // MARK: - Subscribe

    func subscribe(to bonjourServer: BonjourServer, emotionRouter: EmotionRouter, gateway: GatewayService, agentTarget: AgentTargetService) {
        self.bonjourServer = bonjourServer
        self.emotionRouter = emotionRouter
        self.gateway = gateway
        self.agentTarget = agentTarget

        bonjourServer.onSensorReceived = { [weak self] command in
            self?.handleSensorCommand(command)
        }
    }

    // MARK: - Handle Sensor Commands

    private func handleSensorCommand(_ command: SensorCommand) {
        switch command.cmd {
        case "stt":
            handleSTT(command)
        case "presence":
            handlePresence(command)
        case "sound":
            handleSound(command)
        default:
            break
        }
    }

    // MARK: - STT

    private func handleSTT(_ command: SensorCommand) {
        guard sttEnabled else { return }
        guard let text = command.text else { return }
        let isFinal = command.isFinal ?? true

        lastTranscript = text

        if isFinal && !text.isEmpty {
            let entry = STTEntry(text: text, locale: command.locale ?? "de-DE", timestamp: Date())
            sttLog.append(entry)
            if sttLog.count > 50 { sttLog.removeFirst() }

            addLog(.stt, detail: text)

            // Local display: flash listening so the operator sees the capture.
            emotionRouter?.setEmotion(.listening, intensity: 0.6, context: "stt_input")

            // Generic sensor.event relay — agents can subscribe to this if they
            // want raw transcripts without being the direct chat target.
            forwardGatewayEvent(name: "stt.transcript", payload: [
                "text": text,
                "isFinal": true,
                "locale": command.locale ?? "de-DE"
            ], logType: .stt)

            // Direct chat upstream: if the user has designated a target agent
            // via the SKILL tab, actually send the voice input as a chat
            // message. The reply lands back through GatewayService.eventSubject
            // → EmotionRouter.handleChatEvent → TTS (auto-spoken below).
            sendVoiceToAgent(text: text)
        }
    }

    private func sendVoiceToAgent(text: String) {
        guard let target = agentTarget?.config, target.isConfigured else { return }
        guard let gateway, gateway.connectionState.isConnected else {
            addLog(.stt, detail: "gateway offline — chat upstream skipped")
            return
        }
        Task { [weak self] in
            do {
                _ = try await gateway.sendChatMessage(target: target, text: text)
                await MainActor.run {
                    self?.addLog(.stt, detail: "-> \(target.agentLabel.isEmpty ? target.agentId : target.agentLabel)")
                }
            } catch {
                await MainActor.run {
                    self?.addLog(.stt, detail: "chat failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Presence

    private func handlePresence(_ command: SensorCommand) {
        guard presenceEnabled else { return }
        let detected = command.detected ?? false
        let count = command.personCount ?? 0
        let confidence = command.confidence ?? 0

        let wasPresent = isPersonPresent
        isPersonPresent = detected
        personCount = count

        if detected && !wasPresent {
            addLog(.presence, detail: "Person entered (\(count), confidence: \(String(format: "%.0f%%", confidence * 100)))")
            // Wake up agent when someone enters
            emotionRouter?.setEmotion(.idle, intensity: 0.5, context: "person_entered")
            forwardGatewayEvent(name: "presence.entered", payload: [
                "detected": true,
                "personCount": count,
                "confidence": confidence
            ], logType: .presence)

            // Optional: ask the target agent to greet the newcomer. Off by
            // default because it surprises people the first time it happens.
            if let target = agentTarget?.config, target.isConfigured, target.proactiveGreetOnEntry,
               let gateway, gateway.connectionState.isConnected {
                Task { [weak self] in
                    do {
                        _ = try await gateway.sendChatMessage(
                            target: target,
                            text: "Eine Person hat gerade den Raum betreten. Begruesse sie kurz und freundlich auf Deutsch."
                        )
                    } catch {
                        await MainActor.run {
                            self?.addLog(.presence, detail: "greet failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else if !detected && wasPresent {
            addLog(.presence, detail: "Room empty")
            emotionRouter?.setEmotion(.sleeping, intensity: 0.3, context: "room_empty")
            forwardGatewayEvent(name: "presence.empty", payload: [
                "detected": false,
                "personCount": 0,
                "confidence": confidence
            ], logType: .presence)
        }
    }

    // MARK: - Sound

    private func handleSound(_ command: SensorCommand) {
        guard soundEnabled else { return }
        guard let soundType = command.soundType else { return }
        let confidence = command.confidence ?? 0

        lastSoundType = soundType
        lastSoundConfidence = confidence

        addLog(.sound, detail: "\(soundType) (\(String(format: "%.0f%%", confidence * 100)))")
        forwardGatewayEvent(name: "sound.classified", payload: [
            "soundType": soundType,
            "confidence": confidence
        ], logType: .sound)

        // React to specific sounds
        switch soundType {
        case "knock", "doorbell":
            emotionRouter?.setEmotion(.listening, intensity: 0.7, context: "sound_\(soundType)")
        case "speech":
            // Speech detected but STT not active — could notify
            break
        default:
            break
        }
    }

    // MARK: - TTS (macOS → iOS)

    func speak(_ text: String) {
        guard ttsEnabled else { return }
        bonjourServer?.sendTTS(text: text, locale: ttsLocale, rate: ttsRate)
        addLog(.tts, detail: text)
        forwardGatewayEvent(name: "tts.requested", payload: [
            "text": text,
            "locale": ttsLocale,
            "rate": ttsRate
        ], logType: .tts)
    }

    func stopSpeaking() {
        bonjourServer?.sendTTSStop()
    }

    // MARK: - Sensor Control Commands (macOS → iOS)

    func sendStartSTT() {
        // STT is started/stopped from iOS side based on config
        // This is just for logging
        addLog(.stt, detail: "STT enabled")
    }

    func sendStopSTT() {
        addLog(.stt, detail: "STT disabled")
    }

    // MARK: - Log

    /// Public entry point so other routers (EmotionRouter) can surface
    /// gateway/chat activity to the user-visible sensor log for diagnostics.
    func logEvent(_ type: SensorLogEntry.SensorType, detail: String) {
        addLog(type, detail: detail)
    }

    private func addLog(_ type: SensorLogEntry.SensorType, detail: String) {
        let entry = SensorLogEntry(type: type, detail: detail, timestamp: Date())
        sensorLog.append(entry)
        if sensorLog.count > 100 { sensorLog.removeFirst() }
    }

    private func forwardGatewayEvent(name: String, payload: [String: Any], logType: SensorLogEntry.SensorType) {
        guard let gateway else { return }
        Task {
            do {
                _ = try await gateway.sendSensorEvent(name, payload: payload)
            } catch {
                await MainActor.run {
                    self.addLog(logType, detail: "Gateway relay failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Data Models

struct STTEntry: Identifiable {
    let id = UUID()
    let text: String
    let locale: String
    let timestamp: Date
}

struct SensorLogEntry: Identifiable {
    let id = UUID()
    let type: SensorType
    let detail: String
    let timestamp: Date

    enum SensorType: String {
        case stt = "STT"
        case tts = "TTS"
        case presence = "CAM"
        case sound = "SND"
    }
}
