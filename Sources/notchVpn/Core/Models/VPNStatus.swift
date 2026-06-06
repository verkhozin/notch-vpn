import Foundation

enum VPNStatus: Sendable, Equatable {
    case unknown
    case offline
    case connected(country: Country)

    var country: Country? {
        if case .connected(let c) = self { return c }
        return nil
    }
}

struct CountryChangeEvent: Sendable, Equatable {
    let from: Country?
    let to: Country
    let timestamp: Date
}
