import Domain
import Flight
import Formatting
import Foundation
import Observation
import SwiftUI
import Voice

/// The language of the app and of speech (F25): the device's language, or an explicit choice that overrides it.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, swedish

    var id: String {
        rawValue
    }

    /// nil = follow the device.
    var locale: Locale? {
        switch self {
        case .system: nil
        case .english: Locale(identifier: "en")
        case .swedish: Locale(identifier: "sv")
        }
    }
}

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
        static let lastClub = "settings.lastClubID"
        static let voice = "settings.voice"
        static let language = "settings.language"
        static let atmosphere = "settings.atmosphere"
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

    /// The club used last, so QuickShot can start from it. Display preference only.
    var lastClubID: UUID? {
        didSet { defaults.set(lastClubID?.uuidString, forKey: Key.lastClub) }
    }

    /// Spoken feedback choices (F07): on/off and which metrics are spoken.
    var voice: VoicePreferences {
        didSet { defaults.set(try? JSONEncoder().encode(voice), forKey: Key.voice) }
    }

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    /// Standard or manual air pressure and temperature (F18). Manual values are range-checked when resolved.
    var atmosphere: AtmosphereSetting {
        didSet { defaults.set(try? JSONEncoder().encode(atmosphere), forKey: Key.atmosphere) }
    }

    /// The language shown and spoken right now: the explicit choice, else the app's resolved language.
    var effectiveLocale: Locale {
        language.locale ?? Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// True once onboarding was finished or skipped. Repeating onboarding never touches credits or stored shots.
    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboarding) }
    }

    /// - Parameter resetting: UI tests start from defaults (test-only launch argument, see GolfLaunchrApp).
    init(defaults: UserDefaults = .standard, locale: Locale = .current, resetting: Bool = false) {
        self.defaults = defaults
        if resetting {
            [Key.distance, Key.speed, Key.appearance, Key.handedness, Key.onboarding, Key.lastClub, Key.voice, Key.language, Key.atmosphere]
                .forEach(defaults.removeObject(forKey:))
        }
        let regional = DisplayUnits.defaults(for: locale)
        units = DisplayUnits(
            distance: defaults.string(forKey: Key.distance).flatMap(DistanceUnit.init(rawValue:)) ?? regional.distance,
            speed: defaults.string(forKey: Key.speed).flatMap(SpeedUnit.init(rawValue:)) ?? regional.speed
        )
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        swingHandedness = defaults.string(forKey: Key.handedness).flatMap(SwingHandedness.init(rawValue:))
        onboardingCompleted = defaults.bool(forKey: Key.onboarding)
        lastClubID = defaults.string(forKey: Key.lastClub).flatMap(UUID.init(uuidString:))
        language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? .system
        atmosphere = defaults.data(forKey: Key.atmosphere)
            .flatMap { try? JSONDecoder().decode(AtmosphereSetting.self, from: $0) } ?? AtmosphereSetting()
        voice = defaults.data(forKey: Key.voice).flatMap { try? JSONDecoder().decode(VoicePreferences.self, from: $0) } ?? .default
    }
}
