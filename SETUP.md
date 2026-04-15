# Setup & Gerätetest

Kurzanleitung für den ersten Hardware-Smoke-Test. Liest sich in 3 Minuten,
nimmt an, dass beide Targets frisch gebaut sind und ein OpenClaw-Gateway auf
deinem Mac läuft.

## 0. Vorbedingungen

| Komponente         | Erwartet                                    |
|--------------------|---------------------------------------------|
| macOS              | 14+, Xcode 16+                              |
| iPad / iPhone      | iOS 17+, im selben WLAN wie der Mac         |
| OpenClaw Gateway   | lokal laufend, WebSocket-URL + Token bekannt|
| Beide Apps         | via `xcodegen generate && xcodebuild` gebaut|

Einmalig im Repo:

```bash
xcodegen generate
open OpenClawFace.xcodeproj
```

macOS-Target `OpenClawFace` auf deinem Mac ausführen, iOS-Target
`OpenClawDisplay` auf dein iPad/iPhone deployen.

## 1. macOS Bridge verbinden

1. `OpenClawFace.app` starten
2. Tab `[CONFIG]`
3. **host** (z.B. `localhost` oder `100.64.0.1`), **port** (default `18789`),
   **token** eintragen → `[CONNECT]`
4. Statuszeile im Dashboard muss `Gateway` auf grün haben

Beim ersten Start fragt macOS nach Erlaubnis, das lokale Netzwerk zu nutzen —
**akzeptieren**, sonst findet kein iPad den Mac.

## 2. iOS Display pairen

1. `OpenClawDisplay.app` auf dem iPad starten
2. Beim ersten Start fragt iOS nach Erlaubnissen. **Alle akzeptieren:**
   - Lokales Netzwerk (Bonjour)
   - Mikrofon
   - Spracherkennung
   - Kamera (für Presence-Detection)
3. Der Bildschirm zeigt einen pulsierenden grünen Orb — das ist der
   `pulseOrb` Default-Avatar im `abstract` Modus
4. Im Mac-Dashboard muss jetzt `Display: verbunden <endpoint>` stehen und
   der Link-Log (`$ tail -f link.log`) den Verbindungsaufbau protokollieren

**Nicht gepaired?** Im Dashboard `[PING DISPLAY]` drücken. Wenn der Button
ausgegraut ist, hat die Bridge noch keine Verbindung akzeptiert. Mögliche
Gründe:
- Mac und iPad in unterschiedlichen WLANs
- Firewall auf dem Mac blockt eingehende Verbindungen
- Bonjour-Permission auf iPad oder Mac verweigert (System Settings →
  Privacy & Security → Local Network)

## 3. Avatar testen (optional)

1. Tab `[AVATAR]`
2. Zwischen `[ABSTRACT]`, `[EYES]`, `[CUSTOM]` wechseln
3. Emotion-Buttons anklicken, Live-Preview beobachten
4. `[PUSH TO DISPLAY]` — das iPad sollte den Avatar binnen 100-200 ms
   umschalten

## 4. Voice Upstream scharf schalten

Das ist der Punkt, der mit hoher Wahrscheinlichkeit beim ersten Versuch nicht
funktioniert, weil wir den RPC-Namen raten. Deshalb hier im Detail:

1. Tab `[SKILL]`
2. Unter `$ agents.list` bekommst du die Agenten-Liste vom Gateway
3. Bei deinem Ziel-Agenten:
   - `[SET VOICE]` klicken — er bekommt das Label `[VOICE TARGET]`
   - Optional `[INSTALL SKILL]` — schreibt `EMOTION.md` in den Agent-
     Workspace und lehrt ihn Inline-Marker `[emotion:thinking]`
4. Im Dashboard erscheint jetzt: `Voice -> <agent> via agents.chat`

**Prüfung:** Tab `[SENSOR]` → Mikrofon-Symbol (`STT`) muss grün sein.
In Richtung iPad sprechen. Du solltest sehen:

