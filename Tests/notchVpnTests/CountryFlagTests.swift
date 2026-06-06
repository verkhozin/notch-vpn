import XCTest
@testable import notchVpn

final class CountryFlagTests: XCTestCase {
    func test_flag_emoji_for_valid_iso_code() {
        XCTAssertEqual(Country(code: "DE", name: "Germany").flag, "🇩🇪")
        XCTAssertEqual(Country(code: "us", name: "United States").flag, "🇺🇸")
        XCTAssertEqual(Country(code: "JP", name: "Japan").flag, "🇯🇵")
    }

    func test_flag_emoji_invalid_code_returns_fallback() {
        XCTAssertEqual(Country(code: "XYZ", name: "x").flag, "🏳️")
        XCTAssertEqual(Country(code: "", name: "x").flag, "🏳️")
    }
}
