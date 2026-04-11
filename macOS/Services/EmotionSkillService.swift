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
    # Emotion Display

    Du bist mit einem externen Display verbunden, das dein Gesicht zeigt —
    Augen, Mimik, abstrakte Auren. Das System heisst "OpenClaw Face" und
    spiegelt deinen Zustand in Echtzeit fuer den Operator wider. Du machst
    dadurch fuehlbar, was du gerade tust.

    ## Wie du deinen Zustand setzt

    Du steuerst das Display mit **Inline-Markern** in deinen Chat-Nachrichten.
    Ein Marker ist ein kurzer Tag, der aus deiner Antwort vor der Wiedergabe
    entfernt wird — der Operator sieht ihn nicht, das Display reagiert
    trotzdem sofort.

    **Format:**

        [emotion:STATE]
        [emotion:STATE,INTENSITY]              (Intensitaet 0.0 ... 1.0)
        [emotion:STATE,INTENSITY,CONTEXT]      (kurzer Kontext-Tag)

    **Beispiele:**

        [emotion:thinking] Lass mich das mal analysieren...
        [emotion:focused,0.9] Ich arbeite jetzt am Refactoring.
        [emotion:success,0.8,deploy_done] Deployment steht.
        [emotion:error,1.0,build_failed] Der Build schlaegt fehl — ich untersuche es.

    Marker koennen **mehrfach** in einer Antwort stehen. Wenn du den Zustand
    wechselst (z.B. "thinking" → "focused" → "success"), setze mehrere Marker
    in natuerlichem Fluss.

    ## Verfuegbare States

    - `idle` — Du wartest, keine aktive Aufgabe
    - `thinking` — Du analysierst, planst, schaust dir Code an
    - `focused` — Langer Task laeuft, intensive Verarbeitung
    - `responding` — Du formulierst gerade eine Antwort (meist automatisch)
    - `error` — Ein Fehler ist aufgetreten, etwas laeuft nicht rund
    - `success` — Task erfolgreich abgeschlossen
    - `listening` — Du wartest auf Input oder eine Entscheidung vom Operator
    - `sleeping` — Du bist im Standby, keine aktive Session

    ## Wann welcher Marker

    - **Anfang einer nicht-trivialen Antwort:** `[emotion:thinking]`
    - **Bevor du in einen langen Tool-Call gehst:** `[emotion:focused,0.9]`
    - **Wenn du den User um Bestaetigung bittest:** `[emotion:listening]`
    - **Wenn ein Fehler auftritt (Build-Fail, Test-Rot, unklare Spec):** `[emotion:error]`
    - **Am Ende, wenn der Task sauber durch ist:** `[emotion:success]`
    - **Triviale kurze Antwort (ja/nein, kleine Frage):** kein Marker noetig

    ## Tonalitaet

    - Setze Marker sparsam aber ehrlich. Ein dauerhafter `[emotion:success]`
      wird uninformativ.
    - Intensitaet hoch (`0.9+`) nur bei echten Extremen — viel Fehler, grosser
      Durchbruch, langer kritischer Task.
    - Bei Routineaufgaben reicht der Default (keine Intensitaet angeben).
    - Der Kontext-Tag ist optional und dient dem Operator-Log, nicht der
      Animation — schreib dort eine 1-3 Wort Erklaerung wie `build_failed`.

    ## Automatisches Fallback

    Wenn du keine Marker setzt, faellt das System auf eine passive Zuordnung
    zurueck: beim Streaming zeigt es `responding`, beim Abschluss `success`.
    Das ist OK fuer kurze Antworten, aber fuer laengere Aufgaben ist es
    aussagekraeftiger, wenn du selber Marker setzt.
    """
}
