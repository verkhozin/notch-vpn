import Foundation

enum NotchEvent: Sendable, Equatable {
    case launch
    case drop(previous: Country?)
    case restore(CountryChangeEvent)
}
