import SwiftUI

struct AvatarEditorView: View {

    @ObservedObject var bonjourServer: BonjourServer
    @StateObject private var lottieEngine = LottieAnimationEngine()
    @StateObject private var emotionAnimator = EmotionAnimator()

    @State private var avatarMode: AvatarMode = .preset
    @State private var presetConfig = AvatarConfig.default
    @State private var customConfig = CustomAvatarConfig.default

    enum AvatarMode: String, CaseIterable {
        case preset = "PRESETS"
        case custom = "CUSTOM"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("~/openclaw/face/avatar")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            // Mode Toggle
            HStack(spacing: 0) {
                ForEach(AvatarMode.allCases, id: \.self) { mode in
                    Button {
                        avatarMode = mode
                    } label: {
                        Text("[\(mode.rawValue)]")
                            .font(Theme.Font.caption)
                            .foregroundStyle(avatarMode == mode ? Theme.backgroundPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(avatarMode == mode ? Theme.accent : Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            // Content
            switch avatarMode {
            case .preset:
                presetContent
            case .custom:
                CustomEditorView(config: $customConfig, animator: emotionAnimator, bonjourServer: bonjourServer)
            }

            // Push Button
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    pushToDisplay()
                } label: {
                    Text("[PUSH TO DISPLAY]")
                        .font(Theme.Font.captionBold)
                        .foregroundStyle(Theme.backgroundPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.accent)
                }
                .buttonStyle(.plain)

                if bonjourServer.connectedDevice != nil {
                    Text("Display verbunden")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.statusOnline)
                } else {
                    Text("Kein Display")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.statusReady)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.backgroundPrimary)
        .onAppear {
            loadConfigs()
            lottieEngine.setConfig(presetConfig)
        }
    }

    // MARK: - Preset Content

    @ViewBuilder
    private var presetContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Preview
            LottieFaceView(engine: lottieEngine)
                .frame(height: 160)
                .background(Color.black)

            // Emotion test
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(EmotionState.allCases) { state in
                        Button {
                            lottieEngine.setEmotion(state, intensity: 0.7)
                        } label: {
                            Text(state.label)
                                .font(Theme.Font.tiny)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Theme.backgroundTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(AvatarType.categories, id: \.self) { category in
                    Text("$ ls \(category.lowercased().replacingOccurrences(of: " ", with: "_"))/")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    ForEach(AvatarType.allCases.filter { $0.category == category }) { type in
                        Button {
                            presetConfig.avatarType = type
                            lottieEngine.setAvatar(type)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Circle()
                                    .fill(presetConfig.avatarType == type ? Theme.accent : Theme.statusReady)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.label)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(presetConfig.avatarType == type ? Theme.textPrimary : Theme.textSecondary)
                                    Text(type.description)
                                        .font(Theme.Font.tiny)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                if presetConfig.avatarType == type {
                                    Text("[ACTIVE]")
                                        .font(Theme.Font.tiny)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .background(presetConfig.avatarType == type ? Theme.accentLight : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    // MARK: - Actions

    private func pushToDisplay() {
        saveConfigs()
        switch avatarMode {
        case .preset:
            bonjourServer.sendAvatarConfig(presetConfig)
        case .custom:
            bonjourServer.sendCustomAvatarConfig(customConfig)
        }
    }

    private func saveConfigs() {
        if let data = presetConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.config")
        }
        if let data = customConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.custom")
        }
        UserDefaults.standard.set(avatarMode.rawValue, forKey: "avatar.mode")
    }

    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: "avatar.config"),
           let saved = AvatarConfig.from(data: data) {
            presetConfig = saved
        }
        if let data = UserDefaults.standard.data(forKey: "avatar.custom"),
           let saved = CustomAvatarConfig.from(data: data) {
            customConfig = saved
        }
        if let mode = UserDefaults.standard.string(forKey: "avatar.mode"),
           let m = AvatarMode(rawValue: mode) {
            avatarMode = m
        }
    }
}
