import Foundation
import SwiftUI

// ════════════════════════════════════════════
// MARK: - Pose: describes how a component looks in a given emotion
// ════════════════════════════════════════════

struct ComponentPose {
    var scaleX: Double = 1.0
    var scaleY: Double = 1.0
    var offsetX: Double = 0
    var offsetY: Double = 0
    var rotation: Double = 0       // degrees
    var opacity: Double = 1.0

    static let identity = ComponentPose()

    func lerp(to target: ComponentPose, t: Double) -> ComponentPose {
        let t = min(max(t, 0), 1)
        return ComponentPose(
            scaleX: scaleX + (target.scaleX - scaleX) * t,
            scaleY: scaleY + (target.scaleY - scaleY) * t,
            offsetX: offsetX + (target.offsetX - offsetX) * t,
            offsetY: offsetY + (target.offsetY - offsetY) * t,
            rotation: rotation + (target.rotation - rotation) * t,
            opacity: opacity + (target.opacity - opacity) * t
        )
    }
}

// ════════════════════════════════════════════
// MARK: - Emotion Pose Tables
// ════════════════════════════════════════════

struct EmotionPoseSet {
    let eyeLeft: ComponentPose
    let eyeRight: ComponentPose
    let eyebrowLeft: ComponentPose
    let eyebrowRight: ComponentPose
    let pupilLeft: ComponentPose
    let pupilRight: ComponentPose
    let mouth: ComponentPose
    let faceOutline: ComponentPose
    let accessory: ComponentPose

