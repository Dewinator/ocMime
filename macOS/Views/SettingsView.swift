import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var gateway: GatewayService

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

            // Header
            Text("~/openclaw/face/settings")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.lg)

            // Connection Config
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("$ cat gateway.conf")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)

                configField("nickname", text: $viewModel.nickname)
                configField("host", text: $viewModel.host, prompt: "100.64.0.1 or gateway.example.com")
                configField("port", text: $viewModel.port)

                HStack {
                    Text("token")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 80, alignment: .trailing)
                    SecureField("Gateway Token", text: $viewModel.token)
                        .font(Theme.Font.body)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Theme.Spacing.xs)
                        .background(Theme.backgroundTertiary)
                }

                Toggle(isOn: $viewModel.useSSL) {
                    Text("useSSL (wss://)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Divider()
                .background(Theme.borderTertiary)

            // Actions
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    Text(viewModel.isTesting ? "[TESTING...]" : "[TEST]")
                        .font(Theme.Font.captionBold)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isTesting || viewModel.host.isEmpty)

                if gateway.connectionState.isConnected {
                    Button {
                        viewModel.disconnect()
                    } label: {
                        Text("[DISCONNECT]")
                            .font(Theme.Font.captionBold)
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await viewModel.connect() }
                    } label: {
                        Text("[CONNECT]")
                            .font(Theme.Font.captionBold)
                            .foregroundStyle(Theme.backgroundPrimary)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.host.isEmpty || viewModel.token.isEmpty)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            // Test Result
            if let result = viewModel.testResult {
                Text(result)
                    .font(Theme.Font.caption)
                    .foregroundStyle(result.starts(with: "OK") ? Theme.success : Theme.danger)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            // Connection Status
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(gateway.connectionState.displayText)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            if let error = gateway.lastError {
                Text("ERR: \(error)")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.backgroundPrimary)
    }

    private func configField(_ label: String, text: Binding<String>, prompt: String = "") -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 80, alignment: .trailing)
            TextField(prompt, text: text)
                .font(Theme.Font.body)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.textPrimary)
                .padding(Theme.Spacing.xs)
                .background(Theme.backgroundTertiary)
        }
    }

    private var statusColor: Color {
        switch gateway.connectionState {
        case .connected:    return Theme.statusOnline
        case .connecting:   return Theme.statusActive
        case .disconnected: return Theme.statusReady
        case .error:        return Theme.statusError
        }
    }
}
