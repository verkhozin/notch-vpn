import Foundation

struct IPInfo: Sendable, Equatable {
    let ip: String
    let country: Country
    let provider: String
    let timestamp: Date
}
