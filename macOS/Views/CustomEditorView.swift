import SwiftUI

struct CustomEditorView: View {

    @Binding var config: CustomAvatarConfig
    @ObservedObject var animator: EmotionAnimator
    @ObservedObject var bonjourServer: BonjourServer

    @State private var previewEmotion: EmotionState = .idle
    @State private var editSection: EditSection = .eyes

    enum EditSection: String, CaseIterable {
        case eyes = "EYES"
        case brows = "BROWS"
        case mouth = "MOUTH"
        case face = "FACE"
        case extras = "EXTRAS"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Live Preview
            CustomFaceView(config: config, animator: animator)
                .frame(height: 200)
                .clipped()
                .background(config.backgroundColor.swiftUI)
                .onAppear {
                    animator.start()
                    animator.setEmotion(.idle)
                }

            // Emotion test strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(EmotionState.allCases) { state in
                        Button {
                            previewEmotion = state
                            animator.setEmotion(state)
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
                .padding(.vertical, Theme.Spacing.sm)
            }

            // Section tabs
            HStack(spacing: 0) {
                ForEach(EditSection.allCases, id: \.self) { section in
                    Button {
                        editSection = section
                    } label: {
                        Text(section.rawValue)
                            .font(Theme.Font.tiny)
                            .foregroundStyle(editSection == section ? Theme.backgroundPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(editSection == section ? Theme.accent : Theme.backgroundTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Editor content
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    switch editSection {
                    case .eyes:   eyesEditor
                    case .brows:  browsEditor
                    case .mouth:  mouthEditor
                    case .face:   faceEditor
                    case .extras: extrasEditor
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.backgroundPrimary)
    }

    // MARK: - Eyes Editor

    @ViewBuilder
    private var eyesEditor: some View {
        Toggle(isOn: $config.mirrorEyes) {
            Text("Augen spiegeln")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .toggleStyle(.switch).tint(Theme.accent)

        sectionLabel("Linkes Auge (oder beide)")
        variantPicker("Form", items: EyeVariant.allCases, selected: $config.eyeLeft.variant)
        colorRow("Farbe", color: $config.eyeLeft.color)
        sliderRow("Groesse", value: $config.eyeLeft.size, range: 0.5...2.0)

        Toggle(isOn: $config.mirrorPupils) {
            Text("Pupillen spiegeln")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .toggleStyle(.switch).tint(Theme.accent)

        sectionLabel("Pupille")
        variantPicker("Form", items: PupilVariant.allCases, selected: $config.pupilLeft.variant)
        colorRow("Farbe", color: $config.pupilLeft.color)
        sliderRow("Groesse", value: $config.pupilLeft.size, range: 0.3...2.0)
    }

    // MARK: - Brows Editor

    @ViewBuilder
    private var browsEditor: some View {
        Toggle(isOn: $config.mirrorEyebrows) {
            Text("Augenbrauen spiegeln")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .toggleStyle(.switch).tint(Theme.accent)

        variantPicker("Form", items: EyebrowVariant.allCases, selected: $config.eyebrowLeft.variant)
        colorRow("Farbe", color: $config.eyebrowLeft.color)
        sliderRow("Dicke", value: $config.eyebrowLeft.thickness, range: 0.3...3.0)
    }

    // MARK: - Mouth Editor

    @ViewBuilder
    private var mouthEditor: some View {
        variantPicker("Form", items: MouthVariant.allCases, selected: $config.mouth.variant)
        colorRow("Farbe", color: $config.mouth.color)
        sliderRow("Groesse", value: $config.mouth.size, range: 0.3...2.0)
    }

    // MARK: - Face Editor

    @ViewBuilder
    private var faceEditor: some View {
        variantPicker("Umriss", items: FaceOutlineVariant.allCases, selected: $config.faceOutline.variant)
        colorRow("Farbe", color: $config.faceOutline.color)
        sliderRow("Groesse", value: $config.faceOutline.size, range: 0.5...1.5)
        sliderRow("Strichstaerke", value: $config.faceOutline.strokeWidth, range: 0.5...5.0)
        sliderRow("Fuellung", value: $config.faceOutline.fillOpacity, range: 0...0.5)

        sectionLabel("Nase")
        variantPicker("Form", items: NoseVariant.allCases, selected: $config.nose.variant)
        colorRow("Farbe", color: $config.nose.color)

        sectionLabel("Hintergrund")
        colorRow("Farbe", color: $config.backgroundColor)
    }

    // MARK: - Extras Editor

    @ViewBuilder
    private var extrasEditor: some View {
        variantPicker("Zubehoer", items: AccessoryVariant.allCases, selected: $config.accessory.variant)
        colorRow("Farbe", color: $config.accessory.color)
        sliderRow("Groesse", value: $config.accessory.size, range: 0.5...2.0)

        Divider().background(Theme.borderTertiary)

        sectionLabel("Presets")
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(CustomAvatarConfig.presets, id: \.name) { preset in
                Button {
                    config = preset
                } label: {
                    Text("[\(preset.name)]")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.backgroundTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Font.captionBold)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, Theme.Spacing.sm)
    }

    private func variantPicker<T: CaseIterable & Identifiable & RawRepresentable & Equatable>(
        _ label: String, items: T.AllCases, selected: Binding<T>
    ) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(Array(items), id: \.id) { item in
                        Button {
                            selected.wrappedValue = item
                        } label: {
                            Text(item.rawValue)
                                .font(Theme.Font.tiny)
                                .foregroundStyle(selected.wrappedValue == item ? Theme.backgroundPrimary : Theme.textPrimary)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(selected.wrappedValue == item ? Theme.accent : Theme.backgroundTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func colorRow(_ label: String, color: Binding<FaceColor>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(FaceColor.presets.enumerated()), id: \.offset) { _, preset in
                    Button {
                        color.wrappedValue = preset
                    } label: {
                        Circle()
                            .fill(preset.swiftUI)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().stroke(color.wrappedValue == preset ? Color.white : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 80, alignment: .trailing)
            Slider(value: value, in: range)
                .tint(Theme.accent)
            Text(String(format: "%.1f", value.wrappedValue))
                .font(Theme.Font.tiny)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30)
        }
    }
}
