import SwiftUI

struct DashboardView: View {

    @ObservedObject var gateway: GatewayService
    @ObservedObject var emotionRouter: EmotionRouter
    @ObservedObject var bonjourServer: BonjourServer

    @State private var selectedState: EmotionState = .idle
    @State private var intensity: Double = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

            Text("~/openclaw/face/bridge")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.lg)

            // Connection Status
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("$ status")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)

                statusRow("Gateway", connected: gateway.connectionState.isConnected, detail: gatewayDetail)
                statusRow("Display", connected: bonjourServer.connectedDevice != nil, detail: bonjourServer.connectedDevice ?? "waiting...")
                statusRow("Bonjour", connected: bonjourServer.isRunning, detail: bonjourServer.isRunning ? "advertising" : "stopped")
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Divider().background(Theme.borderTertiary)

            // Current Emotion
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("$ echo $EMOTION")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text(emotionRouter.currentEmotion.state.label.uppercased())
                        .font(Theme.Font.title)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("intensity")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                    Text(String(format: "%.1f", emotionRouter.currentEmotion.intensity))
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Divider().background(Theme.borderTertiary)

            // Manual Control
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("$ set-emotion --manual")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 4), spacing: Theme.Spacing.sm) {
                    ForEach(EmotionState.allCases) { state in
                        Button {
                            selectedState = state
                            emotionRouter.setEmotion(state, intensity: intensity, context: "manual")
                        } label: {
                            Text("[\(state.label)]")
                                .font(Theme.Font.caption)
                                .foregroundStyle(selectedState == state ? Theme.backgroundPrimary : Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(selectedState == state ? Theme.accent : Theme.backgroundTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Text("intensity")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Slider(value: $intensity, in: 0...1, step: 0.1)
                        .tint(Theme.accent)
                    Text(String(format: "%.1f", intensity))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Spacer()

            // Emotion Log
            if !emotionRouter.emotionLog.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("$ tail -f emotion.log")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)

                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(emotionRouter.emotionLog.suffix(6).reversed(), id: \.timestamp) { event in
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(event.timestamp, style: .time)
                                    .font(Theme.Font.tiny)
                                    .foregroundStyle(Theme.textTertiary)
                                Text(event.state.rawValue)
                                    .font(Theme.Font.tiny)
                                    .foregroundStyle(Theme.textPrimary)
                                if let ctx = event.context {
                                    Text(ctx)
                                        .font(Theme.Font.tiny)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                Text(String(format: "%.1f", event.intensity))
                                    .font(Theme.Font.tiny)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.backgroundPrimary)
    }

    private var gatewayDetail: String {
        if gateway.connectionState.isConnected {
            return gateway.connectionState.displayText
        }
        if gateway.reconnectAttempt > 0 {
            return "\(gateway.connectionState.displayText) (retry #\(gateway.reconnectAttempt))"
        }
        return gateway.connectionState.displayText
    }

    private func statusRow(_ label: String, connected: Bool, detail: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(connected ? Theme.statusOnline : Theme.statusReady)
                .frame(width: 6, height: 6)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 70, alignment: .leading)
            Text(detail)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }
}
