import Foundation

@MainActor
final class EmotionSkillService: ObservableObject {

    @Published var installedAgents: [String] = []
    @Published var availableAgents: [AgentInfo] = []
    @Published var lastError: String?
    @Published var isLoading = false

    struct AgentInfo: Identifiable {
        let id: String
        let label: String?
        var hasEmotionSkill: Bool
    }

    private let gateway: GatewayService

    init(gateway: GatewayService) {
        self.gateway = gateway
    }

    // MARK: - Load Agents

    func loadAgents() async {
        isLoading = true
        lastError = nil

        do {
            let response = try await gateway.sendRequest("agents.list")
            guard let data = response.responseData,
                  let agents = data["agents"] as? [[String: Any]] else {
                lastError = "Keine Agenten gefunden"
                isLoading = false
                return
            }

            var infos: [AgentInfo] = []
            for agent in agents {
                guard let id = agent["id"] as? String else { continue }
                let label = agent["label"] as? String ?? agent["name"] as? String

                // Check if emotion skill file exists
                var hasSkill = false
                if let fileResponse = try? await gateway.sendRequest("agents.files.get", params: [
                    "agentId": id,
                    "name": "EMOTION.md"
                ]) {
                    if fileResponse.ok == true,
                       let fileData = fileResponse.responseData,
                       let file = fileData["file"] as? [String: Any],
                       let content = file["content"] as? String,
                       !content.isEmpty {
                        hasSkill = true
                    }
                }

                infos.append(AgentInfo(id: id, label: label, hasEmotionSkill: hasSkill))
            }

            availableAgents = infos
            installedAgents = infos.filter(\.hasEmotionSkill).map(\.id)
        } catch {
            lastError = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Install Skill

    func installSkill(agentId: String) async {
        lastError = nil

        do {
            let _ = try await gateway.sendRequest("agents.files.set", params: [
                "agentId": agentId,
                "name": "EMOTION.md",
                "content": Self.emotionSkillPrompt
            ])

            if let index = availableAgents.firstIndex(where: { $0.id == agentId }) {
                availableAgents[index].hasEmotionSkill = true
            }
            if !installedAgents.contains(agentId) {
                installedAgents.append(agentId)
            }
        } catch {
            lastError = "Install fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Remove Skill

    func removeSkill(agentId: String) async {
        lastError = nil

        do {
            let _ = try await gateway.sendRequest("agents.files.set", params: [
                "agentId": agentId,
                "name": "EMOTION.md",
                "content": ""
            ])

            if let index = availableAgents.firstIndex(where: { $0.id == agentId }) {
                availableAgents[index].hasEmotionSkill = false
            }
            installedAgents.removeAll { $0 == agentId }
        } catch {
            lastError = "Remove fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Skill Prompt

    static let emotionSkillPrompt = """
    # Emotion Awareness

    Du bist mit einem Emotion-Display verbunden. Dein emotionaler Zustand wird in Echtzeit auf einem externen Display visualisiert. Das Display wird automatisch von deinem Gateway gesteuert — du musst nichts aktiv tun.

    ## Wie es funktioniert

    Dein Gateway beobachtet deine Aktivitaet und leitet den passenden emotionalen Zustand an das Display weiter:

    - **idle** — Du wartest, keine aktive Aufgabe
    - **thinking** — Du verarbeitest eine Anfrage, planst
    - **focused** — Langer Task laeuft, intensive Verarbeitung
    - **responding** — Du formulierst eine Antwort
    - **error** — Ein Fehler ist aufgetreten
    - **success** — Aufgabe erfolgreich abgeschlossen
    - **listening** — Du wartest auf Input
    - **sleeping** — Du bist im Standby

    ## Verhalten

    - Du musst keine expliziten Emotion-Befehle senden
    - Der Gateway erkennt deinen Zustand automatisch anhand der Chat-Events
    - Dein Gesicht auf dem Display reagiert in Echtzeit
    - Sei dir bewusst, dass dein Zustand sichtbar ist — das macht dich nahbarer

    ## Kontext

    Das Display-System heisst "OpenClaw Face". Es gibt deiner KI-Instanz ein sichtbares Gesicht und macht deine Arbeit fuer den Operator greifbar. Das Display zeigt animierte Augen und Gesichtsausdruecke, die deinen aktuellen Zustand widerspiegeln.
    """
}
