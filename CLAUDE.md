# CLAUDE.md — OpenClaw Face

## Projektuebersicht

**OpenClaw Face** gibt dem lokal laufenden OpenClaw-Agenten ein sichtbares Gesicht. Zwei Apps arbeiten zusammen: Eine macOS-App (Bridge) verbindet sich per WebSocket mit dem lokalen OpenClaw-Gateway und leitet Emotion-Events via Bonjour an ein angeschlossenes iOS-Device weiter. Das iPhone/iPad zeigt als reines Display animierte Gesichter, die den emotionalen Zustand des Agenten in Echtzeit widerspiegeln.

Zielgruppe: Self-Hosted-AI-Enthusiasten mit lokalem OpenClaw-Setup auf einem Mac Mini M4.

---

## Architektur

```
OpenClaw Gateway (localhost:18789)
       |
       | WebSocket (Protocol v3, Ed25519)
       v
macOS App — "OpenClaw Face" (Bridge)
       |
       | Bonjour / Network.framework (LAN/USB, bidirektional)
       v
iOS App — "OpenClaw Display" (Face + Sensor-Hub)
       |
       ├── Display: Animiertes Gesicht (Lottie/Custom/Rive)
       ├── Mikrofon -> STT (SFSpeechRecognizer, on-device)
       ├── Lautsprecher -> TTS (AVSpeechSynthesizer, on-device)
       ├── Kamera -> Personen-Detektion (Vision.framework, on-device)
       └── Mikrofon -> Sound-Analyse (SoundAnalysis, on-device)
```

### Zwei Targets, ein Xcode-Projekt (via XcodeGen)

| Target             | Plattform | Bundle ID                           | Rolle                                  |
|--------------------|-----------|-------------------------------------|----------------------------------------|
| `OpenClawFace`     | macOS 14+ | net.eab-solutions.openclawface      | Bridge: Gateway <-> Display, Konfiguration |
| `OpenClawDisplay`  | iOS 17+   | net.eab-solutions.openclawdisplay   | Face-Display + Sensor-Hub (STT, TTS, Kamera, Sound) |

### Dependencies
- **Lottie** (SPM, v4.4+) — Vektorbasierte Animationen fuer Preset-Avatare
- **RiveRuntime** (SPM, v6.0+) — State-Machine-basierte Animationen fuer Rive-Avatare

### Shared Code
Alles in `Shared/` wird von beiden Targets kompiliert: Models, Networking, Renderer, Theme, Lottie-Animationen.

---

## Technologie-Stack

### Gemeinsam
- **Sprache:** Swift 6, strikt async/await, complete concurrency checking
- **UI-Framework:** SwiftUI
- **Design:** Zentrale Farbverwaltung in `Theme.swift`, Terminal-Aesthetik (schwarz, gruen, monospace)
- **Projekt-Generator:** XcodeGen (`project.yml`) — nach jeder Aenderung: `xcodegen generate`

### macOS App (Bridge)
- **Gateway:** WebSocket via `URLSessionWebSocketTask`, OpenClaw Protocol v3, Ed25519-Signing (CryptoKit)
- **Display:** Bonjour-Server via `Network.framework` mit Length-Prefixed Framing
- **Credentials:** Keychain (`KeychainService`)
- **Persistenz:** UserDefaults fuer Configs (kein CoreData)
- **Architektur:** MVVM, Services, `@StateObject` / `@ObservedObject`

### iOS App (Display + Sensor-Hub)
- **Kommunikation:** Bonjour-Client via `NWBrowser` + `NWConnection`, auto-discovery, bidirektional
- **Rendering:** Drei Systeme: Lottie (Presets) + SwiftUI Shapes (Custom) + Rive (State Machines)
- **STT:** `SFSpeechRecognizer` on-device, Realtime-Streaming, Session-Rotation
- **TTS:** `AVSpeechSynthesizer` mit Premium Voices, synchronisiert mit Emotion-State
- **Personen-Detektion:** `Vision.framework` (`VNDetectHumanRectanglesRequest`), Debounce-Logik
- **Sound-Analyse:** `SoundAnalysis.framework` (`SNClassifySoundRequest`), 15 relevante Geraeuschtypen
- **Fullscreen:** Landscape, System-Overlays hidden, subtile Sensor-Status-Dots