    static func forEmotion(_ emotion: EmotionState) -> EmotionPoseSet {
        switch emotion {
        case .idle:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1, scaleY: 1),
                eyeRight: ComponentPose(scaleX: 1, scaleY: 1),
                eyebrowLeft: ComponentPose(offsetY: 0, rotation: 0),
                eyebrowRight: ComponentPose(offsetY: 0, rotation: 0),
                pupilLeft: ComponentPose(scaleX: 1, scaleY: 1, offsetX: 0, offsetY: 0),
                pupilRight: ComponentPose(scaleX: 1, scaleY: 1, offsetX: 0, offsetY: 0),
                mouth: ComponentPose(scaleX: 1, scaleY: 1),
                faceOutline: .identity,
                accessory: .identity
            )
        case .thinking:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1, scaleY: 0.6),
                eyeRight: ComponentPose(scaleX: 1, scaleY: 0.5),
                eyebrowLeft: ComponentPose(offsetY: -3, rotation: -5),
                eyebrowRight: ComponentPose(offsetY: -6, rotation: 10),
                pupilLeft: ComponentPose(offsetX: -8, offsetY: -3),
                pupilRight: ComponentPose(offsetX: -8, offsetY: -3),
                mouth: ComponentPose(scaleX: 0.7, scaleY: 0.8, offsetX: 5),
                faceOutline: .identity,
                accessory: .identity
            )
        case .focused:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1.05, scaleY: 0.35),
                eyeRight: ComponentPose(scaleX: 1.05, scaleY: 0.35),
                eyebrowLeft: ComponentPose(offsetY: -6, rotation: -8),
                eyebrowRight: ComponentPose(offsetY: -6, rotation: 8),
                pupilLeft: ComponentPose(scaleX: 0.8, scaleY: 0.8),
                pupilRight: ComponentPose(scaleX: 0.8, scaleY: 0.8),
                mouth: ComponentPose(scaleX: 1.2, scaleY: 0.5),
                faceOutline: ComponentPose(scaleX: 0.98, scaleY: 0.98),
                accessory: .identity
            )
        case .responding:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1, scaleY: 1.05),
                eyeRight: ComponentPose(scaleX: 1, scaleY: 1.05),
                eyebrowLeft: ComponentPose(offsetY: -4, rotation: -3),
                eyebrowRight: ComponentPose(offsetY: -4, rotation: 3),
                pupilLeft: ComponentPose(scaleX: 0.9, scaleY: 0.9),
                pupilRight: ComponentPose(scaleX: 0.9, scaleY: 0.9),
                mouth: ComponentPose(scaleX: 1.1, scaleY: 1.3),
                faceOutline: .identity,
                accessory: ComponentPose(rotation: 3)
            )
        case .error:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 0.8, scaleY: 0.15),
                eyeRight: ComponentPose(scaleX: 0.8, scaleY: 0.15),
                eyebrowLeft: ComponentPose(offsetY: -10, rotation: -20),
                eyebrowRight: ComponentPose(offsetY: -10, rotation: 20),
                pupilLeft: ComponentPose(scaleX: 0.5, scaleY: 0.5),
                pupilRight: ComponentPose(scaleX: 0.5, scaleY: 0.5),
                mouth: ComponentPose(scaleX: 1.3, scaleY: 0.4, offsetY: 4),
                faceOutline: ComponentPose(scaleX: 1.02, scaleY: 1.02),
                accessory: ComponentPose(rotation: -5)
            )
        case .success:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1.1, scaleY: 0.5, offsetY: 3),
                eyeRight: ComponentPose(scaleX: 1.1, scaleY: 0.5, offsetY: 3),
                eyebrowLeft: ComponentPose(offsetY: -8, rotation: 5),
                eyebrowRight: ComponentPose(offsetY: -8, rotation: -5),
                pupilLeft: ComponentPose(opacity: 0),
                pupilRight: ComponentPose(opacity: 0),
                mouth: ComponentPose(scaleX: 1.4, scaleY: 1.2, offsetY: 2),
                faceOutline: ComponentPose(scaleX: 1.03, scaleY: 1.03),
                accessory: ComponentPose(offsetY: -3)
            )
        case .listening:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1.2, scaleY: 1.3),
                eyeRight: ComponentPose(scaleX: 1.2, scaleY: 1.3),
                eyebrowLeft: ComponentPose(offsetY: -8),
                eyebrowRight: ComponentPose(offsetY: -8),
                pupilLeft: ComponentPose(scaleX: 1.2, scaleY: 1.2),
                pupilRight: ComponentPose(scaleX: 1.2, scaleY: 1.2),
                mouth: ComponentPose(scaleX: 0.5, scaleY: 0.8),
                faceOutline: .identity,
                accessory: ComponentPose(scaleX: 1.1, scaleY: 1.1, offsetY: -2)
            )
        case .sleeping:
            return EmotionPoseSet(
                eyeLeft: ComponentPose(scaleX: 1, scaleY: 0.05),
                eyeRight: ComponentPose(scaleX: 1, scaleY: 0.05),
                eyebrowLeft: ComponentPose(offsetY: 3, rotation: 5),
                eyebrowRight: ComponentPose(offsetY: 3, rotation: -5),
                pupilLeft: ComponentPose(opacity: 0),
                pupilRight: ComponentPose(opacity: 0),
                mouth: ComponentPose(scaleX: 0.4, scaleY: 0.3, offsetY: 3),
                faceOutline: ComponentPose(scaleX: 0.97, scaleY: 0.97, offsetY: 3),
                accessory: ComponentPose(offsetY: 4, rotation: -8)
            )
        }
    }
}

// ════════════════════════════════════════════
// MARK: - EmotionAnimator (the brain)
// ════════════════════════════════════════════

@MainActor
final class EmotionAnimator: ObservableObject {

    @Published var currentPose: EmotionPoseSet = .forEmotion(.idle)
    @Published var blinkFactor: Double = 1.0      // 1 = open, 0 = closed
    @Published var pupilDriftX: Double = 0
    @Published var pupilDriftY: Double = 0
    @Published var breatheScale: Double = 1.0
    @Published var mouthTalkFactor: Double = 0    // 0 = closed, 1 = open (responding)
    @Published var shakeFactor: Double = 0         // error shake

    private var emotion: EmotionState = .idle
    private var targetPose: EmotionPoseSet = .forEmotion(.idle)
    private var transitionProgress: Double = 1.0
    private var previousPose: EmotionPoseSet = .forEmotion(.idle)

    private var timer: Timer?
    private var frame: Int = 0

    // Mood memory
    private var emotionHistory: [EmotionState] = []
    private let historyLimit = 50

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setEmotion(_ state: EmotionState) {
        guard state != emotion else { return }
        previousPose = currentPose
        emotion = state
        targetPose = .forEmotion(state)
        transitionProgress = 0

        emotionHistory.append(state)
        if emotionHistory.count > historyLimit {
            emotionHistory.removeFirst()
        }
    }

    // MARK: - Mood (weighted recent history)

