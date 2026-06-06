import Foundation

struct IpApiCoProvider: IPProvider {
    let name = "ipapi.co"
    private let fetcher: IPHTTPFetcher

    init(session: URLSession = .shared) {
        self.fetcher = IPHTTPFetcher(session: session)
    }

    private struct Response: Decodable {
        let ip: String
        let country_code: String
        let country_name: String
    }

    func fetch() async throws -> IPInfo {
        guard let url = URL(string: "https://ipapi.co/json/") else {
            throw IPProviderError.invalidResponse
        }
        let parsed = try await fetcher.fetch(Response.self, from: url)
        return IPInfo(
            ip: parsed.ip,
            country: Country(code: parsed.country_code, name: parsed.country_name),
            provider: name,
            timestamp: Date()
        )
    }
}
