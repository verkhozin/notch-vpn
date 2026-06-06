import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    let viewModel = OnboardingViewModel()
    var onSetHome: ((Country) -> Void)?
    var onSkip: (() -> Void)?

    private var window: NSWindow?

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(
            model: viewModel,
            onSetHome: { [weak self] c in self?.onSetHome?(c) },
            onSkip: { [weak self] in self?.onSkip?() }
        )
        let host = NSHostingController(rootView: view)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.contentViewController = host
        win.center()
        win.delegate = self
        win.isReleasedWhenClosed = false
        window = win

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        guard let win = window else { return }
        win.delegate = nil
        win.orderOut(nil)
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        onSkip?()
        window = nil
    }
}
