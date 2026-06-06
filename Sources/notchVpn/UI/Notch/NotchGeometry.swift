import AppKit

struct NotchSize: Equatable, Sendable {
    let width: CGFloat
    let height: CGFloat

    static let fallback = NotchSize(width: 180, height: 0)

    @MainActor
    static func current() -> NotchSize {
        guard let screen = NSScreen.main else { return .fallback }
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return .fallback }

        let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let notchWidth = screen.frame.width - leftWidth - rightWidth
        return NotchSize(width: max(notchWidth, 1), height: height)
    }
}