    var mood: EmotionState {
        guard !emotionHistory.isEmpty else { return .idle }
        // Most frequent in recent history
        var counts: [EmotionState: Int] = [:]
        for (i, e) in emotionHistory.enumerated() {
            let weight = i + 1  // newer = more weight
            counts[e, default: 0] += weight
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .idle
    }

    // MARK: - Tick (30fps)

    private func tick() {
        frame += 1

        // Smooth transition (ease-out)
        if transitionProgress < 1.0 {
            transitionProgress = min(1.0, transitionProgress + 0.06) // ~0.5s transition
            let t = easeOutCubic(transitionProgress)
            currentPose = lerpPoseSet(from: previousPose, to: targetPose, t: t)
        }

        // Blink (random interval, ~every 3-5 seconds)
        updateBlink()

        // Pupil drift (idle micro-movements)
        updatePupilDrift()

        // Breathe (subtle scale oscillation)
        let breatheSpeed: Double = emotion == .sleeping ? 0.03 : 0.05
        breatheScale = 1.0 + sin(Double(frame) * breatheSpeed) * 0.015

        // Mouth talk animation (responding)
        if emotion == .responding {
            mouthTalkFactor = abs(sin(Double(frame) * 0.18))
        } else {
            mouthTalkFactor = max(0, mouthTalkFactor - 0.05)
        }

        // Error shake
        if emotion == .error {
            shakeFactor = sin(Double(frame) * 0.8) * 4 * (1.0 + sin(Double(frame) * 0.3))
        } else {
            shakeFactor *= 0.85
            if abs(shakeFactor) < 0.1 { shakeFactor = 0 }
        }
    }

    // MARK: - Blink

    private var nextBlinkFrame: Int = 80
    private var blinkPhase: Int = 0  // 0=open, 1=closing, 2=opening

    private func updateBlink() {
        if emotion == .sleeping { blinkFactor = 0; return }

        if frame >= nextBlinkFrame && blinkPhase == 0 {
            blinkPhase = 1
        }

        switch blinkPhase {
        case 1: // closing
            blinkFactor = max(0, blinkFactor - 0.25)
            if blinkFactor <= 0 { blinkPhase = 2 }
        case 2: // opening
            blinkFactor = min(1, blinkFactor + 0.15)
            if blinkFactor >= 1 {
                blinkPhase = 0
                // Random interval: 80-150 frames (2.5-5s)
                nextBlinkFrame = frame + Int.random(in: 80...150)
            }
        default:
            blinkFactor = min(1, blinkFactor + 0.05)
        }
    }

    // MARK: - Pupil Drift

    private func updatePupilDrift() {
        if emotion == .thinking {
            // Active looking around
            pupilDriftX = sin(Double(frame) * 0.08) * 10
            pupilDriftY = cos(Double(frame) * 0.06) * 5
        } else if emotion == .listening {
            // Slight attentive movement
            pupilDriftX = sin(Double(frame) * 0.04) * 3
            pupilDriftY = cos(Double(frame) * 0.03) * 2
        } else if emotion == .idle {
            // Subtle micro-drift
            pupilDriftX = sin(Double(frame) * 0.02) * 2
            pupilDriftY = cos(Double(frame) * 0.015) * 1.5
        } else {
            pupilDriftX *= 0.9
            pupilDriftY *= 0.9
        }
    }

    // MARK: - Helpers

    private func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    private func lerpPoseSet(from a: EmotionPoseSet, to b: EmotionPoseSet, t: Double) -> EmotionPoseSet {
        EmotionPoseSet(
            eyeLeft: a.eyeLeft.lerp(to: b.eyeLeft, t: t),
            eyeRight: a.eyeRight.lerp(to: b.eyeRight, t: t),
            eyebrowLeft: a.eyebrowLeft.lerp(to: b.eyebrowLeft, t: t),
            eyebrowRight: a.eyebrowRight.lerp(to: b.eyebrowRight, t: t),
            pupilLeft: a.pupilLeft.lerp(to: b.pupilLeft, t: t),
            pupilRight: a.pupilRight.lerp(to: b.pupilRight, t: t),
            mouth: a.mouth.lerp(to: b.mouth, t: t),
            faceOutline: a.faceOutline.lerp(to: b.faceOutline, t: t),
            accessory: a.accessory.lerp(to: b.accessory, t: t)
        )
    }
}
