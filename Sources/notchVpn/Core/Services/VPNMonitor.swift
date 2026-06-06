import Foundation

@MainActor
final class VPNMonitor {
    var onCountryChange: ((CountryChangeEvent) -> Void)?
    var onStatusChange: ((VPNStatus) -> Void)?

    private(set) var status: VPNStatus = .unknown

    private let lookup: IPLookupService
    private let reachability: NetworkReachability
    private var task: Task<Void, Never>?
    private var pendingTick: Task<Void, Never>?

    private let baseInterval: TimeInterval = 30
    private let maxInterval: TimeInterval = 60
    private var currentInterval: TimeInterval

    init(lookup: IPLookupService, reachability: NetworkReachability) {
        self.lookup = lookup
        self.reachability = reachability
        self.currentInterval = baseInterval
    }

    func start() {
        task?.cancel()
        Log.monitor.info("monitor started, base=\(self.baseInterval, privacy: .public)s max=\(self.maxInterval, privacy: .public)s")

        reachability.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleReachabilityEvent(event)
            }
        }

        task = Task { [weak self] in
            await self?.loop()
        }
    }

    func stop() {
        Log.monitor.info("monitor stopped")
        reachability.onEvent = nil
        task?.cancel()
        task = nil
        pendingTick?.cancel()
        pendingTick = nil
    }

    func forceRefresh() {
        Log.monitor.info("forceRefresh requested")
        scheduleImmediateTick()
    }

    private func handleReachabilityEvent(_ event: ReachabilityEvent) {
        switch event {
        case .wentOffline:
            Log.monitor.notice("network offline — flipping status reactively")
            currentInterval = baseInterval
            updateStatus(.offline)
        case .wentOnline:
            Log.monitor.info("network online — refreshing immediately")
            currentInterval = baseInterval
            scheduleImmediateTick()
        case .pathChanged:
            Log.monitor.notice("network path changed — refreshing immediately")
            currentInterval = baseInterval
            scheduleImmediateTick()
        }
    }

    private func scheduleImmediateTick() {
        pendingTick?.cancel()
        pendingTick = Task { [weak self] in
            await self?.tick()
        }
    }

    private func loop() async {
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: .seconds(currentInterval))
        }
    }

    private func tick() async {
        guard reachability.isOnline else {
            Log.monitor.info("offline — skipping fetch")
            updateStatus(.offline)
            currentInterval = baseInterval
            return
        }
        do {
            let info = try await lookup.currentIP()
            Log.monitor.info("tick ok: country=\(info.country.code, privacy: .public) provider=\(info.provider, privacy: .public)")
            handle(info: info)
        } catch {
            currentInterval = min(currentInterval * 1.5, maxInterval)
            Log.monitor.error("tick failed: \(error.localizedDescription, privacy: .public) — next=\(self.currentInterval, privacy: .public)s")
        }
    }

    private func handle(info: IPInfo) {
        let previous = status.country
        if previous?.code != info.country.code {
            let event = CountryChangeEvent(
                from: previous,
                to: info.country,
                timestamp: info.timestamp
            )
            Log.monitor.notice("country change: \(previous?.code ?? "nil", privacy: .public) → \(info.country.code, privacy: .public)")
            onCountryChange?(event)
        }
        currentInterval = baseInterval
        updateStatus(.connected(country: info.country))
    }

    private func updateStatus(_ new: VPNStatus) {
        guard new != status else { return }
        status = new
        onStatusChange?(new)
    }
}
