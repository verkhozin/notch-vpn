import Foundation
import Network

enum ReachabilityEvent: Sendable {
    case wentOnline
    case wentOffline
    case pathChanged
}

final class NetworkReachability: @unchecked Sendable {
    var onEvent: (@Sendable (ReachabilityEvent) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.egor.notchVpn.reachability")
    private let lock = NSLock()
    private var _isOnline: Bool = true
    private var lastInterfaceFingerprint: String = ""

    var isOnline: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isOnline
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let online = path.status == .satisfied
        let fingerprint = Self.fingerprint(for: path)

        var event: ReachabilityEvent?
        lock.lock()
        let wasOnline = _isOnline
        let oldFingerprint = lastInterfaceFingerprint
        _isOnline = online
        lastInterfaceFingerprint = fingerprint

        if wasOnline && !online {
            event = .wentOffline
        } else if !wasOnline && online {
            event = .wentOnline
        } else if online && oldFingerprint != fingerprint && !oldFingerprint.isEmpty {
            event = .pathChanged
        }
        lock.unlock()

        if let event {
            onEvent?(event)
        }
    }

    private static func fingerprint(for path: NWPath) -> String {
        let interfaces = path.availableInterfaces
            .map { "\($0.type.rawValue)-\($0.name)" }
            .sorted()
            .joined(separator: ",")
        return "\(path.status)|\(interfaces)"
    }
}

private extension NWInterface.InterfaceType {
    var rawValue: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "ethernet"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
