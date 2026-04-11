# OpenClaw Face

**Gib deinem lokalen KI-Agenten ein Gesicht.**

OpenClaw Face verbindet sich mit deinem selbst-gehosteten [OpenClaw](https://github.com/openclaw)-Agenten und zeigt dessen emotionalen Zustand als animiertes Gesicht auf einem iPhone oder iPad — in Echtzeit. Zusaetzlich nutzt die iOS-App Kamera, Mikrofon und Lautsprecher als Sensor-Hub, damit der Agent seine Umgebung wahrnehmen und mit ihr interagieren kann.

```
OpenClaw Gateway (Mac Mini M4)
       |
       | WebSocket (Protocol v3, Ed25519)
       v
macOS Bridge — Konfiguration, Routing, Dashboard
       |
       | Bonjour (bidirektional, LAN/USB)
       v
iOS Display — Animiertes Gesicht + Sensor-Hub
       |
       +-- Gesicht: Lottie / Custom / Rive
       +-- STT:     Sprache zu Text (on-device)
       +-- TTS:     Text zu Sprache (on-device)
       +-- Kamera:  Personen-Detektion (on-device)
       +-- Sound:   Geraeusch-Klassifikation (on-device)
```

---

## Warum?

Du betreibst OpenClaw lokal auf einem Mac Mini. Der Agent kann denken, planen, ausfuehren — aber er hat kein Gesicht, keine Stimme, keine Augen. OpenClaw Face aendert das:

- **Sehen:** Erkennt, wenn jemand den Raum betritt — der Agent wacht auf
- **Hoeren:** Wandelt Sprache in Text um, direkt auf dem iPhone — kein Whisper-API noetig
- **Sprechen:** Liest Agent-Antworten vor, synchronisiert mit Gesichts-Animation
- **Fuehlen:** 8 Emotionen spiegeln den Zustand des Agenten in Echtzeit wider

Alles laeuft **komplett on-device**. Keine Cloud, keine externen APIs, keine Daten verlassen dein Netzwerk.

---

## Features

### Zwei Avatar-Systeme

| System | Beschreibung | Anpassbar? |
|--------|-------------|------------|
| **Abstract** | 7 SwiftUI-Canvas Auren, Orbs, Wellenformen — pure GPU | Style-Auswahl |
| **Custom Face** | SwiftUI-Bezier Face mit EmotionAnimator-Mimik, Eyes-Only Quick-Presets | Komplett |

> Voll-Kopf-Lottie-Avatare (Roboter, Katze, Geist, ...) und Rive sind komplett
> entfernt — die Abhaengigkeiten zu `lottie-ios` und `rive-ios` sind raus.
> Die App besteht jetzt nur noch aus zwei kohärenten Rendering-Systemen, beide
> in purem SwiftUI.

### 8 Emotionen

| Emotion | Wann | Gesicht |
|---------|------|---------|
| `idle` | Agent wartet | Ruhig, subtiles Atmen |
| `thinking` | Agent plant | Blick wandert, Brauen asymmetrisch |
| `focused` | Langer Task | Zusammengekniffene Augen |
| `responding` | Antwort wird generiert | Mund bewegt sich |
| `error` | Fehler aufgetreten | Zittern, rote Toene |
| `success` | Aufgabe erledigt | Augen schliessen gluecklich |
| `listening` | Wartet auf Input | Grosse Augen, aufmerksam |
| `sleeping` | Standby | Augen zu, langsames Atmen |

### Sensor-Hub (iOS)

| Sensor | Framework | Funktion |
|--------|-----------|----------|
| **Speech-to-Text** | `SFSpeechRecognizer` | Realtime-Streaming, Session-Rotation, on-device |
| **Text-to-Speech** | `AVSpeechSynthesizer` | Premium Voices, Emotion-Synchronisation |
| **Personen-Detektion** | `Vision.framework` | Front-Kamera, Debounce, Person-Enter/Leave Events |
| **Sound-Analyse** | `SoundAnalysis.framework` | 15 Geraeuschtypen (knock, doorbell, speech...) |

### macOS Bridge (5 Tabs)

| Tab | Funktion |
|-----|----------|
| **BRIDGE** | Gateway + Display Status, manuelle Emotion-Steuerung, Log |
| **AVATAR** | Preset / Custom / Rive Auswahl, Live-Preview, Push to Display |
| **SENSOR** | STT-Log, TTS-Eingabe, Sensor-Toggles, Live-Status |
| **SKILL** | Agent-Liste, EMOTION.md installieren/entfernen |
| **CONFIG** | Gateway Host/Port/Token, Verbindungstest |

---

## Voraussetzungen

| Komponente | Anforderung |
|------------|------------|
| Mac | macOS 14+ mit Xcode 16+ |
| iPhone/iPad | iOS 17+ |
| OpenClaw | Lokal laufende Instanz (Gateway auf `localhost:18789`) |
| Netzwerk | Mac und iOS-Geraet im selben LAN (oder via USB) |

---

## Installation

### 1. Repository klonen

```bash
git clone https://github.com/Dewinator/ocMime.git
cd ocMime
```

### 2. Xcode-Projekt generieren

```bash
brew install xcodegen   # falls noch nicht installiert
xcodegen generate
```

### 3. In Xcode oeffnen

```bash
open OpenClawFace.xcodeproj
```

### 4. Targets bauen

| Target | Schema | Geraet |
|--------|--------|--------|
| `OpenClawFace` | macOS | Dein Mac |
| `OpenClawDisplay` | iOS | Dein iPhone/iPad |

### 5. Verbinden

1. macOS-App starten — verbindet sich automatisch zum Gateway
2. iOS-App starten — findet die macOS-App automatisch via Bonjour
3. Im AVATAR-Tab ein Gesicht waehlen und [PUSH TO DISPLAY] klicken

---

## Entwicklung

### Projektstruktur

```
ocMime/
+-- project.yml              XcodeGen-Konfiguration
+-- Shared/                   Code fuer beide Targets
|   +-- Models/               Datenmodelle (Emotion, Avatar, Sensor)
|   +-- Networking/           Bonjour, Gateway, Keychain
|   +-- Renderer/             Lottie, Custom, Rive Engines + Views
|   +-- Animations/           13 Lottie-JSON-Dateien
|   +-- RiveAssets/           .riv Dateien
|   +-- Theme/                Farben, Fonts, Spacing
+-- macOS/                    Bridge-App
|   +-- App/                  Entry Point, ContentView (5 Tabs)
|   +-- Services/             BonjourServer, EmotionRouter, SensorRouter
|   +-- Views/                Dashboard, Avatar, Sensor, Skill, Settings
+-- iOS/                      Display-App
|   +-- App/                  Entry Point, Sensor-Wiring
|   +-- Services/             BonjourClient, TTS, STT, Presence, Sound
|   +-- Views/                FaceView (Fullscreen)
+-- tools/
    +-- generate_lottie.py    Generiert alle 13 Lottie-Animationen
```

### Build-Verifikation (End-to-End)

Um den gesamten Build-Workflow zu pruefen: `xcodegen generate && xcodebuild -scheme OpenClawFace -destination 'platform=macOS' build && xcodebuild -scheme OpenClawDisplay -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` — beide Targets muessen fehlerfrei durchlaufen.

### XcodeGen

Nach jeder Datei-Aenderung (neue Dateien, Umbenennung):

```bash
rm -rf OpenClawFace.xcodeproj && xcodegen generate
```

### Lottie-Animationen regenerieren

```bash
python3 tools/generate_lottie.py
```

### Eigene Rive-Avatare erstellen

1. Avatar im [Rive Editor](https://rive.app) designen
2. State Machine `"emotions"` anlegen mit Inputs:
   - `emotionState` (Number, 0-7)
   - `intensity` (Number, 0.0-1.0)
   - Optional: `triggerBlink` (Trigger)
3. Als `.riv` exportieren und in `Shared/RiveAssets/` ablegen
4. Neuen Case zu `RiveAvatarType` in `Shared/Models/RiveAvatarConfig.swift` hinzufuegen

### Design-Richtlinien

- Terminal-Aesthetik: Schwarzer Hintergrund, gruener Monospace-Text
- Buttons in eckigen Klammern: `[PUSH TO DISPLAY]`
- Keine Emojis, keine dekorativen Icons
- Keine Chevron-Pfeile
- Alle Farben zentral in `Theme.swift`
- Credentials ausschliesslich via Keychain

---

## Bonjour-Protokoll

Bidirektionale Kommunikation via TCP mit 4-Byte Length-Prefixed JSON Framing.

### macOS -> iOS

```json
{"cmd": "emotion", "state": "thinking", "intensity": 0.8, "context": "planning"}
{"cmd": "customAvatar", "customAvatar": {...}}
{"cmd": "abstractAvatar", "abstractAvatar": {"style": "pulse_orb"}}
{"cmd": "tts", "ttsText": "Hallo!", "context": "de-DE", "intensity": 0.5}
{"cmd": "ttsStop"}
{"cmd": "ping"}
```

### iOS -> macOS

```json
{"cmd": "stt", "text": "Wie ist das Wetter?", "isFinal": true, "locale": "de-DE"}
{"cmd": "presence", "detected": true, "personCount": 1, "confidence": 0.92}
{"cmd": "sound", "soundType": "knock", "confidence": 0.85}
```

---

## Plugin-Architektur

OpenClaw Face interagiert mit dem Gateway ueber das OpenClaw Protocol v3. Die Emotion-Logik ist vollstaendig in der macOS Bridge gekapselt:

- **EmotionRouter** mappt Gateway-Events auf Emotionen
- **SensorRouter** verarbeitet iOS-Sensordaten und leitet sie an den Gateway weiter
- **EMOTION.md** kann pro Agent installiert werden (SKILL-Tab), damit der Agent seine Emotionen selbst steuern kann

Bei einem OpenClaw-Update aendert sich nur die Gateway-Kommunikation. Die Emotion-Darstellung, Sensor-Verarbeitung und Avatar-Systeme bleiben unabhaengig.

---

## Lizenz

MIT

---

## Verwandte Projekte

- [OpenClaw](https://github.com/openclaw) — Open-Source AI Agent Framework
- [OpenClaw CommandCenter (ocSHELL)](https://github.com/Dewinator/ocSHELL) — iOS Control Interface fuer OpenClaw
