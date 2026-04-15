import SwiftUI

// MARK: - Animator
//
// Smoothes the per-emotion palette/speed so transitions don't snap.

@MainActor
final class AbstractAnimator: ObservableObject {

    // Deliberately NOT @Published: these are mutated 60× per second by the
    // Canvas TimelineView. Publishing would invalidate every observing view
    // on every frame and stall SwiftUI. The Canvas re-reads them on each
    // tick anyway, so no subscription is needed.
    private(set) var blendedPalette = EmotionPalette.forEmotion(.idle)
    private(set) var currentEmotion: EmotionState = .idle

    var reduceMotion: Bool = false

    private var sourcePalette = EmotionPalette.forEmotion(.idle)
    private var targetPalette = EmotionPalette.forEmotion(.idle)
    private var transition: Double = 1.0      // 0 ... 1
    private var lastUpdate = Date()

    func setEmotion(_ state: EmotionState) {
        guard state != currentEmotion else { return }
        sourcePalette = blendedPalette
        targetPalette = EmotionPalette.forEmotion(state)
        transition = 0
        currentEmotion = state
        if reduceMotion {
            transition = 1
            blendedPalette = targetPalette
        }
    }

    /// Called by the Canvas TimelineView once per frame. Time is in seconds.
    func tick(absoluteTime: Double) {
        let dt = max(0, min(0.1, absoluteTime - lastUpdate.timeIntervalSinceReferenceDate))
        lastUpdate = Date(timeIntervalSinceReferenceDate: absoluteTime)
        if reduceMotion {
            transition = 1
            blendedPalette = targetPalette
            return
        }
        if transition < 1 {
            transition = min(1, transition + dt * 1.6) // ~0.6s ease
            let t = easeOutCubic(transition)
            blendedPalette = EmotionPalette(
                primary: lerpRGB(sourcePalette.primary, targetPalette.primary, t),
                secondary: lerpRGB(sourcePalette.secondary, targetPalette.secondary, t),
                glow: sourcePalette.glow + (targetPalette.glow - sourcePalette.glow) * t,
                speed: sourcePalette.speed + (targetPalette.speed - sourcePalette.speed) * t
            )
        }
    }

    private func easeOutCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    private func lerpRGB(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> (Double, Double, Double) {
        (a.0 + (b.0 - a.0) * t,
         a.1 + (b.1 - a.1) * t,
         a.2 + (b.2 - a.2) * t)
    }
}

// MARK: - View

struct AbstractFaceView: View {

    let config: AbstractAvatarConfig
    let animator: AbstractAnimator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: true) { ctx, size in
                animator.tick(absoluteTime: now)
                let palette = animator.blendedPalette
                let phase = now * palette.speed
                AbstractFaceRenderer.draw(
                    style: config.style,
                    in: &ctx,
                    size: size,
                    phase: phase,
                    palette: palette,
                    emotion: animator.currentEmotion,
                    reduceMotion: reduceMotion
                )
            }
        }
        .background(Color.black)
        .onAppear { animator.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, newValue in animator.reduceMotion = newValue }
    }
}

// MARK: - Renderer

enum AbstractFaceRenderer {

