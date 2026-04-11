import SwiftUI

struct AvatarEditorView: View {

    @ObservedObject var bonjourServer: BonjourServer
    @StateObject private var lottieEngine = LottieAnimationEngine()
    @StateObject private var riveEngine = RiveAnimationEngine()
    @StateObject private var emotionAnimator = EmotionAnimator()
    @StateObject private var abstractAnimator = AbstractAnimator()

    @State private var avatarMode: AvatarMode = .abstract
    @State private var presetConfig = AvatarConfig.default
    @State private var customConfig = CustomAvatarConfig.default
    @State private var riveConfig = RiveAvatarConfig.default
    @State private var abstractConfig = AbstractAvatarConfig.default
    @State private var selectedRiveType: RiveAvatarType = .robotFace
    @State private var previewEmotion: EmotionState = .idle

    enum AvatarMode: String, CaseIterable {
        case abstract = "ABSTRACT"
        case eyes     = "EYES"
        case custom   = "CUSTOM"
        case rive     = "RIVE"
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
                    presetContent
                case .custom:
                    CustomEditorView(config: $customConfig, animator: emotionAnimator, bonjourServer: bonjourServer)
                case .rive:
                    riveContent
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
            lottieEngine.setConfig(presetConfig)
            lottieEngine.reduceMotion = reduceMotion
            emotionAnimator.reduceMotion = reduceMotion
            // Rive engine loads lazily — only when RIVE tab is selected and a type chosen
        }
        .onChange(of: avatarMode) { _, newMode in
            if newMode == .rive && !riveEngine.hasLoadedOnce {
                riveEngine.setType(selectedRiveType)
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            lottieEngine.reduceMotion = newValue
            emotionAnimator.reduceMotion = newValue
        }
    }

    // MARK: - Rive Content

    @ViewBuilder
    private var riveContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.sm) {
                // Preview
                RiveFaceView(engine: riveEngine)
                    .frame(height: 160)
                    .clipped()
                    .background(Color.black)

                // Emotion test
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(EmotionState.allCases) { state in
                            Button {
                                riveEngine.setEmotion(state, intensity: 0.7)
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
                Text("$ ls rive_avatars/")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textTertiary)

                ForEach(RiveAvatarType.allCases) { type in
                    Button {
                        selectedRiveType = type
                        riveConfig = RiveAvatarConfig(type: type)
                        riveEngine.setType(type)
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            Circle()
                                .fill(selectedRiveType == type ? Theme.accent : Theme.statusReady)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.label)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(selectedRiveType == type ? Theme.textPrimary : Theme.textSecondary)
                                Text(type.description)
                                    .font(Theme.Font.tiny)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            if selectedRiveType == type {
                                Text("[ACTIVE]")
                                    .font(Theme.Font.tiny)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .background(selectedRiveType == type ? Theme.accentLight : Color.clear)
                    }
                    .buttonStyle(.plain)
                }

                // Info about adding custom .riv files
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("$ cat README")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Eigene .riv Dateien in Shared/RiveAssets/ ablegen.")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                    Text("State Machine muss 'emotions' heissen mit Inputs:")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                    Text("  emotionState (Number 0-7), intensity (Number 0-1)")
                        .font(Theme.Font.tiny)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, Theme.Spacing.md)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    // MARK: - Preset Content

    @ViewBuilder
    private var presetContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.sm) {
                // Preview
                LottieFaceView(engine: lottieEngine)
                    .frame(height: 160)
                    .clipped()
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
    }

    // MARK: - Actions

    private func pushToDisplay() {
        saveConfigs()
        switch avatarMode {
        case .abstract:
            bonjourServer.sendAbstractAvatarConfig(abstractConfig)
        case .eyes:
            bonjourServer.sendAvatarConfig(presetConfig)
        case .custom:
            bonjourServer.sendCustomAvatarConfig(customConfig)
        case .rive:
            bonjourServer.sendRiveAvatarConfig(riveConfig)
        }
    }

    private func saveConfigs() {
        if let data = presetConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.config")
        }
        if let data = customConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.custom")
        }
        if let data = riveConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.rive")
        }
        if let data = abstractConfig.toData() {
            UserDefaults.standard.set(data, forKey: "avatar.abstract")
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
        if let data = UserDefaults.standard.data(forKey: "avatar.rive"),
           let saved = RiveAvatarConfig.from(data: data) {
            riveConfig = saved
            if let type = RiveAvatarType.allCases.first(where: { $0.fileName == saved.riveFile }) {
                selectedRiveType = type
            }
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

    // MARK: - Abstract Content

    @ViewBuilder
    private var abstractContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.sm) {
                AbstractFaceView(config: abstractConfig, animator: abstractAnimator)
                    .frame(height: 180)
                    .clipped()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(EmotionState.allCases) { state in
                            Button {
                                previewEmotion = state
                                abstractAnimator.setEmotion(state)
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

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("$ ls abstract_avatars/")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textTertiary)

                    ForEach(AbstractAvatarStyle.allCases) { style in
                        Button {
                            abstractConfig.style = style
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Circle()
                                    .fill(abstractConfig.style == style ? Theme.accent : Theme.statusReady)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.label)
                                        .font(Theme.Font.body)
                                        .foregroundStyle(abstractConfig.style == style ? Theme.textPrimary : Theme.textSecondary)
                                    Text(style.description)
                                        .font(Theme.Font.tiny)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                if abstractConfig.style == style {
                                    Text("[ACTIVE]")
                                        .font(Theme.Font.tiny)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .background(abstractConfig.style == style ? Theme.accentLight : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
}
