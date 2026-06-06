import SwiftUI

@MainActor
struct NotchEventStyle {
    let accent: Color
    let label: String
    let flag: String?
    let symbolName: String?
    let showSpark: Bool
    let entrySpring: Animation
    let widthSpringDelay: Double

    static func style(for event: NotchEvent) -> NotchEventStyle {
        switch event {
        case .launch:
            return NotchEventStyle(
                accent: Color(red: 0.55, green: 0.85, blue: 1.0),
                label: "notchVpn",
                flag: nil,
                symbolName: "antenna.radiowaves.left.and.right",
                showSpark: false,
                entrySpring: .spring(response: 0.45, dampingFraction: 0.85),
                widthSpringDelay: 0.04
            )

        case .drop:
            return NotchEventStyle(
                accent: Color(red: 1.0, green: 0.32, blue: 0.32),
                label: "Connection lost",
                flag: nil,
                symbolName: "wifi.slash",
                showSpark: true,
                entrySpring: .spring(response: 0.55, dampingFraction: 0.78),
                widthSpringDelay: 0.08
            )

        case .restore(let change):
            return NotchEventStyle(
                accent: Color(red: 0.36, green: 0.96, blue: 0.66),
                label: change.to.name,
                flag: change.to.flag,
                symbolName: nil,
                showSpark: false,
                entrySpring: .spring(response: 0.42, dampingFraction: 0.82),
                widthSpringDelay: 0.04
            )
        }
    }
}
