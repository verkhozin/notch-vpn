import XCTest
@testable import notchVpn

final class IPLookupServiceTests: XCTestCase {
    func test_returns_first_successful_provider() async throws {
        let primary = StubProvider(name: "primary", result: .failure(IPProviderError.rateLimited))
        let backup = StubProvider(
            name: "backup",
            result: .success(IPInfo(
                ip: "1.2.3.4",
                country: Country(code: "DE", name: "Germany"),
                provider: "backup",
                timestamp: Date()
            ))
        )
        let service = IPLookupService(providers: [primary, backup])

        let info = try await service.currentIP()

        XCTAssertEqual(info.country.code, "DE")
        XCTAssertEqual(info.provider, "backup")
    }

    func test_throws_when_all_providers_fail() async {
        let providers: [any IPProvider] = [
            StubProvider(name: "a", result: .failure(IPProviderError.rateLimited)),
            StubProvider(name: "b", result: .failure(IPProviderError.invalidResponse)),
        ]
        let service = IPLookupService(providers: providers)

        do {
            _ = try await service.currentIP()
            XCTFail("expected throw")
        } catch {
            XCTAssertTrue(error is IPProviderError)
        }
    }
}

private struct StubProvider: IPProvider {
    let name: String
    let result: Result<IPInfo, IPProviderError>

    func fetch() async throws -> IPInfo {
        try result.get()
    }
}
