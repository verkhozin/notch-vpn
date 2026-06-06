import AppKit
import SwiftUI

@MainActor
final class NotchPresenter {
    private let panelSize = CGSize(width: 400, height: 110)
    private let displayDuration: TimeInterval = 0.7

    private let model = NotchAnimationModel()
    private var window: NotchWindow?
    private var hostingView: NSHostingView<NotchNotificationView>?

    func show(event: NotchEvent) {
        ensureWindow()
        guard let window, let hostingView else { return }

        let metrics = NotchMorphMetrics.current()
        hostingView.rootView = NotchNotificationView(
            model: model,
            metrics: metrics,
            panelSize: panelSize
        )

        window.setFrame(topAnchoredFrame(), display: true)
        window.alphaValue = 1
        window.orderFrontRegardless()

        model.play(event: event, holdDuration: displayDuration) { [weak self] in
            self?.hideWindow()
        }
    }

    func hide() {
        model.cancel()
        hideWindow()
    }

    private func ensureWindow() {
        guard window == nil else { return }
        let metrics = NotchMorphMetrics.current()
        let view = NotchNotificationView(
            model: model,
            metrics: metrics,
            panelSize: panelSize
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: panelSize)
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear

        let win = NotchWindow(contentRect: NSRect(origin: .zero, size: panelSize))
        win.contentView = host

        window = win
        hostingView = host
    }

    private func hideWindow() {
        window?.orderOut(nil)
    }

    private func topAnchoredFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = frame.midX - panelSize.width / 2
        let y = frame.maxY - panelSize.height
        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }
}
