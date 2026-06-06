import AppKit

@MainActor
final class AppCoordinator {
    private let monitor: VPNMonitor
    private let presenter: NotchPresenter
    private let menuBar: MenuBarController
    private let settings: AppSettings
    private var onboarding: OnboardingWindowController?

    private var lastStatus: VPNStatus = .unknown
    private var swallowFirstCountryChange = true
    private var pendingDropTask: Task<Void, Never>?

    init() {
        let providers: [any IPProvider] = [
            IpApiCoProvider(),
            IpWhoIsProvider(),
        ]
        let lookup = IPLookupService(providers: providers)
        self.monitor = VPNMonitor(
            lookup: lookup,
            reachability: NetworkReachability()
        )
        self.presenter = NotchPresenter()
        self.menuBar = MenuBarController()
        self.settings = AppSettings.shared
    }

    func start() {
        Log.app.info("AppCoordinator starting")
        menuBar.install()
        menuBar.updateHome(settings.homeCountry)

        monitor.onCountryChange = { [weak self] event in
            guard let self else { return }
            self.handleCountryChange(event)
        }
        monitor.onStatusChange = { [weak self] status in
            guard let self else { return }
            let previous = self.lastStatus
            self.lastStatus = status
            self.menuBar.update(status: status)
            self.handleStatusTransition(previous: previous, current: status)
            self.onboarding?.viewModel.currentCountry = status.country
        }

        menuBar.onForceRefresh = { [weak self] in
            self?.monitor.forceRefresh()
        }
        menuBar.onShowOnboarding = { [weak self] in
            self?.presentOnboarding()
        }
        menuBar.onSetHomeCurrent = { [weak self] in
            guard let self, case .connected(let country) = self.lastStatus else { return }
            self.settings.homeCountry = country
            self.menuBar.updateHome(country)
            Log.app.info("home country set to \(country.code, privacy: .public)")
        }

        presenter.show(event: .launch)
        monitor.start()

        if !settings.hasCompletedOnboarding {
            presentOnboarding()
        }
    }

    private func presentOnboarding() {
        if let existing = onboarding {
            existing.show()
            return
        }
        Log.app.info("presenting onboarding")
        let controller = OnboardingWindowController()
        controller.viewModel.currentCountry = lastStatus.country
        controller.viewModel.savedHome = settings.homeCountry
        controller.onSetHome = { [weak self] country in
            guard let self else { return }
            self.settings.homeCountry = country
            self.menuBar.updateHome(country)
            Log.app.info("home country set via onboarding: \(country.code, privacy: .public)")
            self.finishOnboarding()
        }
        controller.onSkip = { [weak self] in
            Log.app.info("onboarding skipped")
            self?.finishOnboarding()
        }
        onboarding = controller
        controller.show()
    }

    private func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        onboarding?.close()
        onboarding = nil
    }

    func stop() {
        Log.app.info("AppCoordinator stopping")
        monitor.stop()
    }

    private func handleCountryChange(_ event: CountryChangeEvent) {
        if swallowFirstCountryChange {
            swallowFirstCountryChange = false
            Log.app.debug(
                "swallowed initial country change to \(event.to.code, privacy: .public)"
            )
            return
        }
        if let home = settings.homeCountry,
           event.to.code == home.code,
           let from = event.from,
           from.code != home.code {
            Log.app.notice(
                "VPN drop: returned to home \(home.code, privacy: .public) from \(from.code, privacy: .public)"
            )
            presenter.show(event: .drop(previous: from))
            return
        }
        presenter.show(event: .restore(event))
    }

    private func handleStatusTransition(previous: VPNStatus, current: VPNStatus) {
        switch (previous, current) {
        case (.connected, .offline):
            scheduleDelayedDrop(previous: previous.country)
        case (.offline, .connected):
            if pendingDropTask != nil {
                Log.app.debug("offline blip resolved, suppressing drop")
                pendingDropTask?.cancel()
                pendingDropTask = nil
            }
        default:
            break
        }
    }

    private func scheduleDelayedDrop(previous: Country?) {
        pendingDropTask?.cancel()
        pendingDropTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self, !Task.isCancelled else { return }
            self.presenter.show(event: .drop(previous: previous))
            self.pendingDropTask = nil
        }
    }
}
