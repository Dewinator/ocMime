import SwiftUI

// ════════════════════════════════════════════
// MARK: - Color Extension
// ════════════════════════════════════════════

extension FaceColor {
    var swiftUI: Color {
        Color(red: r, green: g, blue: b).opacity(a)
    }
}

// ════════════════════════════════════════════
// MARK: - Face Outline Shapes
// ════════════════════════════════════════════

struct FaceOutlineShape: Shape {
    let variant: FaceOutlineVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width * 0.45, h = rect.height * 0.45

        switch variant {
        case .circle:
            p.addEllipse(in: CGRect(x: cx - w, y: cy - h, width: w * 2, height: h * 2))
        case .roundedRect:
            p.addRoundedRect(in: CGRect(x: cx - w, y: cy - h, width: w * 2, height: h * 2), cornerSize: CGSize(width: w * 0.3, height: h * 0.3))
        case .oval:
            p.addEllipse(in: CGRect(x: cx - w, y: cy - h * 0.85, width: w * 2, height: h * 1.7))
        case .square:
            p.addRect(CGRect(x: cx - w * 0.85, y: cy - h * 0.85, width: w * 1.7, height: h * 1.7))
        case .hexagon:
            let r = min(w, h)
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3 - .pi / 2
                let px = cx + CGFloat(cos(angle)) * r
                let py = cy + CGFloat(sin(angle)) * r
                if i == 0 { p.move(to: CGPoint(x: px, y: py)) }
                else { p.addLine(to: CGPoint(x: px, y: py)) }
            }
            p.closeSubpath()
        case .none:
            break
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Eye Shapes
// ════════════════════════════════════════════

struct EyeShape: Shape {
    let variant: EyeVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width * 0.45, h = rect.height * 0.45

        switch variant {
        case .round:
            p.addEllipse(in: CGRect(x: cx - w, y: cy - h, width: w * 2, height: h * 2))
        case .oval:
            p.addEllipse(in: CGRect(x: cx - w, y: cy - h * 0.7, width: w * 2, height: h * 1.4))
        case .almond:
            p.move(to: CGPoint(x: cx - w, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy - h * 1.2))
            p.addQuadCurve(to: CGPoint(x: cx - w, y: cy), control: CGPoint(x: cx, y: cy + h * 0.6))
        case .droopy:
            p.move(to: CGPoint(x: cx - w, y: cy - h * 0.3))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy + h * 0.2), control: CGPoint(x: cx, y: cy - h))
            p.addQuadCurve(to: CGPoint(x: cx - w, y: cy - h * 0.3), control: CGPoint(x: cx, y: cy + h * 0.8))
        case .wide:
            p.addEllipse(in: CGRect(x: cx - w * 1.1, y: cy - h * 1.1, width: w * 2.2, height: h * 2.2))
        case .slit:
            p.move(to: CGPoint(x: cx - w, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy - h * 0.5))
            p.addQuadCurve(to: CGPoint(x: cx - w, y: cy), control: CGPoint(x: cx, y: cy + h * 0.5))
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Eyebrow Shapes
// ════════════════════════════════════════════

struct EyebrowShape: Shape {
    let variant: EyebrowVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width * 0.4, h = rect.height * 0.1

        switch variant {
        case .straight:
            p.move(to: CGPoint(x: cx - w, y: cy))
            p.addLine(to: CGPoint(x: cx + w, y: cy))
        case .arched:
            p.move(to: CGPoint(x: cx - w, y: cy + h))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy + h), control: CGPoint(x: cx, y: cy - h * 4))
        case .angry:
            p.move(to: CGPoint(x: cx - w, y: cy - h * 2))
            p.addLine(to: CGPoint(x: cx + w, y: cy + h * 2))
        case .worried:
            p.move(to: CGPoint(x: cx - w, y: cy + h))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy - h * 3), control: CGPoint(x: cx, y: cy - h * 2))
        case .thick:
            p.addRoundedRect(in: CGRect(x: cx - w, y: cy - h * 1.5, width: w * 2, height: h * 3), cornerSize: CGSize(width: h, height: h))
        case .none:
            break
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Pupil Shapes
// ════════════════════════════════════════════

struct PupilShape: Shape {
    let variant: PupilVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) * 0.35

        switch variant {
        case .round:
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        case .vertical:
            p.addEllipse(in: CGRect(x: cx - r * 0.35, y: cy - r, width: r * 0.7, height: r * 2))
        case .horizontal:
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r * 0.35, width: r * 2, height: r * 0.7))
        case .star:
            for i in 0..<5 {
                let outerAngle = Double(i) * .pi * 2 / 5 - .pi / 2
                let innerAngle = outerAngle + .pi / 5
                let ox = cx + CGFloat(cos(outerAngle)) * r
                let oy = cy + CGFloat(sin(outerAngle)) * r
                let ix = cx + CGFloat(cos(innerAngle)) * r * 0.4
                let iy = cy + CGFloat(sin(innerAngle)) * r * 0.4
                if i == 0 { p.move(to: CGPoint(x: ox, y: oy)) }
                else { p.addLine(to: CGPoint(x: ox, y: oy)) }
                p.addLine(to: CGPoint(x: ix, y: iy))
            }
            p.closeSubpath()
        case .dot:
            p.addEllipse(in: CGRect(x: cx - r * 0.3, y: cy - r * 0.3, width: r * 0.6, height: r * 0.6))
        case .none:
            break
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Nose Shapes
// ════════════════════════════════════════════