---

## Vier Avatar-Systeme

Das Projekt hat sich von Voll-Kopf-Avataren weg entwickelt: Roboter-, Katzen-,
Geister-, Eulen-, Toten- und Alien-Köpfe wirkten nie wirklich ausgereift. Statt
dessen liegt der Fokus jetzt auf **Augen mit Mimik**, **abstrakten Auren** und
optional **Rive State-Machines**. Voll-Köpfe sind komplett aus dem Build raus.

### 1. Lottie-Presets (Augen-Set)
6 vorgefertigte Lottie-JSON-Animationen in `Shared/Animations/`. Jede hat 240
Frames (8 Emotion-Segments à 30 Frames, 30fps). Generiert mit `tools/generate_lottie.py`.

| Kategorie | Avatare |
|-----------|---------|
| **Eyes** | Round, Cyber, Minimal Dots, Neon (Farbwechsel), Sharp, Soft |

Gesteuert durch: `LottieAnimationEngine` + `LottieFaceView` (UIKit/AppKit Wrapper mit `play(fromFrame:toFrame:)`)

### 2. Custom Avatar Editor (Baukasten)
Programmatischer SwiftUI-Renderer. Der User baut sein eigenes Gesicht aus Komponenten:

```
CustomAvatar
├── FaceOutline     (circle, roundedRect, oval, square, hexagon, none)
├── EyebrowLeft     (straight, arched, angry, worried, thick, none)
├── EyebrowRight    (unabhaengig oder gespiegelt)
├── EyeLeft         (round, oval, almond, droopy, wide, slit)
│   └── PupilLeft   (round, vertical, horizontal, star, dot, none)
├── EyeRight        (unabhaengig oder gespiegelt)
│   └── PupilRight  (unabhaengig oder gespiegelt)
├── Nose            (triangle, round, line, dot, none)
├── Mouth           (line, smile, open, small, wide, none)
└── Accessory       (ears, horns, antenna, halo, glasses, bow, none)
```

Jedes Element hat: **Shape-Variante + Farbe (10 Presets) + Groesse + Position**.

Gesteuert durch: `EmotionAnimator` (30fps, smooth Transitions, Blinzeln, Pupillen-Drift, Mund-Talk, Error-Shake, Atmen) + `CustomFaceView` + `FaceShapes.swift`

Quick-Presets: Default, Robot, Kawaii, Demon, Hacker

### 3. Abstract Avatars (Auras / Orbs / Wellenformen)
Sieben SwiftUI-Canvas-Renderer in `Shared/Renderer/AbstractFaceView.swift`. Komplett
prozedural, kein Asset-Preprocessing, 60fps via `TimelineView`. Jede Variante wird
durch eine gemeinsame `EmotionPalette` (Primary/Secondary/Glow/Speed) gefärbt, damit
die visuelle Sprache über alle Stile konsistent bleibt.

| Style | Look |
|-------|------|
| `pulseOrb` | Atmender Lichtkern mit additivem Halo-Glow |
| `neuralRing` | Konzentrische rotierende Arc-Segmente, Synapsen-Look |
| `plasmaCore` | Trigonometrisch animierte Plasma-Blobs |
| `particleHalo` | 36 orbitierende Partikel um einen ruhigen Kern |
| `waveform` | Sprach-Wellenform, Amplitude pro Emotion |
| `gradientFlow` | Pseudo-Conic Gradient mit Highlight |
| `ringBars` | Siri-ähnliche radiale Bars mit Sinus-Pulse |

Gesteuert durch: `AbstractAnimator` (palette-blending, reduceMotion-aware) + `AbstractFaceView` + `AbstractFaceRenderer`. Kein Lottie, kein Rive — pure `Canvas` + `GraphicsContext`.