    static func draw(
        style: AbstractAvatarStyle,
        in ctx: inout GraphicsContext,
        size: CGSize,
        phase: Double,
        palette: EmotionPalette,
        emotion: EmotionState,
        reduceMotion: Bool
    ) {
        switch style {
        case .pulseOrb:     drawPulseOrb(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        case .neuralRing:   drawNeuralRing(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        case .plasmaCore:   drawPlasmaCore(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        case .particleHalo: drawParticleHalo(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        case .waveform:     drawWaveform(&ctx, size: size, phase: phase, palette: palette, emotion: emotion, reduceMotion: reduceMotion)
        case .gradientFlow: drawGradientFlow(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        case .ringBars:     drawRingBars(&ctx, size: size, phase: phase, palette: palette, reduceMotion: reduceMotion)
        }
    }

    // MARK: Helpers

    private static func color(_ rgb: (r: Double, g: Double, b: Double), opacity: Double = 1) -> Color {
        Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }

    private static func breathe(_ phase: Double, amount: Double = 0.06, speed: Double = 0.7) -> Double {
        1 + sin(phase * speed) * amount
    }

    // MARK: Pulse Orb
    //
    // A central radial-gradient core inside layered glow halos. The core
    // breathes, the halos drift slightly out of phase so you get a sense of
    // depth without any pre-baked assets.

    private static func drawPulseOrb(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let baseR = min(size.width, size.height) * 0.18
        let breath = reduceMotion ? 1 : breathe(phase, amount: 0.08, speed: 0.9)

        // Outer halos (additive blend for that OLED bloom look)
        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in stride(from: 6, to: 0, by: -1) {
                let r = baseR * Double(i) * 0.95 * breath
                let alpha = 0.07 * palette.glow * (1 - Double(i) / 7)
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                layer.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            color(palette.primary, opacity: alpha),
                            color(palette.primary, opacity: 0)
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }

        // Bright core
        let coreR = baseR * breath
        let coreRect = CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)
        ctx.fill(
            Path(ellipseIn: coreRect),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.95),
                    color(palette.primary, opacity: 0.85),
                    color(palette.secondary, opacity: 0.0)
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: coreR
            )
        )
    }

    // MARK: Neural Ring
    //
    // Concentric arc segments that rotate at different speeds. Looks like a
    // tiny synapse firing — clearly "thinking" energy.

    private static func drawNeuralRing(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let baseR = min(size.width, size.height) * 0.36
        let speed = reduceMotion ? 0 : 1.0

        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter

            for ringIndex in 0..<4 {
                let r = baseR * (0.35 + Double(ringIndex) * 0.18)
                let segments = 6 + ringIndex * 2
                let segLen = (.pi * 2) / Double(segments) * 0.55
                let dir: Double = ringIndex.isMultiple(of: 2) ? 1 : -1
                let rot = phase * speed * (0.4 + Double(ringIndex) * 0.18) * dir

                for seg in 0..<segments {
                    let start = Double(seg) * (.pi * 2 / Double(segments)) + rot
                    let end = start + segLen
                    var path = Path()
                    path.addArc(
                        center: CGPoint(x: cx, y: cy),
                        radius: r,
                        startAngle: .radians(start),
                        endAngle: .radians(end),
                        clockwise: false
                    )
                    let alpha = 0.35 + 0.55 * palette.glow * (1 - Double(ringIndex) * 0.18)
                    layer.stroke(
                        path,
                        with: .color(color(palette.primary, opacity: alpha)),
                        style: StrokeStyle(lineWidth: 4 - Double(ringIndex) * 0.6, lineCap: .round)
                    )
                }
            }

            // Center node
            let nodeR = baseR * 0.18
            let nodeRect = CGRect(x: cx - nodeR, y: cy - nodeR, width: nodeR * 2, height: nodeR * 2)
            layer.fill(
                Path(ellipseIn: nodeRect),
                with: .radialGradient(
                    Gradient(colors: [
                        .white.opacity(0.9),
                        color(palette.primary, opacity: 0.7),
                        color(palette.secondary, opacity: 0)
                    ]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: nodeR
                )
            )
        }
    }

    // MARK: Plasma Core
    //
    // A noisy energetic blob built out of overlapping additive ellipses
    // animated through trigonometric phase. Cheap to render, looks alive.

    private static func drawPlasmaCore(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let baseR = min(size.width, size.height) * 0.22
        let speed = reduceMotion ? 0 : 1.0

        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            let blobs = 7
            for i in 0..<blobs {
                let t = Double(i) / Double(blobs) * .pi * 2
                let driftX = cos(t + phase * 0.6 * speed) * baseR * 0.6
                let driftY = sin(t * 1.2 + phase * 0.7 * speed) * baseR * 0.5
                let r = baseR * (0.7 + 0.4 * sin(t * 2 + phase * speed))
                let rect = CGRect(x: cx + driftX - r, y: cy + driftY - r, width: r * 2, height: r * 2)
                let mix = 0.5 + 0.5 * sin(t * 1.4 + phase * speed * 0.5)
                let blend = (
                    palette.primary.r * mix + palette.secondary.r * (1 - mix),
                    palette.primary.g * mix + palette.secondary.g * (1 - mix),
                    palette.primary.b * mix + palette.secondary.b * (1 - mix)
                )
                layer.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            color(blend, opacity: 0.55 * palette.glow),
                            color(blend, opacity: 0)
                        ]),
                        center: CGPoint(x: cx + driftX, y: cy + driftY),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }
    }

    // MARK: Particle Halo
    //
    // 36 small particles in orbital motion around a calm center. Looks like
    // attention focused on a thought.

    private static func drawParticleHalo(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let baseR = min(size.width, size.height) * 0.32
        let speed = reduceMotion ? 0 : 1.0
        let count = 36

        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<count {
                let t = Double(i) / Double(count) * .pi * 2
                let orbit = baseR * (1 + sin(t * 3 + phase * 0.6 * speed) * 0.18)
                let x = cx + cos(t + phase * 0.3 * speed) * orbit
                let y = cy + sin(t + phase * 0.3 * speed) * orbit
                let r = 3.0 + 2.0 * (0.5 + 0.5 * sin(t * 2 + phase * speed))
                let alpha = 0.55 + 0.45 * sin(t + phase * speed)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                layer.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            color(palette.primary, opacity: alpha * palette.glow),
                            color(palette.primary, opacity: 0)
                        ]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }

