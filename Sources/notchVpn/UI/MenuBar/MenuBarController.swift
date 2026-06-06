import AppKit

@MainActor
final class MenuBarController: NSObject {
    var onForceRefresh: (() -> Void)?
    var onSetHomeCurrent: (() -> Void)?
    var onShowOnboarding: (() -> Void)?

    private var statusItem: NSStatusItem?
    private weak var statusLabel: NSMenuItem?
    private weak var homeLabel: NSMenuItem?
    private weak var setHomeItem: NSMenuItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🌐"
        item.button?.toolTip = "notchVpn"

        let menu = NSMenu()
        menu.autoenablesItems = false

        let label = NSMenuItem(title: "Status: probing…", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        statusLabel = label

        let home = NSMenuItem(title: "Home: —", action: nil, keyEquivalent: "")
        home.isEnabled = false
        menu.addItem(home)
        homeLabel = home

        menu.addItem(.separator())

        let setHome = NSMenuItem(
            title: "Set current country as home",
            action: #selector(setHomeCurrent),
            keyEquivalent: ""
        )
        setHome.target = self
        setHome.isEnabled = false
        menu.addItem(setHome)
        setHomeItem = setHome

        menu.addItem(.separator())

        let refresh = NSMenuItem(
            title: "Force refresh now",
            action: #selector(forceRefresh),
            keyEquivalent: "r"
        )
        refresh.target = self
        menu.addItem(refresh)

        let onboarding = NSMenuItem(
            title: "Show onboarding…",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboarding.target = self
        menu.addItem(onboarding)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit notchVpn",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    func update(status: VPNStatus) {
        switch status {
        case .unknown:
            statusItem?.button?.title = "🌐"
            statusLabel?.title = "Status: probing…"
        case .offline:
            statusItem?.button?.title = "🚫"
            statusLabel?.title = "Status: offline"
        case .connected(let country):
            statusItem?.button?.title = country.flag
            statusLabel?.title = "Status: \(country.flag) \(country.name)"
        }
        setHomeItem?.isEnabled = status.country != nil
    }

    func updateHome(_ home: Country?) {
        if let home {
            homeLabel?.title = "Home: \(home.flag) \(home.name)"
        } else {
            homeLabel?.title = "Home: —"
        }
    }

    @objc private func forceRefresh() { onForceRefresh?() }
    @objc private func setHomeCurrent() { onSetHomeCurrent?() }
    @objc private func showOnboarding() { onShowOnboarding?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
