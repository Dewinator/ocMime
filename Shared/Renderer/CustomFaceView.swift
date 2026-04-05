import SwiftUI

struct CustomFaceView: View {

    let config: CustomAvatarConfig
    @ObservedObject var animator: EmotionAnimator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Layout constants (relative to view size)
    private let eyeSpacing: CGFloat = 0.32      // distance from center
    private let eyeY: CGFloat = 0.38            // vertical position
    private let eyebrowY: CGFloat = 0.24        // above eyes
    private let noseY: CGFloat = 0.58
    private let mouthY: CGFloat = 0.72
    private let eyeSize: CGFloat = 0.18         // relative to view width
    private let pupilSize: CGFloat = 0.07

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let shake = CGFloat(animator.shakeFactor)

            ZStack {
                // Background
                config.backgroundColor.swiftUI.ignoresSafeArea()

                // Face Outline
                if config.faceOutline.variant != .none {
                    faceOutlineLayer(w: w, h: h)
                        .modifier(PoseModifier(pose: animator.currentPose.faceOutline, breathe: animator.breatheScale))
                }

                // Accessory (behind face)
                if config.accessory.variant != .none {
                    accessoryLayer(w: w, h: h)
                        .modifier(PoseModifier(pose: animator.currentPose.accessory, breathe: 1))
                }

                // Left Eyebrow
                if config.eyebrowLeft.variant != .none {
                    eyebrowLayer(config: config.eyebrowLeft, x: -eyeSpacing, y: eyebrowY, w: w, h: h)
                        .modifier(PoseModifier(pose: animator.currentPose.eyebrowLeft, breathe: 1))
                }

                // Right Eyebrow
                let rbConfig = config.mirrorEyebrows ? config.eyebrowLeft : config.eyebrowRight
                if rbConfig.variant != .none {
                    eyebrowLayer(config: rbConfig, x: eyeSpacing, y: eyebrowY, w: w, h: h, mirror: true)
                        .modifier(PoseModifier(pose: animator.currentPose.eyebrowRight, breathe: 1))
                }

                // Left Eye + Pupil
                eyeWithPupil(
                    eyeConfig: config.eyeLeft,
                    pupilConfig: config.pupilLeft,
                    x: -eyeSpacing + CGFloat(config.eyeLeft.offsetX) / 100,
                    y: eyeY + CGFloat(config.eyeLeft.offsetY) / 100,
                    w: w, h: h,
                    eyePose: animator.currentPose.eyeLeft,
                    pupilPose: animator.currentPose.pupilLeft
                )

                // Right Eye + Pupil
                let reConfig = config.mirrorEyes ? config.eyeLeft : config.eyeRight
                let rpConfig = config.mirrorPupils ? config.pupilLeft : config.pupilRight
                eyeWithPupil(
                    eyeConfig: reConfig,
                    pupilConfig: rpConfig,
                    x: eyeSpacing + CGFloat(reConfig.offsetX) / 100,
                    y: eyeY + CGFloat(reConfig.offsetY) / 100,
                    w: w, h: h,
                    eyePose: animator.currentPose.eyeRight,
                    pupilPose: animator.currentPose.pupilRight
                )

                // Nose
                if config.nose.variant != .none {
                    noseLayer(w: w, h: h)
                }

                // Mouth
                if config.mouth.variant != .none {
                    mouthLayer(w: w, h: h)
                        .modifier(PoseModifier(pose: animator.currentPose.mouth, breathe: 1))
                }
            }
            .offset(x: shake)
        }
        .onAppear { animator.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, newValue in animator.reduceMotion = newValue }
    }

    // MARK: - Layers

    @ViewBuilder
    private func faceOutlineLayer(w: CGFloat, h: CGFloat) -> some View {
        let s = min(w, h) * CGFloat(config.faceOutline.size)
        FaceOutlineShape(variant: config.faceOutline.variant)
            .stroke(config.faceOutline.color.swiftUI, lineWidth: CGFloat(config.faceOutline.strokeWidth))
            .background(
                FaceOutlineShape(variant: config.faceOutline.variant)
                    .fill(config.faceOutline.color.swiftUI.opacity(config.faceOutline.fillOpacity))
            )
            .frame(width: s, height: s * 0.8)
            .position(x: w / 2, y: h / 2)
    }

    @ViewBuilder
    private func eyeWithPupil(eyeConfig: EyeConfig, pupilConfig: PupilConfig, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, eyePose: ComponentPose, pupilPose: ComponentPose) -> some View {
        let eyeW = w * eyeSize * CGFloat(eyeConfig.size)
        let posX = w / 2 + w * x
        let posY = h * y

        // Blink modifies scaleY
        let blinkScaleY = CGFloat(eyePose.scaleY) * CGFloat(animator.blinkFactor)

        // Eye
        ZStack {
            EyeShape(variant: eyeConfig.variant)
                .fill(eyeConfig.color.swiftUI)
                .frame(width: eyeW, height: eyeW * 0.85)
                .scaleEffect(x: CGFloat(eyePose.scaleX), y: max(0.02, blinkScaleY))

            // Pupil
            if pupilConfig.variant != .none && pupilPose.opacity > 0.01 {
                let pupilW = w * pupilSize * CGFloat(pupilConfig.size)
                PupilShape(variant: pupilConfig.variant)
                    .fill(pupilConfig.color.swiftUI)
                    .frame(width: pupilW, height: pupilW)
                    .offset(
                        x: CGFloat(pupilPose.offsetX + animator.pupilDriftX),
                        y: CGFloat(pupilPose.offsetY + animator.pupilDriftY)
                    )
                    .scaleEffect(x: CGFloat(pupilPose.scaleX), y: CGFloat(pupilPose.scaleY) * CGFloat(animator.blinkFactor))
                    .opacity(pupilPose.opacity)
            }
        }
        .offset(x: CGFloat(eyePose.offsetX), y: CGFloat(eyePose.offsetY))
        .rotationEffect(.degrees(eyePose.rotation))
        .position(x: posX, y: posY)
    }

    @ViewBuilder
    private func eyebrowLayer(config: EyebrowConfig, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, mirror: Bool = false) -> some View {
        let bw = w * 0.15 * CGFloat(config.thickness)
        let posX = w / 2 + w * x
        let posY = h * y + CGFloat(config.offsetY)

        EyebrowShape(variant: config.variant)
            .stroke(config.color.swiftUI, style: StrokeStyle(lineWidth: CGFloat(config.thickness) * 2.5, lineCap: .round))
            .frame(width: bw, height: bw * 0.5)
            .scaleEffect(x: mirror ? -1 : 1, y: 1)
            .position(x: posX, y: posY)
    }

    @ViewBuilder
    private func noseLayer(w: CGFloat, h: CGFloat) -> some View {
        let s = w * 0.06 * CGFloat(config.nose.size)
        NoseShape(variant: config.nose.variant)
            .fill(config.nose.color.swiftUI)
            .frame(width: s, height: s)
            .position(x: w / 2, y: h * noseY)
    }

    @ViewBuilder
    private func mouthLayer(w: CGFloat, h: CGFloat) -> some View {
        let mw = w * 0.3 * CGFloat(config.mouth.size)
        let posY = h * (mouthY + CGFloat(config.mouth.offsetY) / 100)

        MouthShape(variant: config.mouth.variant, openFactor: CGFloat(animator.mouthTalkFactor))
            .stroke(config.mouth.color.swiftUI, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: mw, height: mw * 0.4)
            .position(x: w / 2, y: posY)
    }

    @ViewBuilder
    private func accessoryLayer(w: CGFloat, h: CGFloat) -> some View {
        AccessoryShape(variant: config.accessory.variant)
            .stroke(config.accessory.color.swiftUI, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: w * 0.8, height: h * 0.8)
            .position(x: w / 2, y: h / 2)
    }
}

// MARK: - Pose View Modifier

struct PoseModifier: ViewModifier {
    let pose: ComponentPose
    let breathe: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: CGFloat(pose.scaleX * breathe), y: CGFloat(pose.scaleY * breathe))
            .offset(x: CGFloat(pose.offsetX), y: CGFloat(pose.offsetY))
            .rotationEffect(.degrees(pose.rotation))
            .opacity(pose.opacity)
    }
}
