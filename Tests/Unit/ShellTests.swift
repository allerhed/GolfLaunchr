import Formatting
import Foundation
@testable import GolfLaunchr
import Testing

struct DesignTokenTests {
    /// WCAG AA for text: 4.5:1 in both schemes.
    @Test func textPairsMeetAAInLightAndDark() {
        for pair in Tokens.textPairs {
            for isDark in [false, true] {
                let ratio = Contrast.ratio(pair.foreground.hex(dark: isDark), pair.background.hex(dark: isDark))
                #expect(ratio >= 4.5, "\(pair.name) \(isDark ? "dark" : "light") = \(ratio)")
            }
        }
    }

    @Test func contrastMathMatchesKnownValues() {
        #expect(abs(Contrast.ratio(0x000000, 0xFFFFFF) - 21) < 1e-9)
        #expect(abs(Contrast.ratio(0x777777, 0x777777) - 1) < 1e-9)
    }

    @Test func touchTargetIsAtLeast44() {
        #expect(Spacing.minTarget >= 44)
    }
}

@MainActor
struct SettingsStoreTests {
    func freshDefaults() throws -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsFollowRegionNotLanguage() throws {
        let us = try SettingsStore(defaults: freshDefaults(), locale: Locale(identifier: "en_US"))
        #expect(us.units == DisplayUnits(distance: .yards, speed: .milesPerHour))
        let se = try SettingsStore(defaults: freshDefaults(), locale: Locale(identifier: "sv_SE"))
        #expect(se.units == DisplayUnits(distance: .metres, speed: .kilometresPerHour))
        #expect(se.appearance == .system)
    }

    @Test func choicesPersistAcrossRelaunch() throws {
        let defaults = try freshDefaults()
        let first = SettingsStore(defaults: defaults, locale: Locale(identifier: "sv_SE"))
        first.units.distance = .yards
        first.units.speed = .milesPerHour
        first.appearance = .dark
        let second = SettingsStore(defaults: defaults, locale: Locale(identifier: "sv_SE"))
        #expect(second.units == DisplayUnits(distance: .yards, speed: .milesPerHour))
        #expect(second.appearance == .dark)
    }

    @Test func resetRestoresDefaults() throws {
        let defaults = try freshDefaults()
        let first = SettingsStore(defaults: defaults, locale: Locale(identifier: "sv_SE"))
        first.units.distance = .yards
        let reset = SettingsStore(defaults: defaults, locale: Locale(identifier: "sv_SE"), resetting: true)
        #expect(reset.units.distance == .metres)
    }

    @Test func corruptStoredValuesFallBackToDefaults() throws {
        let defaults = try freshDefaults()
        defaults.set("furlongs", forKey: "settings.distanceUnit")
        defaults.set("neon", forKey: "settings.appearance")
        let store = SettingsStore(defaults: defaults, locale: Locale(identifier: "sv_SE"))
        #expect(store.units.distance == .metres)
        #expect(store.appearance == .system)
    }
}

@MainActor
struct NavigationTests {
    @Test func selectionLivesInTheModelSoRotationKeepsIt() {
        let nav = AppNavigation()
        #expect(nav.selection == .home)
        nav.selection = .progress
        #expect(nav.selection == .progress)
        #expect(AppTab.allCases.count == 3) // Home, Bag, Progress; Settings is a gear, not a tab
    }
}