            // Center calm dot
            let dotR = 6.0
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            layer.fill(Path(ellipseIn: dotRect), with: .color(color(palette.primary, opacity: 0.9)))
        }
    }

    // MARK: Waveform
    //
    // A horizontal symmetric waveform — louder when responding, almost flat
    // when sleeping. Composed of two mirrored sine sums for an organic shape.

    private static func drawWaveform(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, emotion: EmotionState, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let width = size.width * 0.7
        let amplitudeBase: Double
        switch emotion {
        case .responding, .listening: amplitudeBase = 1.0
        case .thinking, .focused:     amplitudeBase = 0.55
        case .error:                  amplitudeBase = 1.2
        case .sleeping:               amplitudeBase = 0.08
        default:                      amplitudeBase = 0.35
        }
        let amplitude = (reduceMotion ? 0.2 : 1.0) * amplitudeBase * size.height * 0.18

        let steps = 64
        var path = Path()
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = cx - width / 2 + width * t
            let envelope = sin(.pi * t)
            let y = cy + sin(t * .pi * 6 + phase * 2) * amplitude * envelope
                       + sin(t * .pi * 13 + phase * 3.1) * amplitude * 0.35 * envelope
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        color(palette.secondary, opacity: 0.6 * palette.glow),
                        color(palette.primary, opacity: palette.glow),
                        color(palette.secondary, opacity: 0.6 * palette.glow)
                    ]),
                    startPoint: CGPoint(x: cx - width / 2, y: cy),
                    endPoint: CGPoint(x: cx + width / 2, y: cy)
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            // Mirror, slightly dimmed.
            var mirror = path
            mirror = mirror.applying(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -2 * cy))
            layer.stroke(
                mirror,
                with: .color(color(palette.primary, opacity: 0.35 * palette.glow)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
    }

    // MARK: Gradient Flow
    //
    // Animated angular gradient inside a circle — like a slow lava lamp.

    private static func drawGradientFlow(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) * 0.36
        let speed = reduceMotion ? 0 : 1.0

        let circle = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        ctx.drawLayer { layer in
            // base fill, soft
            layer.fill(circle, with: .radialGradient(
                Gradient(colors: [
                    color(palette.secondary, opacity: 0.35),
                    .black
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: r
            ))

            layer.blendMode = .plusLighter
            // Angular gradient via thin rotating wedges (Canvas has no native conic).
            let wedges = 36
            for i in 0..<wedges {
                let angle = Double(i) / Double(wedges) * .pi * 2 + phase * 0.4 * speed
                let nextAngle = angle + (.pi * 2 / Double(wedges))
                var path = Path()
                path.move(to: CGPoint(x: cx, y: cy))
                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: r,
                    startAngle: .radians(angle),
                    endAngle: .radians(nextAngle),
                    clockwise: false
                )
                path.closeSubpath()
                let mix = 0.5 + 0.5 * sin(angle * 2 + phase * speed)
                let blend = (
                    palette.primary.r * mix + palette.secondary.r * (1 - mix),
                    palette.primary.g * mix + palette.secondary.g * (1 - mix),
                    palette.primary.b * mix + palette.secondary.b * (1 - mix)
                )
                layer.fill(path, with: .color(color(blend, opacity: 0.18 * palette.glow)))
            }

            // Bright center highlight
            let hr = r * 0.35
            layer.fill(
                Path(ellipseIn: CGRect(x: cx - hr, y: cy - hr, width: hr * 2, height: hr * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        .white.opacity(0.45),
                        color(palette.primary, opacity: 0)
                    ]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: hr
                )
            )
        }
    }

    // MARK: Ring Bars (Siri-like)
    //
    // 48 radial bars with a length envelope driven by a moving sine pulse.
    // Reads as "the assistant is alive and listening."

    private static func drawRingBars(_ ctx: inout GraphicsContext, size: CGSize, phase: Double, palette: EmotionPalette, reduceMotion: Bool) {
        let cx = size.width / 2
        let cy = size.height / 2
        let inner = min(size.width, size.height) * 0.24
        let outerMax = min(size.width, size.height) * 0.42
        let speed = reduceMotion ? 0 : 1.0
        let bars = 48

        ctx.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<bars {
                let t = Double(i) / Double(bars) * .pi * 2
                let envelope = 0.5 + 0.5 * sin(t * 3 + phase * 1.4 * speed)
                let outer = inner + (outerMax - inner) * envelope
                let cosT = cos(t), sinT = sin(t)
                var path = Path()
                path.move(to: CGPoint(x: cx + cosT * inner, y: cy + sinT * inner))
                path.addLine(to: CGPoint(x: cx + cosT * outer, y: cy + sinT * outer))
                let alpha = 0.4 + 0.55 * envelope
                layer.stroke(
                    path,
                    with: .color(color(palette.primary, opacity: alpha * palette.glow)),
                    style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
                )
            }

            // Inner faint ring
            let ring = Path(ellipseIn: CGRect(x: cx - inner, y: cy - inner, width: inner * 2, height: inner * 2))
            layer.stroke(ring, with: .color(color(palette.primary, opacity: 0.4 * palette.glow)), lineWidth: 1.2)
        }
    }
}