### 4. Rive Avatare (State-Machine-basiert)
State-Machine-gesteuerte Animationen via [Rive](https://rive.app). `.riv` Dateien in `Shared/RiveAssets/`. Jede Datei muss eine State Machine `"emotions"` mit Inputs `emotionState` (Number 0-7) und `intensity` (Number 0-1) enthalten.

Gesteuert durch: `RiveAnimationEngine` (Wrapper um `RiveViewModel`) + `RiveFaceView` (SwiftUI View)

**Wichtig:** `RiveAnimationEngine` laedt lazy — kein Crash wenn `.riv` Dateien fehlen. Existenz wird vor dem Laden via `Bundle.main.url(forResource:withExtension:)` geprueft.

Aktuell verfuegbare Rive-Avatare: Robot Face (Platzhalter, `.riv` Datei muss noch im Rive Editor erstellt werden)

---

## Emotion-Protokoll

### 8 Emotion-States
| State        | Beschreibung                              |
|--------------|-------------------------------------------|
| `idle`       | Agent wartet, keine aktive Aufgabe        |
| `thinking`   | Agent verarbeitet, plant                  |
| `focused`    | Langer Task, intensive Verarbeitung       |
| `responding` | Agent formuliert Antwort                  |
| `error`      | Fehler im Agent-Prozess                   |
| `success`    | Aufgabe erfolgreich abgeschlossen         |
| `listening`  | Agent wartet auf Input                    |
| `sleeping`   | Agent im Standby / inaktiv                |

### Bonjour-Protokoll (bidirektional)

**macOS -> iOS:**
```json
{"cmd": "emotion", "state": "thinking", "intensity": 0.8, "context": "planning"}
{"cmd": "avatar", "avatar": {"avatarType": "eyes_neon"}}
{"cmd": "customAvatar", "customAvatar": {...}}
{"cmd": "riveAvatar", "riveAvatar": {"riveFile": "robot_face", "stateMachine": "emotions"}}
{"cmd": "abstractAvatar", "abstractAvatar": {"style": "pulse_orb", "blackBackground": true}}
{"cmd": "tts", "ttsText": "Hallo!", "context": "de-DE", "intensity": 0.5}
{"cmd": "ttsStop"}
{"cmd": "ping"}
```

**iOS -> macOS (Sensor-Daten):**
```json
{"cmd": "stt", "text": "Wie ist das Wetter?", "isFinal": true, "locale": "de-DE"}
{"cmd": "presence", "detected": true, "personCount": 1, "confidence": 0.92}
{"cmd": "sound", "soundType": "knock", "confidence": 0.85}
```

Framing: 4-Byte Length-Header (Big Endian) + JSON Payload ueber TCP.
iOS antwortet auf Commands mit: `{"ack": true}`

### Gateway-Event-Mapping (EmotionRouter)
- `chat` event + `state: "delta"` -> `responding`
- `chat` event + `state: "final"` -> `success`
- `agent.status` + `status: "thinking"` -> `thinking`
- Connection-State-Aenderungen -> `sleeping`, `error`, `success`

### EmotionAnimator Features
- Smooth Transitions (0.5s ease-out-cubic zwischen Emotionen)
- Automatisches Blinzeln (zufaellig alle 2.5-5 Sek)
- Pupillen-Drift (Idle: Mikrobewegung, Thinking: aktiv herumschauen, Listening: leicht)
- Atmen (subtile Scale-Oszillation des ganzen Gesichts)
- Mund-Animation (oeffnet/schliesst bei Responding)
- Error-Shake (ganzes Gesicht vibriert)
- Mood-Tracking (gewichteter Durchschnitt der letzten 50 Emotionen)

---

## Projektstruktur

```
ocFaceMe/
├── CLAUDE.md
├── project.yml                              <- XcodeGen
├── tools/
│   └── generate_lottie.py                   <- Generiert alle 13 Lottie-JSONs
├── Shared/                                  <- Beide Targets
│   ├── Models/
│   │   ├── AvatarConfig.swift               <- AvatarType enum (13 Lottie-Presets), Emotion-Segment-Mapping
│   │   ├── CustomAvatarConfig.swift         <- Komplettes Custom-Avatar-Modell mit allen Komponenten + Farben
│   │   ├── RiveAvatarConfig.swift           <- Rive Avatar-Typen, State-Machine-Mapping, Config
│   │   ├── SensorCommand.swift             <- STT/Presence/Sound Commands (iOS->macOS) + TTS Extension
│   │   └── EmotionState.swift               <- 8 States + EmotionCommand/Ack (Bonjour-Protokoll)
│   ├── Networking/
│   │   ├── BonjourConstants.swift           <- Service-Type + EmotionFramerProtocol (Length-Prefixed)
│   │   ├── ConnectionState.swift
│   │   ├── DeviceIdentity.swift             <- Ed25519 Keypair, Keychain-Persistenz
│   │   ├── GatewayConnectionConfig.swift
│   │   ├── GatewayService.swift             <- WebSocket zu OpenClaw, Auto-Connect, Reconnect (Exp. Backoff)
│   │   ├── KeychainService.swift
│   │   └── OpenClawAPI.swift                <- OCResponse, AnyCodable, GatewayError
│   ├── Renderer/
│   │   ├── LottieAnimationEngine.swift      <- Laedt Lottie-JSON, steuert Segments per Emotion
│   │   ├── LottieFaceView.swift             <- UIKit/AppKit Wrapper (UIViewRepresentable/NSViewRepresentable)
│   │   ├── EmotionAnimator.swift            <- 30fps Pose-Interpolation, Blinzeln, Pupillen, Mood
│   │   ├── CustomFaceView.swift             <- SwiftUI View, composited alle Shapes mit EmotionAnimator
│   │   ├── FaceShapes.swift                 <- Bezier-Shapes: Eye, Eyebrow, Pupil, Mouth, Nose, Face, Accessory
│   │   ├── RiveAnimationEngine.swift        <- Wrapper um RiveViewModel, steuert State Machine Inputs
│   │   └── RiveFaceView.swift               <- SwiftUI View fuer Rive-Avatare
│   ├── Animations/                          <- Lottie JSON Dateien (als Resources in beide Targets)
│   │   ├── eyes_round.json                  <- 6 Augen-Varianten
│   │   ├── eyes_cyber.json
│   │   ├── eyes_minimal.json
│   │   ├── eyes_neon.json                   <- Farbwechsel pro Emotion
│   │   ├── eyes_angry.json                  <- Rot, schraeg
│   │   ├── eyes_cute.json                   <- Kawaii mit Iris
│   │   ├── face_robot.json                  <- 6 Gesichter
│   │   ├── face_cat.json
│   │   ├── face_ghost.json
│   │   ├── face_owl.json
│   │   ├── face_skull.json
│   │   ├── face_alien.json
│   │   └── sphere_rgb.json                  <- Siri-aehnliche RGB-Kugel
│   ├── RiveAssets/                          <- Rive .riv Dateien (als Resources in beide Targets)
│   │   └── (robot_face.riv)                 <- Platzhalter, muss in Rive Editor erstellt werden
│   └── Theme/
│       └── Theme.swift                      <- Terminal-Aesthetik, alle Farben/Fonts/Spacing
├── macOS/                                   <- OpenClawFace Target
│   ├── App/
│   │   ├── OpenClawFaceApp.swift            <- @main, DI, Auto-Connect, Bonjour-Start
│   │   └── ContentView.swift                <- 5 Tabs: BRIDGE, AVATAR, SENSOR, SKILL, CONFIG
│   ├── Services/
│   │   ├── BonjourServer.swift              <- Advertised _openclawface._tcp, sendet Commands
│   │   ├── EmotionRouter.swift              <- Gateway-Events -> EmotionState -> BonjourServer
│   │   ├── EmotionSkillService.swift        <- EMOTION.md auf Agenten-Workspace pushen/entfernen
│   │   └── SensorRouter.swift              <- Empfaengt iOS Sensor-Daten (STT, Presence, Sound), TTS
│   ├── ViewModels/
│   │   └── SettingsViewModel.swift          <- Gateway-Config, Reachability-Test
│   ├── Views/
│   │   ├── AvatarEditorView.swift           <- Drei Modi: [PRESETS] + [CUSTOM] + [RIVE], Push to Display
│   │   ├── CustomEditorView.swift           <- Full Custom Editor: 5 Sektionen (Eyes/Brows/Mouth/Face/Extras)
│   │   ├── DashboardView.swift              <- Gateway+Display+Bonjour Status, Manual Emotion, Log
│   │   ├── SensorView.swift                 <- Sensor-Dashboard: STT-Log, TTS, Presence, Sound, Toggles
│   │   ├── SettingsView.swift               <- Host/Port/Token/SSL, Test, Connect/Disconnect
│   │   └── SkillView.swift                  <- Agent-Liste, EMOTION.md Install/Remove
│   └── Resources/
│       └── OpenClawFace.entitlements        <- network.client + network.server
└── iOS/                                     <- OpenClawDisplay Target
    ├── App/
    │   └── OpenClawDisplayApp.swift         <- @main, BonjourClient, empfaengt emotion/avatar Commands
    ├── Services/
    │   ├── BonjourClient.swift              <- NWBrowser auto-discovery, empfaengt + ACKt Commands, sendet Sensor-Daten
    │   ├── TTSService.swift                 <- AVSpeechSynthesizer, Premium Voices, on-device TTS
    │   ├── STTService.swift                 <- SFSpeechRecognizer, on-device STT, Session-Rotation
    │   ├── PresenceService.swift            <- Vision.framework, Personen-Detektion via Front-Kamera
    │   └── SoundAnalysisService.swift       <- SoundAnalysis.framework, Geraeusch-Klassifikation
    └── Views/
        └── FaceView.swift                   <- Fullscreen, Lottie/Custom/Rive, Sensor-Status-Dots
```

---

## Entwicklungsrichtlinien

- Alle Farben und Design-Attribute zentral in `Theme.swift`
- Nach jeder Datei-Aenderung: `rm -rf OpenClawFace.xcodeproj && xcodegen generate`
- Keine neuen Config-Speicherorte ausser Keychain fuer Secrets und vorhandene Config-Mechanismen
- Networking bleibt async/await-only
- Sichtbare Fehlerzustände im UI statt stiller Fails

---

## Bonjour-Härtung (2026-04-11)

Die ursprüngliche Bonjour-Implementierung war optimistisch und hat unter realen
LAN-Bedingungen häufig die Verbindung verloren. Die aktuelle Version (`BonjourServer`
auf macOS, `BonjourClient` auf iOS) ist deutlich robuster:

- **Sichere Frame-Parser** in `BonjourConstants.swift`: Hard-Cap auf 1 MB pro Frame,
  defensive Bounds-Checks, kein Endlos-Spinning bei verstümmelten Headern.
- **NWPathMonitor** auf beiden Seiten: Wenn der Netzwerk-Pfad zurück kommt
  (Wi-Fi → USB Wechsel, Sleep/Wake), wird Listener bzw. Browser automatisch neu
  gestartet.
- **NSWorkspace `didWakeNotification`** auf macOS: Listener wird nach Sleep neu
  aufgesetzt, da NWListener sonst tot bleiben kann.
- **scenePhase Observer** auf iOS (`OpenClawDisplayApp`): Bei Rückkehr in den
  Vordergrund wird der Browser über `client.restart()` zurückgesetzt.
- **Heartbeat-Ping** alle 5s vom macOS-Server, damit halb-offene TCP-Sockets
  sofort als Fehler hochkommen statt sich Updates aufzustauen.
- **Send-Guard**: Jeder Send prüft `connection.state == .ready`, sonst wird das
  Kommando verworfen statt in den `.waiting` State zu fallen.
- **Connect-Timeout** auf iOS: Wenn ein Endpoint in 6s nicht `.ready` wird, wird
  er fallen gelassen und neu gebrowst — wichtig nach Wi-Fi/USB-Wechseln.
- **Exponentielles Backoff** ohne Rekursion: dedizierter `reconnectTask`, gecappt
  auf 8s, danach erneutes Browsen.
- **Live-Diagnose** über `LinkDiagnostic` (Shared/Networking): Beide Seiten halten
  einen Rolling-Log von 60 Einträgen, Dashboard zeigt die letzten 5.
- **`[PING DISPLAY]`** Button im Dashboard: Manueller Test, ob das Display
  tatsächlich antwortet.

## Aktueller Audit-Stand (2026-04-05)

### Verifiziert
- Beide Targets bauen erfolgreich mit `xcodegen generate` + `xcodebuild`:
  - `OpenClawDisplay` (iOS 17+)
  - `OpenClawFace` (macOS 14+)
- iOS-Audio-Lifecycle ist jetzt mit Interruption- und Route-Change-Recovery besser gehärtet; STT/TTS bleiben aber weiter sensitive Wechselstellen.
- Bonjour-Discovery und Reconnect-Verhalten sind grundsätzlich da, aber Sleep/Wake- und Netzwerkwechsel-Races bleiben ein echtes Risiko.

### Status der dokumentierten Arbeit
- P1–P5 sind noch nicht als abgeschlossen zu behandeln; sie bleiben als umzusetzende Produktarbeit im Issue-Backlog.
- Vorhandene Teilimplementierungen sind brauchbar, aber noch nicht ausreichend, um die offenen Aufgaben als erledigt zu markieren.
- Audit-Fokus bleibt auf Bonjour-Race-Conditions, Audio-Handoffs, Accessibility und produktionsreifer Avatar-Persistenz.

### Zusätzliche Audit-Issues
- `#38` Reconnect and audio interruption hardening
- `#40` Critical-path test coverage for Gateway and sensor relay
- `#42` Project Audit Report
- `#54` Bonjour endpoint deduping and reconnect race audit
- `#55` Motion accessibility and reduced-motion pass
- `#56` P1 Gateway integration for sensor relay and audio handoff
- `#57` P2 EmotionAnimator personality, gaze, and micro-expression pass
- `#58` P3 First production Rive avatar and state-machine expansion
- `#59` P4 Lottie emotion separation and segment playback audit
- `#60` P5 Product readiness: onboarding, avatar storage, export/import, and E2E gateway test
- `#61` iOS orientation and accessibility configuration warning

### Architektur-Erkenntnisse
- Der aktuelle Code ist klar in `Shared/`, `macOS/` und `iOS/` getrennt; das Pattern ist brauchbar und sollte beibehalten werden.
- Die kritischsten technischen Risiken liegen weiter in Netzwerk-Resilienz, Audio-Handoffs, Accessibility und fehlender Testabdeckung.
- Rive ist weiterhin content-getrieben; echte Produktions-Avatare fehlen.

### Hinweise fuer die naechsten Iterationen
- Vor jeder grösseren Aenderung Build + Projekt-Generierung erneut verifizieren.
- Neue Workitems nur mit explizitem Issue und Priority-Label anlegen.
- Keine auskommentierten TODOs; alles als Issue oder Code umgesetzt.

## Aktuelle Prioritaet

README-Testsatz: Build-Verifikations-Anleitung in README.md ist aktueller Fokus.

## Aktueller Stand / Notizen (2026-04-05)

- iOS-Audio wurde auf einen zentralen `AudioSessionCoordinator` umgestellt, damit STT und TTS sich sauber gegenseitig ausschliessen.
- `EmotionAnimator` traegt jetzt ein einfaches Personality-Modell plus Thinking-Asymmetrie, Focused-Pupil-Damping und Idle-Micro-Expressions.
- `LottieFaceView` vermeidet redundante Segment-Starts bei unveraenderter Emotion.
- Sensor-Routing protokolliert Gateway-Relay-Fehler nun passend zum jeweiligen Sensortyp statt alles als Presence zu verbuchen.
- iOS `OpenClawDisplay` baut wieder erfolgreich mit `xcodebuild ... CODE_SIGNING_ALLOWED=NO`.
- Dokumentierte offene Arbeiten sind als GitHub-Issues erfasst (`#32` bis `#37`) und warten auf Umsetzung/Abschluss.
- Offene Produktarbeit bleibt: Gateway-Routing fuer STT/Presence/TTS, echte Rive-Avatare, Lottie-Emotionen differenzieren, Onboarding, Export/Import, E2E-Test.
- Keine hardcodierten Farben, Abstaende oder Schriftgroessen ausserhalb von Theme
- Keine Emojis oder dekorativen Icons in der UI
- Keine Chevron-Pfeile in Navigations- oder Auswahlmenues
- Credentials ausschliesslich via Keychain
- WebSocket- und Bonjour-Kommunikation vollstaendig async
- Fehlerbehandlung explizit und sichtbar im UI
- Terminal-Aesthetik: schwarzer Hintergrund, gruener Monospace-Text, eckige Klammern `[BUTTON]`
- XcodeGen: Nach Datei-Aenderungen immer `rm -rf OpenClawFace.xcodeproj && xcodegen generate`
- Lottie-Animationen: Mit `python3 tools/generate_lottie.py` regenerieren

---

## Entwicklungsphasen

### Phase 1 — Grundstruktur + Simulator ✅
- Xcode-Projekt mit XcodeGen (macOS + iOS Target)
- Theme, Networking-Layer (Gateway Protocol v3, Ed25519)
- Bonjour-Kommunikation (Server + Client, Length-Prefixed Framing)
- macOS: Dashboard, Settings, 4-Tab-Navigation
- iOS: Fullscreen FaceView mit Verbindungsstatus
- Beide Targets bauen erfolgreich

### Phase 2 — Live-Integration ✅
- Auto-Connect zum lokalen Gateway bei App-Start
- Reconnect mit Exponential Backoff (1s...30s)
- EmotionRouter: Gateway-Events -> Emotion -> BonjourServer -> iOS
- Emotion-Skill-Management: EMOTION.md pro Agent installieren/entfernen
- [SKILL] Tab mit Agent-Liste

### Phase 3 — Lottie Avatar-System ✅
- 13 Lottie-Presets (6 Augen, 6 Gesichter, 1 RGB-Sphere)
- Python-Generator (`tools/generate_lottie.py`) fuer alle Animationen
- LottieAnimationEngine + LottieFaceView (UIKit/AppKit Wrapper)
- Jede Animation: 240 Frames, 8 Emotion-Segments
- [AVATAR] Tab mit Preset-Auswahl und Live-Preview
- Farbe pro Emotion (Neon Eyes, RGB Sphere)

### Phase 4 — Custom Avatar Editor ✅
- Komponenten-basierter SwiftUI-Renderer (Bezier-Shapes)
- 7 Komponenten: FaceOutline, EyeL/R, EyebrowL/R, PupilL/R, Nose, Mouth, Accessory
- Jede Komponente: Shape-Variante + Farbe + Groesse
- EmotionAnimator: 30fps Pose-Interpolation, Blinzeln, Pupillen-Drift, Mund-Talk, Shake, Atmen, Mood
- CustomEditorView: 5 Sektionen (Eyes, Brows, Mouth, Face, Extras)
- Quick-Presets: Default, Robot, Kawaii, Demon, Hacker
- [AVATAR] Tab: [PRESETS] und [CUSTOM] Modi nebeneinander

### Phase 5 — Rive Avatar-System ✅
- `rive-ios` (RiveRuntime) als SPM Dependency integriert
- `RiveAnimationEngine`: Wrapper um `RiveViewModel`, steuert State Machine Inputs (`emotionState`, `intensity`)
- `RiveFaceView`: SwiftUI View fuer Rive-Avatare (iOS + macOS)
- `RiveAvatarConfig`: Codable Config fuer Bonjour-Protokoll (`cmd:"riveAvatar"`)
- `DisplayMode.rive` als dritter Modus neben `.lottie` und `.custom`
- [AVATAR] Tab: Dritter Modus `[RIVE]` mit Live-Preview und Emotion-Test
- Bestehendes Lottie- und Custom-System bleibt parallel erhalten
- `.riv` Dateien werden in `Shared/RiveAssets/` abgelegt

### Phase 6 — iOS Sensor-Hub (STT, TTS, Kamera, Sound) ✅
- Bonjour-Protokoll bidirektional: iOS sendet `SensorCommand` an macOS
- `TTSService`: `AVSpeechSynthesizer`, Premium Voices, synchronisiert Emotion-State mit Sprechen
- `STTService`: `SFSpeechRecognizer` on-device, Realtime-Streaming, automatische Session-Rotation
- `PresenceService`: `VNDetectHumanRectanglesRequest`, Debounce-Logik, Front-Kamera
- `SoundAnalysisService`: `SNClassifySoundRequest`, 15 relevante Geraeuschtypen
- `SensorRouter` (macOS): Empfaengt Sensor-Daten, steuert EmotionRouter (Raum betreten/verlassen)
- `SensorView` (macOS): [SENSOR] Tab mit Live-Status, TTS-Input, STT-Log, Sensor-Toggles
- macOS 5-Tab-Navigation: BRIDGE, AVATAR, SENSOR, SKILL, CONFIG
- Alle Sensor-Features komplett on-device, keine externen APIs noetig
- Info.plist: Kamera, Mikrofon, Speech Recognition Permissions

---

## Offene Aufgaben (naechste Session)

### Prioritaet 1 — Gateway-Integration fuer Sensoren
- [ ] STT-Texte an Gateway/Agent weiterleiten (neuer Endpoint oder Chat-Kanal)
- [ ] Presence-Events an Gateway melden (Agent wacht auf bei Person, schlaeft bei leerem Raum)
- [ ] TTS automatisch bei Agent-Antworten ausloesen (responding -> speak)
- [ ] Audio-Session-Management: STT und TTS wechseln (nicht gleichzeitig)

### Prioritaet 2 — Emotion Engine verbessern
- [ ] EmotionAnimator: Personality-System (viele Errors = nervoeser Idle, viele Success = selbstbewusster)
- [ ] Smooth Pupillen-Tracking: Pupillen folgen "Aufmerksamkeit" (zentriert bei Focused, wandernd bei Thinking)
- [ ] Augenbrauen-Asymmetrie bei Thinking (eine hoch, eine runter)
- [ ] Micro-Expressions: zufaellige kleine Zuckungen im Idle

### Prioritaet 3 — Rive Avatare erstellen
- [ ] Erstes Rive-Avatar (`robot_face.riv`) im Rive Editor erstellen mit 8 Emotion-States
- [ ] Weitere Rive-Avatare designen und `RiveAvatarType` erweitern
- [ ] Optional: `triggerBlink` Trigger in Rive State Machine einbauen

### Prioritaet 4 — Lottie-Emotionen fixen
- [ ] Lottie-Presets: Emotionen sehen noch zu aehnlich aus
- [ ] LottieFaceView: Pruefen ob `play(fromFrame:toFrame:)` korrekt bei jedem Emotion-Wechsel aufgerufen wird
- [ ] Eventuell: Lottie durch Custom-Renderer komplett ersetzen (bessere Kontrolle)

### Prioritaet 5 — Produktreife
- [ ] Onboarding-Flow (Ersteinrichtung: Gateway-URL, erster Avatar)
- [ ] Custom-Avatare speichern/laden (mehrere Slots)
- [ ] Export/Import von Custom-Avataren
- [ ] End-to-End Test mit echtem OpenClaw Gateway

---

## Verwandte Projekte

- **OpenClaw CommandCenter** (ocSHELL) — iOS-App als primaeres OpenClaw Control Interface. Gateway-Networking-Code (`GatewayService`, `DeviceIdentity`, `KeychainService`) wurde von dort adaptiert.
- **OpenClaw** — Open-Source AI Agent Framework, lokal auf Mac Mini M4
