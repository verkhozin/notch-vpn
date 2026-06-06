import Foundation

protocol IPProvider: Sendable {
    var name: String { get }
    func fetch() async throws -> IPInfo
}

enum IPProviderError: Error, Sendable {
    case rateLimited
    case invalidResponse
    case decodingFailed
    case allProvidersFailed([ProviderFailure])
}

struct ProviderFailure: Sendable, CustomStringConvertible {
    let provider: String
    let reason: String

    var description: String { "\(provider): \(reason)" }
}

extension IPProviderError: CustomStringConvertible {
    var description: String {
        switch self {
        case .rateLimited: return "rate limited"
        case .invalidResponse: return "invalid response"
        case .decodingFailed: return "decoding failed"
        case .allProvidersFailed(let failures):
            return "all providers failed [\(failures.map(\.description).joined(separator: ", "))]"
        }
    }
}
