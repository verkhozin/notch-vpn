import SwiftUI

@MainActor
final class NotchAnimationModel: ObservableObject {
    @Published private(set) var event: NotchEvent = .launch
    @Published private(set) var heightT: CGFloat = 0
    @Published private(set) var widthT: CGFloat = 0
    @Published private(set) var haloOpacity: CGFloat = 0
    @Published private(set) var haloPulse: CGFloat = 0
    @Published private(set) var contentOpacity: CGFloat = 0
    @Published private(set) var contentOffsetY: CGFloat = 8
    @Published private(set) var sparkPhase: CGFloat = 0
    @Published private(set) var symbolActive: Bool = false

    private var sequenceTask: Task<Void, Never>?

    func play(
        event: NotchEvent,
        holdDuration: TimeInterval,
        onCompletion: @MainActor @escaping () -> Void
    ) {
        sequenceTask?.cancel()
        self.event = event

        heightT = 0
        widthT = 0
        haloOpacity = 0
        haloPulse = 0
        contentOpacity = 0
        contentOffsetY = 8
        sparkPhase = 0
        symbolActive = false

        let style = NotchEventStyle.style(for: event)
        let entrySpring = style.entrySpring
        let widthDelay = style.widthSpringDelay

        sequenceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(40))
            if Task.isCancelled { return }

            // Phase 1 — light up the notch outline (heightT and widthT still 0).
            withAnimation(.easeOut(duration: 0.22)) {
                self.haloOpacity = 1
            }
            // small breath while the user registers the highlight
            try? await Task.sleep(for: .milliseconds(120))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.34)) {
                self.haloPulse = 1
            }
            try? await Task.sleep(for: .milliseconds(280))
            if Task.isCancelled { return }

            // Phase 2 — pill morphs out from under the notch.
            if style.showSpark {
                withAnimation(.easeOut(duration: 0.55)) {
                    self.sparkPhase = 1
                }
            }
            withAnimation(entrySpring) {
                self.heightT = 1
            }
            withAnimation(entrySpring.delay(widthDelay)) {
                self.widthT = 1
            }
            try? await Task.sleep(for: .milliseconds(460))
            if Task.isCancelled { return }

            // Phase 3 — label fades in (icon container becomes visible but symbol not drawn yet).
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                self.contentOpacity = 1
                self.contentOffsetY = 0
            }

            // Phase 4 — micro pause, then draw the symbol on top of the now-stable label.
            try? await Task.sleep(for: .milliseconds(420))
            if Task.isCancelled { return }
            self.symbolActive = true

            try? await Task.sleep(for: .seconds(holdDuration))
            if Task.isCancelled { return }

            // Exit — pill retracts upward; content is clipped by the mask, no separate fade.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.92)) {
                self.heightT = 0
                self.widthT = 0
            }
            try? await Task.sleep(for: .milliseconds(420))
            if Task.isCancelled { return }

            withAnimation(.easeIn(duration: 0.18)) {
                self.haloOpacity = 0
                self.haloPulse = 0
            }
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { return }

            onCompletion()
        }
    }

    func cancel() {
        sequenceTask?.cancel()
        sequenceTask = nil
    }
}
