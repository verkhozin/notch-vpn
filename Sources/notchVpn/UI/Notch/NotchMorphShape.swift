import SwiftUI

struct NotchMorphMetrics: Equatable {
    let notch: NotchSize
    let pillWidth: CGFloat
    let pillHeight: CGFloat
    let notchCornerRadius: CGFloat
    let pillCornerRadius: CGFloat

    static let virtualHalfWidth: CGFloat = 92
    static let virtualHeight: CGFloat = 32

    var hasPhysicalNotch: Bool { notch.height > 0 }
    var startHalfWidth: CGFloat { hasPhysicalNotch ? notch.width / 2 : Self.virtualHalfWidth }
    var startHeight: CGFloat { hasPhysicalNotch ? notch.height : Self.virtualHeight }

    @MainActor
    static func current(
        pillWidth: CGFloat = 320,
        pillHeight: CGFloat = 64,
        notchCornerRadius: CGFloat = 6,
        pillCornerRadius: CGFloat = 22
    ) -> NotchMorphMetrics {
        NotchMorphMetrics(
            notch: NotchSize.current(),
            pillWidth: pillWidth,
            pillHeight: pillHeight,
            notchCornerRadius: notchCornerRadius,
            pillCornerRadius: pillCornerRadius
        )
    }
}

struct NotchMorphShape: Shape {
    var heightT: CGFloat
    var widthT: CGFloat
    let metrics: NotchMorphMetrics

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(heightT, widthT) }
        set {
            heightT = newValue.first
            widthT = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        notchMorphPath(in: rect, heightT: heightT, widthT: widthT, metrics: metrics, kind: .closed)
    }
}

struct NotchMorphHalo: Shape {
    var heightT: CGFloat
    var widthT: CGFloat
    let metrics: NotchMorphMetrics

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(heightT, widthT) }
        set {
            heightT = newValue.first
            widthT = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        notchMorphPath(in: rect, heightT: heightT, widthT: widthT, metrics: metrics, kind: .bottomOutline)
    }
}

private enum NotchMorphPathKind {
    case closed
    case bottomOutline
}

private func notchMorphPath(
    in rect: CGRect,
    heightT: CGFloat,
    widthT: CGFloat,
    metrics: NotchMorphMetrics,
    kind: NotchMorphPathKind
) -> Path {
    let cx = rect.midX
    let halfW = lerp(metrics.startHalfWidth, metrics.pillWidth / 2, widthT)
    let h = lerp(metrics.startHeight, metrics.pillHeight, heightT)
    let radiusT = max(heightT, widthT)
    let rawR = lerp(metrics.notchCornerRadius, metrics.pillCornerRadius, radiusT)
    let r = max(0.5, min(rawR, min(h - 0.5, halfW - 0.5)))

    var path = Path()

    switch kind {
    case .closed:
        path.move(to: CGPoint(x: cx - halfW, y: 0))
        path.addLine(to: CGPoint(x: cx + halfW, y: 0))
        path.addLine(to: CGPoint(x: cx + halfW, y: h - r))
        path.addQuadCurve(
            to: CGPoint(x: cx + halfW - r, y: h),
            control: CGPoint(x: cx + halfW, y: h)
        )
        path.addLine(to: CGPoint(x: cx - halfW + r, y: h))
        path.addQuadCurve(
            to: CGPoint(x: cx - halfW, y: h - r),
            control: CGPoint(x: cx - halfW, y: h)
        )
        path.closeSubpath()

    case .bottomOutline:
        path.move(to: CGPoint(x: cx - halfW, y: 0))
        path.addLine(to: CGPoint(x: cx - halfW, y: h - r))
        path.addQuadCurve(
            to: CGPoint(x: cx - halfW + r, y: h),
            control: CGPoint(x: cx - halfW, y: h)
        )
        path.addLine(to: CGPoint(x: cx + halfW - r, y: h))
        path.addQuadCurve(
            to: CGPoint(x: cx + halfW, y: h - r),
            control: CGPoint(x: cx + halfW, y: h)
        )
        path.addLine(to: CGPoint(x: cx + halfW, y: 0))
    }

    return path
}
