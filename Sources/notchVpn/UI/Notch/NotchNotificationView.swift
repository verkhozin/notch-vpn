import SwiftUI

struct NotchNotificationView: View {
    @ObservedObject var model: NotchAnimationModel
    let metrics: NotchMorphMetrics
    let panelSize: CGSize

    @State private var restoreStage: Int = 0
    @State private var staggerTask: Task<Void, Never>?

    private var style: NotchEventStyle {
        NotchEventStyle.style(for: model.event)
    }

    var body: some View {
        ZStack(alignment: .top) {
            outerGlow
            fillShape
            midGlow
            coreStroke
            sparkOverlay
            content
        }
        .frame(width: panelSize.width, height: panelSize.height, alignment: .top)
        .allowsHitTesting(false)
        .onAppear { handleEventChange(model.event) }
        .onDisappear { staggerTask?.cancel() }
        .onChange(of: model.event) { _, new in
            handleEventChange(new)
        }
    }

    private func handleEventChange(_ event: NotchEvent) {
        staggerTask?.cancel()
        restoreStage = 0
        guard case .restore(let change) = event, change.from != nil else { return }
        staggerTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(950))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                restoreStage = 1
            }
            try? await Task.sleep(for: .milliseconds(160))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                restoreStage = 2
            }
            try? await Task.sleep(for: .milliseconds(160))
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                restoreStage = 3
            }
        }
    }

    private var outerGlow: some View {
        NotchMorphHalo(heightT: model.heightT, widthT: model.widthT, metrics: metrics)
            .stroke(
                style.accent,
                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 10)
            .opacity(model.haloOpacity * (0.4 + 0.2 * model.haloPulse))
            .blendMode(.plusLighter)
    }

    private var fillShape: some View {
        NotchMorphShape(heightT: model.heightT, widthT: model.widthT, metrics: metrics)
            .fill(Color.black)
    }

    private var midGlow: some View {
        NotchMorphHalo(heightT: model.heightT, widthT: model.widthT, metrics: metrics)
            .stroke(
                style.accent,
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .blur(radius: 1.5)
            .opacity(model.haloOpacity * 0.85)
            .blendMode(.plusLighter)
    }

    private var coreStroke: some View {
        NotchMorphHalo(heightT: model.heightT, widthT: model.widthT, metrics: metrics)
            .stroke(
                style.accent,
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .opacity(model.haloOpacity)
    }

    @ViewBuilder
    private var sparkOverlay: some View {
        if style.showSpark {
            let cx = panelSize.width / 2
            let topHalfW = metrics.startHalfWidth
            let bottomHalfW = max(
                topHalfW,
                lerp(metrics.startHalfWidth, metrics.pillWidth / 2, model.widthT)
            )
            let h = lerp(metrics.startHeight, metrics.pillHeight, model.heightT)
            let alpha = sparkAlpha(model.sparkPhase)
            let scale = 0.4 + 4.5 * model.sparkPhase

            ZStack {
                spark()
                    .scaleEffect(scale)
                    .opacity(alpha)
                    .position(x: cx - bottomHalfW, y: h)
                spark()
                    .scaleEffect(scale)
                    .opacity(alpha)
                    .position(x: cx + bottomHalfW, y: h)
            }
        }
    }

    private func spark() -> some View {
        Circle()
            .fill(style.accent)
            .frame(width: 7, height: 7)
            .blur(radius: 3)
    }

    private func sparkAlpha(_ p: CGFloat) -> CGFloat {
        if p <= 0 { return 0 }
        if p < 0.3 { return p / 0.3 }
        return max(0, 1.0 - (p - 0.3) / 0.7)
    }

    private var content: some View {
        contentInner
            .padding(.top, metrics.startHeight + 4)
            .frame(width: panelSize.width, height: panelSize.height, alignment: .top)
            .opacity(model.contentOpacity)
            .offset(y: model.contentOffsetY)
            .mask(
                NotchMorphShape(heightT: model.heightT, widthT: model.widthT, metrics: metrics)
            )
    }

    @ViewBuilder
    private var contentInner: some View {
        if case .restore(let change) = model.event, let from = change.from {
            restoreContent(from: from, to: change.to)
        } else {
            standardContent
        }
    }

    private var standardContent: some View {
        HStack(spacing: 6) {
            iconView
            Text(style.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private func restoreContent(from: Country, to: Country) -> some View {
        HStack(spacing: 8) {
            Text(from.flag)
                .font(.system(size: 14))
                .opacity(restoreStage >= 1 ? 1 : 0)
                .offset(y: restoreStage >= 1 ? 0 : 6)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .opacity(restoreStage >= 2 ? 1 : 0)
                .scaleEffect(restoreStage >= 2 ? 1 : 0.4)

            HStack(spacing: 4) {
                Text(to.flag)
                    .font(.system(size: 14))
                Text(to.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .opacity(restoreStage >= 3 ? 1 : 0)
            .offset(y: restoreStage >= 3 ? 0 : 6)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let symbolName = style.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(style.accent)
                .symbolEffect(.drawOff, isActive: !model.symbolActive)
        } else if let flag = style.flag {
            Text(flag)
                .font(.system(size: 14))
        }
    }
}
