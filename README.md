# OpenClaw Face

**Give your local AI agent a face.** OpenClaw Face is a companion app system for [OpenClaw](https://github.com/Dewinator/OpenClaw) that turns an iPhone or iPad into a real-time animated face display for your self-hosted AI agent.

A macOS Bridge app connects to the local OpenClaw Gateway via WebSocket and relays emotion events over Bonjour to a connected iOS device. The iOS app renders animated avatars that reflect the agent's emotional state in real time -- and doubles as a sensor hub, sending speech, presence, and sound data back to the agent.

## Architecture

```
OpenClaw Gateway (localhost:18789)
       |
       | WebSocket (Protocol v3, Ed25519)
       v
macOS App -- "OpenClaw Face" (Bridge)
       |
       | Bonjour / Network.framework (LAN/USB, bidirectional)
       v
iOS App -- "OpenClaw Display" (Face + Sensor Hub)
       |
       +-- Animated Face (Lottie / Custom / Rive)
       +-- Microphone -> STT (on-device)
       +-- Speaker -> TTS (on-device)
       +-- Camera -> Presence Detection (on-device)
       +-- Microphone -> Sound Classification (on-device)
```

## Features

### Three Avatar Rendering Systems

| System | Description |
|--------|-------------|
| **Lottie Presets** | 13 pre-built vector animations (6 eye styles, 6 faces, 1 RGB sphere). 240 frames each with 8 emotion segments. Generated via `tools/generate_lottie.py`. |
| **Custom Avatar Editor** | Build-your-own face from modular components (eyes, eyebrows, pupils, nose, mouth, accessories). Each element has shape variants, colors, and sizing. Includes quick presets (Robot, Kawaii, Demon, Hacker). |
| **Rive Avatars** | State-machine-driven animations via [Rive](https://rive.app). Drop `.riv` files into `Shared/RiveAssets/` with an `"emotions"` state machine exposing `emotionState` (0-7) and `intensity` (0-1) inputs. |

### Eight Emotion States

`idle` | `thinking` | `focused` | `responding` | `error` | `success` | `listening` | `sleeping`

Emotions are mapped from Gateway events by `EmotionRouter` and transmitted to the iOS display in real time.

### Emotion Animator

The custom avatar system features a 30fps emotion engine with:
- Smooth transitions (0.5s ease-out-cubic)
- Automatic blinking (random interval 2.5-5s)
- Pupil drift (micro-movement in idle, active scanning in thinking)
- Breathing animation (subtle scale oscillation)
- Mouth animation (opens/closes during responding)
- Error shake (full face vibration)
- Mood tracking (weighted average of last 50 emotions)

### iOS Sensor Hub

All processing happens on-device -- no external APIs required.

| Sensor | Framework | Capability |
|--------|-----------|------------|
| **Speech-to-Text** | `SFSpeechRecognizer` | Real-time streaming, session rotation |
| **Text-to-Speech** | `AVSpeechSynthesizer` | Premium voices, emotion-synchronized |
| **Presence Detection** | `Vision.framework` | Human rectangle detection, debounce logic |
| **Sound Classification** | `SoundAnalysis.framework` | 15 sound types (knock, speech, music, etc.) |

### Bonjour Protocol

Bidirectional communication over TCP with 4-byte length-prefixed JSON framing.

**macOS to iOS:** emotion commands, avatar config, TTS text, ping
**iOS to macOS:** STT transcripts, presence events, sound classifications

## Requirements

| Target | Platform | Bundle ID |
|--------|----------|-----------|
| `OpenClawFace` | macOS 14+ | `net.eab-solutions.openclawface` |
| `OpenClawDisplay` | iOS 17+ | `net.eab-solutions.openclawdisplay` |

### Dependencies

- [Lottie](https://github.com/airbnb/lottie-ios) (SPM, v4.4+) -- Vector animations for preset avatars
- [RiveRuntime](https://github.com/rive-app/rive-ios) (SPM, v6.0+) -- State-machine animations for Rive avatars

### Tech Stack

- Swift 6 with strict concurrency checking
- SwiftUI
- XcodeGen (`project.yml`)
- Ed25519 signing (CryptoKit) for Gateway authentication
- Network.framework for Bonjour
- Keychain for credential storage

## Getting Started

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open OpenClawFace.xcodeproj

# Regenerate Lottie animations (optional)
python3 tools/generate_lottie.py
```

Build and run `OpenClawFace` (macOS) and `OpenClawDisplay` (iOS) targets. The iOS device discovers the macOS bridge automatically via Bonjour.

## Project Structure

```
ocMIME/
+-- project.yml                  XcodeGen project definition
+-- tools/generate_lottie.py     Generates all 13 Lottie JSON animations
+-- Shared/                      Code shared by both targets
|   +-- Models/                  AvatarConfig, CustomAvatarConfig, RiveAvatarConfig,
|   |                            SensorCommand, EmotionState
|   +-- Networking/              Bonjour, Gateway WebSocket, Keychain, DeviceIdentity
|   +-- Renderer/                Lottie/Custom/Rive engines and SwiftUI views
|   +-- Animations/              13 Lottie JSON files
|   +-- RiveAssets/              Rive .riv files
|   +-- Theme/                   Terminal aesthetic (black, green, monospace)
+-- macOS/                       Bridge app (Gateway <-> Display)
|   +-- Services/                BonjourServer, EmotionRouter, SensorRouter
|   +-- Views/                   5 tabs: Bridge, Avatar, Sensor, Skill, Config
+-- iOS/                         Display + Sensor Hub
    +-- Services/                BonjourClient, TTSService, STTService,
    |                            PresenceService, SoundAnalysisService
    +-- Views/                   Fullscreen face with sensor status dots
```

## Design Guidelines

- Terminal aesthetic: black background, green monospace text, bracket-style buttons `[ACTION]`
- All colors and design tokens centralized in `Theme.swift`
- No emojis, decorative icons, or chevron arrows in the UI
- Credentials stored exclusively via Keychain
- All networking fully async

## Related Projects

- [OpenClaw](https://github.com/Dewinator/OpenClaw) -- Open-source AI agent framework, runs locally on Mac Mini M4
- **OpenClaw CommandCenter** (ocSHELL) -- iOS control interface for OpenClaw. Gateway networking code was adapted from this project.

## License

See [LICENSE](LICENSE) for details.
