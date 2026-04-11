import SwiftUI

struct AvatarEditorView: View {

    @ObservedObject var bonjourServer: BonjourServer
    @StateObject private var emotionAnimator = EmotionAnimator()
    @StateObject private var abstractAnimator = AbstractAnimator()

    @State private var avatarMode: AvatarMode = .abstract
    @State private var customConfig = CustomAvatarConfig.default
    @State private var abstractConfig = AbstractAvatarConfig.default
    @State private var previewEmotion: EmotionState = .idle

    enum AvatarMode: String, CaseIterable {
        case abstract = "ABSTRACT"
        case eyes     = "EYES"
        case custom   = "CUSTOM"
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            // Content
            Group {
                switch avatarMode {
                case .abstract:
                    abstractContent
                case .eyes:
                    eyesContent
                case .custom:
                    CustomEditorView(config: $customConfig, animator: emotionAnimator, bonjourServer: bonjourServer)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .layoutPriority(1)

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
            emotionAnimator.reduceMotion = reduceMotion
            emotionAnimator.start()
        }
        .onChange(of: reduceMotion) { _, newValue in
            emotionAnimator.reduceMotion = newValue
        }
    }

    // MARK: - Abstract Content

    @ViewBuilder
    private var abstractContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.sm) {
                AbstractFaceView(config: abstractConfig, animator: abstractAnimator)
                    .frame(height: 200)
                    .clipped()

                emotionPreviewBar { state in
                    abstractAnimator.setEmotion(state)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("$ ls abstract_avatars/")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    ForEach(AbstractAvatarStyle.allCases) { style in
                        Button {
                            abstractConfig.style = style
                        } label: {
                            styleRow(
                                isActive: abstractConfig.style == style,
                                label: style.label,
                                description: style.description
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Eyes Content

    @ViewBuilder
    private var eyesContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.sm) {
                CustomFaceView(config: customConfig, animator: emotionAnimator)
                    .frame(height: 200)
                    .clipped()
                    .background(Color.black)

                emotionPreviewBar { state in
                    emotionAnimator.setEmotion(state)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("$ ls eyes_presets/")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    ForEach(CustomAvatarConfig.eyesPresets, id: \.name) { preset in
                        Button {
                            customConfig = preset
                        } label: {
                            styleRow(
                                isActive: customConfig.name == preset.name,
                                label: preset.name,
                                description: eyesDescription(for: preset)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private func eyesDescription(for preset: CustomAvatarConfig) -> String {
        "\(preset.eyeLeft.variant.label.lowercased()) · \(preset.pupilLeft.variant.label.lowercased()) · \(colorName(preset.eyeLeft.color))"
    }

    private func colorName(_ c: FaceColor) -> String {
        if c == .green { return "green" }
        if c == .cyan  { return "cyan" }
        if c == .orange { return "orange" }
        if c == .blue { return "blue" }
        if c == .purple { return "purple" }
        if c == .white { return "white" }
        return "custom"
    }

    // MARK: - Shared UI bits

    @ViewBuilder
    private func emotionPreviewBar(apply: @escaping (EmotionState) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(EmotionState.allCases) { state in
                    Button {
                        previewEmotion = state
                        apply(state)
                    } label: {
                        Text(state.label)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(previewEmotion == state ? Theme.backgroundPrimary : Theme.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(previewEmotion == state ? Theme.accent : Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func styleRow(isActive: Bool, label: String, description: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(isActive ? Theme.accent : Theme.statusReady)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Font.body)
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textSecondary)
                Text(description)
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if isActive {
                Text("[ACTIVE]")
                    .font(Theme.Font.tiny)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(isActive ? Theme.accentLight : Color.clear)
    }

    // MARK: - Push

    private func pushToDisplay() {
        saveConfigs()
        switch avatarMode {
        case .abstract:
            bonjourServer.sendAbstractAvatarConfig(abstractConfig)
        case .eyes, .custom:
            bonjourServer.sendCustomAvatarConfig(customConfig)
        }
    }

    private func saveConfigs() {
        if let data = customConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.custom")
        }
        if let data = abstractConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.abstract")
        }
        UserDefaults.standard.set(avatarMode.rawValue, forKey: "avatar.mode")
    }

    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: "avatar.custom"),
           let saved = CustomAvatarConfig.from(data: data) {
            customConfig = saved
        }
        if let data = UserDefaults.standard.data(forKey: "avatar.abstract"),
           let saved = AbstractAvatarConfig.from(data: data) {
            abstractConfig = saved
        }
        if let mode = UserDefaults.standard.string(forKey: "avatar.mode"),
           let m = AvatarMode(rawValue: mode) {
            avatarMode = m
        }
    }
}
