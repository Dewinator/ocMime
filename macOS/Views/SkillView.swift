import SwiftUI

struct SkillView: View {

    @ObservedObject var gateway: GatewayService
    @ObservedObject var agentTarget: AgentTargetService
    @StateObject private var skillService: EmotionSkillService

    init(gateway: GatewayService, agentTarget: AgentTargetService) {
        self.gateway = gateway
        self.agentTarget = agentTarget
        _skillService = StateObject(wrappedValue: EmotionSkillService(gateway: gateway))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                Text("~/openclaw/face/skill")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.textSecondary)

                // ── Voice target config ──
                voiceTargetSection

                Divider().background(Theme.borderTertiary)

                // ── Emotion skill info ──
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("$ cat EMOTION.md --info")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    Text("Der Emotion-Skill wird als EMOTION.md in den Agent-Workspace geschrieben und lehrt den Agenten, Inline-Marker wie [emotion:thinking] zu setzen. Die Bridge parst diese aus Chat-Text und faerbt den Display-State.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(Theme.borderTertiary)

                if !gateway.connectionState.isConnected {
                    Text("Gateway nicht verbunden — zuerst unter [CONFIG] verbinden")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.danger)
                } else if skillService.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Lade Agenten...")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    agentListSection
                }

                if let error = skillService.lastError {
                    Text("ERR: \(error)")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.lg)
        }
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

    // MARK: - Voice target section

    @ViewBuilder
    private var voiceTargetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("$ cat voice.target")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)

            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(agentTarget.config.isConfigured ? Theme.statusOnline : Theme.statusReady)
                    .frame(width: 6, height: 6)
                Text(agentTarget.config.isConfigured
                     ? "Voice -> \(agentTarget.config.agentLabel.isEmpty ? agentTarget.config.agentId : agentTarget.config.agentLabel)"
                     : "Voice-Upstream nicht konfiguriert")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if agentTarget.config.isConfigured {
                    Button {
                        agentTarget.config.agentId = ""
                        agentTarget.config.agentLabel = ""
                    } label: {
                        Text("[CLEAR]")
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Method configuration (editable)
            HStack(spacing: Theme.Spacing.sm) {
                Text("method")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 80, alignment: .trailing)
                TextField("agents.chat", text: $agentTarget.config.chatMethod)
                    .font(Theme.Font.caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Theme.backgroundTertiary)
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("text param")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 80, alignment: .trailing)
                TextField("text", text: $agentTarget.config.paramNameForText)
                    .font(Theme.Font.caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Theme.backgroundTertiary)
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("id param")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 80, alignment: .trailing)
                TextField("agentId", text: $agentTarget.config.paramNameForAgentId)
                    .font(Theme.Font.caption)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Theme.backgroundTertiary)
            }

            // Behaviour toggles
            toggleRow("Agent-Antworten automatisch sprechen", $agentTarget.config.autoTTSResponse)
            toggleRow("Begruessung bei Raumbetritt", $agentTarget.config.proactiveGreetOnEntry)
        }
    }

    @ViewBuilder
    private func toggleRow(_ label: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                value.wrappedValue.toggle()
            } label: {
                Text(value.wrappedValue ? "[ON]" : "[OFF]")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(value.wrappedValue ? Theme.backgroundPrimary : Theme.textTertiary)
                    .frame(width: 36)
                    .padding(.vertical, 2)
                    .background(value.wrappedValue ? Theme.accent : Theme.backgroundTertiary)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Agent list

    @ViewBuilder
    private var agentListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("$ agents.list")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textTertiary)

            if skillService.availableAgents.isEmpty {
                Text("Keine Agenten gefunden")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(skillService.availableAgents) { agent in
                agentRow(agent)
            }

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
            .padding(.top, Theme.Spacing.xs)
        }
    }

    @ViewBuilder
    private func agentRow(_ agent: EmotionSkillService.AgentInfo) -> some View {
        let isTarget = agentTarget.config.agentId == agent.id
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(agent.hasEmotionSkill ? Theme.statusOnline : Theme.statusReady)
                    .frame(width: 6, height: 6)

                Text(agent.label ?? agent.id)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)

                if isTarget {
                    Text("[VOICE TARGET]")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.accent)
                }

                Spacer()

                if agent.hasEmotionSkill {
                    Button {
                        Task { await skillService.removeSkill(agentId: agent.id) }
                    } label: {
                        Text("[REMOVE SKILL]")
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await skillService.installSkill(agentId: agent.id) }
                    } label: {
                        Text("[INSTALL SKILL]")
                            .font(Theme.Font.tiny)
                            .foregroundStyle(Theme.backgroundPrimary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if isTarget {
                        agentTarget.config.agentId = ""
                        agentTarget.config.agentLabel = ""
                    } else {
                        agentTarget.config.agentId = agent.id
                        agentTarget.config.agentLabel = agent.label ?? agent.id
                    }
                } label: {
                    Text(isTarget ? "[UNSET]" : "[SET VOICE]")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(isTarget ? Theme.danger : Theme.textPrimary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }
}