- `$ sensor-status` → `STT: dein_text` (Live-Transcript)
- `$ tail -f stt.log` → neuer Eintrag mit dem final Transcript
- `$ tail -f sensor.log` → `STT -> <agent>` oder `STT chat failed: ...`

### Wenn `chat failed: ...` kommt

Der RPC-Name passt nicht zu deinem Gateway. Zurück auf `[SKILL]` und die drei
editierbaren Felder anpassen:

| Feld          | Default       | Typische Alternativen       |
|---------------|---------------|-----------------------------|
| `method`      | `agents.chat` | `chat.send`, `messages.create`, `agent.message` |
| `text param`  | `text`        | `message`, `content`, `prompt` |
| `id param`    | `agentId`     | `agent`, `targetAgent`, `to` |

Frag OpenClaw direkt (`gateway methods` oder in den Gateway-Logs schauen, was
andere Clients rufen), bis ein Aufruf durchgeht. Die drei Felder werden
persistent gespeichert, du musst das nur einmal machen.

## 5. Vollschleife testen

Wenn Punkt 4 funktioniert:

1. Ins iPad sprechen: *"Was ist die Hauptstadt von Frankreich?"*
2. Erwarteter Ablauf:
   - iPad Display zeigt `.listening` für einen Moment
   - Display wechselt zu `.responding` (oder Marker-State, falls Agent
     welche emittiert)
   - Agent-Antwort wird via AVSpeechSynthesizer vom iPad gesprochen
   - Dashboard zeigt die Emotion-Log-Einträge, inkl. "via [emotion:*]" bei
     Marker-Hits
3. Wenn nur Schritt 1 passiert: `autoTTSResponse` auf `[SKILL]` checken

## 6. Presence Wake testen

1. iPad so positionieren, dass die Front-Kamera dich sieht
2. Weg aus dem Kamerabild gehen → Display wechselt nach ein paar Sekunden
   auf `.sleeping` (gedämpfter Orb)
3. Zurück in den Fokus → Display geht auf `.idle`
4. Wenn `proactiveGreetOnEntry` angeschaltet ist: der Agent bekommt einen
   Greeting-Chat-Request und antwortet — seine Antwort spricht das iPad vor

## Typische Probleme

| Symptom | Ursache | Fix |
|---------|---------|-----|
| `Display: waiting...` bleibt stehen | Bonjour blockiert | Local Network Permission auf beiden Seiten; gleiches WLAN |
| iPad bleibt schwarz nach App-Start | Szenen-Transition verschluckt | App einmal killen + neu starten, `scenePhase`-Handler triggert dann `client.restart()` |
| `Gateway: error: auth failed` | Token falsch | CONFIG-Tab, Token neu eintragen, `[CONNECT]` |
| STT stumm, Emotion bleibt `.idle` | Mikrofon-Permission verweigert | iOS Settings → OpenClaw Display → Mikrofon + Sprache aktivieren |
| Presence triggert nicht | Kamera-Permission fehlt | iOS Settings → OpenClaw Display → Kamera |
| `chat failed: method not found` | RPC-Name falsch | `[SKILL]` → `method` Feld anpassen (siehe Tabelle oben) |
| Agent antwortet, iPad ist stumm | `autoTTSResponse` aus | `[SKILL]` Toggle einschalten |
| Markers im TTS hörbar (`eckige Klammer emotion focused`) | Parser-Regex verpasst den Tag | Markerformat prüfen — muss `[emotion:state]` sein, ohne Leerzeichen vor dem `:` |

## Terminal-Flow zum Wiederbauen

```bash
cd ocMime
rm -rf OpenClawFace.xcodeproj && xcodegen generate
xcodebuild -scheme OpenClawFace -destination 'platform=macOS' build
xcodebuild -scheme OpenClawDisplay -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

Beide müssen `** BUILD SUCCEEDED **` melden, bevor du auf Hardware deployst.
