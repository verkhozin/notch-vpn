import Foundation

struct IpWhoIsProvider: IPProvider {
    let name = "ipwho.is"
    private let fetcher: IPHTTPFetcher

    init(session: URLSession = .shared) {
        self.fetcher = IPHTTPFetcher(session: session)
    }

    private struct Response: Decodable {
        let ip: String
        let country: String
        let country_code: String
        let success: Bool?
    }

    func fetch() async throws -> IPInfo {
        guard let url = URL(string: "https://ipwho.is/") else {
            throw IPProviderError.invalidResponse
        }
        let parsed = try await fetcher.fetch(Response.self, from: url)
        if parsed.success == false {
            throw IPProviderError.rateLimited
        }
        return IPInfo(
            ip: parsed.ip,
            country: Country(code: parsed.country_code, name: parsed.country),
            provider: name,
            timestamp: Date()
        )
    }
}
