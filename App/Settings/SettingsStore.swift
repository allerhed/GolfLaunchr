import Domain
import Formatting
import Foundation
import Observation
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String {
        rawValue
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}

/// Display preferences (units, theme). Interim store: the full `UserSettings` entity arrives with persistence (item 2.1).
/// Only display changes; stored SI data, scores and credits are never touched by these settings.
@MainActor @Observable
final class SettingsStore {
    private enum Key {
        static let distance = "settings.distanceUnit"
        static let speed = "settings.speedUnit"
        static let appearance = "settings.appearance"
        static let handedness = "settings.swingHandedness"
        static let onboarding = "settings.onboardingCompleted"
    }

    private let defaults: UserDefaults

    var units: DisplayUnits {
        didSet {
            defaults.set(units.distance.rawValue, forKey: Key.distance)
            defaults.set(units.speed.rawValue, forKey: Key.speed)
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The golfer's swing, chosen explicitly in onboarding. nil until chosen: it is never inferred (F01).
    var swingHandedness: SwingHandedness? {
        didSet { defaults.set(swingHandedness?.rawValue, forKey: Key.handedness) }
    }

    /// True once onboarding was finished or skipped. Repeating onboarding never touches credits or stored shots.
    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboarding) }
    }

    /// - Parameter resetting: UI tests start from defaults (test-only launch argument, see GolfLaunchrApp).
    init(defaults: UserDefaults = .standard, locale: Locale = .current, resetting: Bool = false) {
        self.defaults = defaults
        if resetting {
            [Key.distance, Key.speed, Key.appearance, Key.handedness, Key.onboarding].forEach(defaults.removeObject(forKey:))
        }
        let regional = DisplayUnits.defaults(for: locale)
        units = DisplayUnits(
            distance: defaults.string(forKey: Key.distance).flatMap(DistanceUnit.init(rawValue:)) ?? regional.distance,
            speed: defaults.string(forKey: Key.speed).flatMap(SpeedUnit.init(rawValue:)) ?? regional.speed
        )
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        swingHandedness = defaults.string(forKey: Key.handedness).flatMap(SwingHandedness.init(rawValue:))
        onboardingCompleted = defaults.bool(forKey: Key.onboarding)
    }
}
