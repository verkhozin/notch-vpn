import Foundation

actor IPLookupService {
    private let providers: [any IPProvider]

    init(providers: [any IPProvider]) {
        precondition(!providers.isEmpty, "IPLookupService requires at least one provider")
        self.providers = providers
    }

    func currentIP() async throws -> IPInfo {
        var failures: [ProviderFailure] = []
        for provider in providers {
            do {
                return try await provider.fetch()
            } catch {
                failures.append(ProviderFailure(
                    provider: provider.name,
                    reason: String(describing: error)
                ))
            }
        }
        throw IPProviderError.allProvidersFailed(failures)
    }
}
