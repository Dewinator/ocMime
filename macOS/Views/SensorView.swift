import SwiftUI

struct SensorView: View {

    @ObservedObject var sensorRouter: SensorRouter
    @ObservedObject var bonjourServer: BonjourServer
    @State private var ttsInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("~/openclaw/face/sensors")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                    // ── Live Status ──
                    sensorStatusSection

                    Divider().background(Theme.borderTertiary)

                    // ── TTS ──
                    ttsSection

                    Divider().background(Theme.borderTertiary)

                    // ── Sensor Toggles ──
                    sensorTogglesSection

                    Divider().background(Theme.borderTertiary)

                    // ── STT Log ──
                    sttLogSection

                    Divider().background(Theme.borderTertiary)

                    // ── Sensor Log ──
                    sensorLogSection
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .background(Theme.backgroundPrimary)
    }

    // MARK: - Live Status

    @ViewBuilder
    private var sensorStatusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("$ sensor-status")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)

            HStack(spacing: Theme.Spacing.lg) {
                sensorIndicator(
                    label: "PRESENCE",
                    active: sensorRouter.isPersonPresent,
                    detail: sensorRouter.isPersonPresent ? "\(sensorRouter.personCount) person(s)" : "empty"
                )
                sensorIndicator(
                    label: "STT",
                    active: sensorRouter.sttEnabled,
                    detail: sensorRouter.lastTranscript.isEmpty ? "waiting..." : String(sensorRouter.lastTranscript.prefix(30))
                )
                sensorIndicator(
                    label: "SOUND",
                    active: sensorRouter.lastSoundType != nil,
                    detail: sensorRouter.lastSoundType ?? "quiet"
                )
            }
        }
    }

    private func sensorIndicator(label: String, active: Bool, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(active ? Theme.statusOnline : Theme.statusReady)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(Theme.Font.captionBold)
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(detail)
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - TTS

    @ViewBuilder
    private var ttsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("$ say --voice agent")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Text zum Sprechen...", text: $ttsInput)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.backgroundTertiary)
                    .onSubmit {
                        sendTTS()
                    }

                Button {
                    sendTTS()
                } label: {
                    Text("[SPEAK]")
                        .font(Theme.Font.captionBold)
                        .foregroundStyle(Theme.backgroundPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(sensorRouter.ttsEnabled ? Theme.accent : Theme.statusReady)
                }
                .buttonStyle(.plain)
                .disabled(!sensorRouter.ttsEnabled || ttsInput.isEmpty)

                Button {
                    sensorRouter.stopSpeaking()
                } label: {
                    Text("[STOP]")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Theme.Spacing.md) {
                Text("locale")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
                Picker("", selection: $sensorRouter.ttsLocale) {
                    Text("de-DE").tag("de-DE")
                    Text("en-US").tag("en-US")
                    Text("en-GB").tag("en-GB")
                    Text("fr-FR").tag("fr-FR")
                    Text("es-ES").tag("es-ES")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Text("rate")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
                Slider(value: $sensorRouter.ttsRate, in: 0.1...1.0, step: 0.1)
                    .tint(Theme.accent)
                    .frame(maxWidth: 100)
                Text(String(format: "%.1f", sensorRouter.ttsRate))
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 25)
            }
        }
    }

    private func sendTTS() {
        guard !ttsInput.isEmpty else { return }
        sensorRouter.speak(ttsInput)
        ttsInput = ""
    }

    // MARK: - Sensor Toggles

    @ViewBuilder
    private var sensorTogglesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("$ sensor-config")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)

            sensorToggle("Speech-to-Text (on-device)", isOn: $sensorRouter.sttEnabled)
            sensorToggle("Text-to-Speech", isOn: $sensorRouter.ttsEnabled)
            sensorToggle("Personen-Detektion (Kamera)", isOn: $sensorRouter.presenceEnabled)
            sensorToggle("Sound-Analyse (Mikrofon)", isOn: $sensorRouter.soundEnabled)

            if bonjourServer.connectedDevice == nil {
                Text("Kein Display verbunden — Sensoren inaktiv")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.statusError)
            }
        }
    }

    private func sensorToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                isOn.wrappedValue.toggle()
            } label: {
                Text(isOn.wrappedValue ? "[ON]" : "[OFF]")
                    .font(Theme.Font.caption)
                    .foregroundStyle(isOn.wrappedValue ? Theme.backgroundPrimary : Theme.textTertiary)
                    .frame(width: 40)
                    .padding(.vertical, 2)
                    .background(isOn.wrappedValue ? Theme.accent : Theme.backgroundTertiary)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - STT Log

    @ViewBuilder
    private var sttLogSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("$ tail -f stt.log")
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)

            if sensorRouter.sttLog.isEmpty {
                Text("Noch keine Spracheingaben empfangen")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(sensorRouter.sttLog.suffix(8).reversed()) { entry in
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(entry.timestamp, style: .time)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.textTertiary)
                        Text("[\(entry.locale)]")
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.textTertiary)
                        Text(entry.text)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Sensor Log

    @ViewBuilder
    private var sensorLogSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("$ tail -f sensor.log")
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)

            if sensorRouter.sensorLog.isEmpty {
                Text("Keine Sensor-Events")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ForEach(sensorRouter.sensorLog.suffix(10).reversed()) { entry in
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(entry.timestamp, style: .time)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.textTertiary)
                        Text(entry.type.rawValue)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(logColor(for: entry.type))
                            .frame(width: 30, alignment: .leading)
                        Text(entry.detail)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
    }

    private func logColor(for type: SensorLogEntry.SensorType) -> Color {
        switch type {
        case .stt:      return .cyan
        case .tts:      return .green
        case .presence: return .orange
        case .sound:    return .blue
        }
    }
}
