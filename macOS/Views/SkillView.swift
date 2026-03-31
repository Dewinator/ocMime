import SwiftUI

struct SkillView: View {

    @ObservedObject var gateway: GatewayService
    @StateObject private var skillService: EmotionSkillService

    init(gateway: GatewayService) {
        self.gateway = gateway
        _skillService = StateObject(wrappedValue: EmotionSkillService(gateway: gateway))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

            Text("~/openclaw/face/skill")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, Theme.Spacing.lg)

            // Info
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("$ cat EMOTION.md --info")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)

                Text("Der Emotion-Skill wird als EMOTION.md in den Agent-Workspace geschrieben. Er informiert den Agenten, dass sein Zustand auf einem Display sichtbar ist.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            Divider().background(Theme.borderTertiary)

            if !gateway.connectionState.isConnected {
                Text("Gateway nicht verbunden — zuerst unter [CONFIG] verbinden")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, Theme.Spacing.lg)
                Spacer()
            } else if skillService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Lade Agenten...")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                Spacer()
            } else {
                // Agent List
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("$ agents.list --emotion-skill")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    if skillService.availableAgents.isEmpty {
                        Text("Keine Agenten gefunden")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    ForEach(skillService.availableAgents) { agent in
                        HStack(spacing: Theme.Spacing.md) {
                            Circle()
                                .fill(agent.hasEmotionSkill ? Theme.statusOnline : Theme.statusReady)
                                .frame(width: 6, height: 6)

                            Text(agent.label ?? agent.id)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            if agent.hasEmotionSkill {
                                Button {
                                    Task { await skillService.removeSkill(agentId: agent.id) }
                                } label: {
                                    Text("[REMOVE]")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.danger)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.backgroundTertiary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    Task { await skillService.installSkill(agentId: agent.id) }
                                } label: {
                                    Text("[INSTALL]")
                                        .font(Theme.Font.captionBold)
                                        .foregroundStyle(Theme.backgroundPrimary)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Refresh
                Button {
                    Task { await skillService.loadAgents() }
                } label: {
                    Text("[REFRESH]")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer()
            }

            if let error = skillService.lastError {
                Text("ERR: \(error)")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.backgroundPrimary)
        .onAppear {
            if gateway.connectionState.isConnected {
                Task { await skillService.loadAgents() }
            }
        }
        .onChange(of: gateway.connectionState) { _, newState in
            if newState.isConnected {
                Task { await skillService.loadAgents() }
            }
        }
    }
}