struct NoseShape: Shape {
    let variant: NoseVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let s = min(rect.width, rect.height) * 0.25

        switch variant {
        case .triangle:
            p.move(to: CGPoint(x: cx, y: cy - s))
            p.addLine(to: CGPoint(x: cx - s * 0.7, y: cy + s * 0.5))
            p.addLine(to: CGPoint(x: cx + s * 0.7, y: cy + s * 0.5))
            p.closeSubpath()
        case .round:
            p.addEllipse(in: CGRect(x: cx - s * 0.4, y: cy - s * 0.3, width: s * 0.8, height: s * 0.6))
        case .line:
            p.move(to: CGPoint(x: cx, y: cy - s * 0.5))
            p.addLine(to: CGPoint(x: cx, y: cy + s * 0.5))
        case .dot:
            p.addEllipse(in: CGRect(x: cx - s * 0.2, y: cy - s * 0.2, width: s * 0.4, height: s * 0.4))
        case .none:
            break
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Mouth Shapes
// ════════════════════════════════════════════

struct MouthShape: Shape {
    let variant: MouthVariant
    var openFactor: CGFloat = 0  // 0 = resting, 1 = fully open

    var animatableData: CGFloat {
        get { openFactor }
        set { openFactor = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width * 0.3, h = rect.height * 0.1

        switch variant {
        case .line:
            p.move(to: CGPoint(x: cx - w, y: cy))
            p.addLine(to: CGPoint(x: cx + w, y: cy))
        case .smile:
            let drop = h * (1 + openFactor * 3)
            p.move(to: CGPoint(x: cx - w, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy + drop))
        case .open:
            let openH = h * (1 + openFactor * 4)
            p.addEllipse(in: CGRect(x: cx - w * 0.5, y: cy - openH * 0.5, width: w, height: openH))
        case .small:
            let sw = w * 0.4
            p.move(to: CGPoint(x: cx - sw, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + sw, y: cy), control: CGPoint(x: cx, y: cy + h * (1 + openFactor * 2)))
        case .wide:
            let drop = h * (0.5 + openFactor * 3)
            p.move(to: CGPoint(x: cx - w * 1.2, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + w * 1.2, y: cy), control: CGPoint(x: cx, y: cy + drop))
            if openFactor > 0.3 {
                p.move(to: CGPoint(x: cx - w * 1.2, y: cy))
                p.addQuadCurve(to: CGPoint(x: cx + w * 1.2, y: cy), control: CGPoint(x: cx, y: cy - drop * 0.3))
            }
        case .none:
            break
        }
        return p
    }
}

// ════════════════════════════════════════════
// MARK: - Accessory Shapes
// ════════════════════════════════════════════

struct AccessoryShape: Shape {
    let variant: AccessoryVariant

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX, cy = rect.midY
        let w = rect.width, h = rect.height

        switch variant {
        case .none: break
        case .ears:
            // Left ear
            p.addEllipse(in: CGRect(x: cx - w * 0.48, y: cy - h * 0.15, width: w * 0.12, height: h * 0.25))
            // Right ear
            p.addEllipse(in: CGRect(x: cx + w * 0.36, y: cy - h * 0.15, width: w * 0.12, height: h * 0.25))
        case .horns:
            // Left horn
            p.move(to: CGPoint(x: cx - w * 0.2, y: cy - h * 0.3))
            p.addLine(to: CGPoint(x: cx - w * 0.28, y: cy - h * 0.48))
            p.addLine(to: CGPoint(x: cx - w * 0.14, y: cy - h * 0.35))
            // Right horn
            p.move(to: CGPoint(x: cx + w * 0.2, y: cy - h * 0.3))
            p.addLine(to: CGPoint(x: cx + w * 0.28, y: cy - h * 0.48))
            p.addLine(to: CGPoint(x: cx + w * 0.14, y: cy - h * 0.35))
        case .antenna:
            p.move(to: CGPoint(x: cx, y: cy - h * 0.35))
            p.addLine(to: CGPoint(x: cx, y: cy - h * 0.48))
            p.addEllipse(in: CGRect(x: cx - w * 0.02, y: cy - h * 0.5, width: w * 0.04, height: w * 0.04))
        case .halo:
            p.addEllipse(in: CGRect(x: cx - w * 0.18, y: cy - h * 0.47, width: w * 0.36, height: h * 0.08))
        case .glasses:
            // Left lens
            p.addEllipse(in: CGRect(x: cx - w * 0.25, y: cy - h * 0.12, width: w * 0.2, height: h * 0.18))
            // Right lens
            p.addEllipse(in: CGRect(x: cx + w * 0.05, y: cy - h * 0.12, width: w * 0.2, height: h * 0.18))
            // Bridge
            p.move(to: CGPoint(x: cx - w * 0.05, y: cy - h * 0.03))
            p.addLine(to: CGPoint(x: cx + w * 0.05, y: cy - h * 0.03))
        case .bow:
            // Left loop
            p.move(to: CGPoint(x: cx, y: cy - h * 0.38))
            p.addQuadCurve(to: CGPoint(x: cx, y: cy - h * 0.38), control: CGPoint(x: cx - w * 0.12, y: cy - h * 0.48))
            // Right loop
            p.addQuadCurve(to: CGPoint(x: cx, y: cy - h * 0.38), control: CGPoint(x: cx + w * 0.12, y: cy - h * 0.48))
            // Center knot
            p.addEllipse(in: CGRect(x: cx - w * 0.02, y: cy - h * 0.4, width: w * 0.04, height: h * 0.04))
        }
        return p
    }
}
