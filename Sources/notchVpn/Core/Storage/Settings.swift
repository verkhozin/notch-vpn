import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Keys {
        static let lastCountry = "lastKnownCountryCode"
        static let homeCountryCode = "homeCountryCode"
        static let homeCountryName = "homeCountryName"
        static let onboardingDone = "hasCompletedOnboarding"
        static let pollMinSec = "pollMinSeconds"
        static let pollMaxSec = "pollMaxSeconds"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastKnownCountryCode: String? {
        get { defaults.string(forKey: Keys.lastCountry) }
        set { defaults.set(newValue, forKey: Keys.lastCountry) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.onboardingDone) }
        set { defaults.set(newValue, forKey: Keys.onboardingDone) }
    }

    var homeCountry: Country? {
        get {
            guard let code = defaults.string(forKey: Keys.homeCountryCode),
                  let name = defaults.string(forKey: Keys.homeCountryName)
            else { return nil }
            return Country(code: code, name: name)
        }
        set {
            defaults.set(newValue?.code, forKey: Keys.homeCountryCode)
            defaults.set(newValue?.name, forKey: Keys.homeCountryName)
        }
    }
}
