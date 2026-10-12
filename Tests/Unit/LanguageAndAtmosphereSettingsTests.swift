import Flight
import Foundation
@testable import GolfLaunchr
import Testing

@MainActor
struct LanguageAndAtmosphereSettingsTests {
    private func defaults() -> UserDefaults {
        guard let d = UserDefaults(suiteName: "settings-tests-\(UUID().uuidString)") else { preconditionFailure("suite") }
        return d
    }

    @Test func languageDefaultsToSystemAndPersistsAnExplicitChoice() {
        let d = defaults()
        let first = SettingsStore(defaults: d)
        #expect(first.language == .system && first.language.locale == nil)
        first.language = .swedish
        let second = SettingsStore(defaults: d)
        #expect(second.language == .swedish && second.language.locale?.language.languageCode?.identifier == "sv")
        #expect(second.effectiveLocale.identifier == "sv")
        #expect(SettingsStore(defaults: d, resetting: true).language == .system)
    }

    @Test func languageDoesNotTouchUnitsHandednessOrAtmosphere() {
        let s = SettingsStore(defaults: defaults())
        s.units.distance = .yards
        s.swingHandedness = .left
        s.atmosphere = AtmosphereSetting(mode: .manual, pressureHPa: 990, temperatureC: 7, enteredAt: Date())
        let before = (s.units, s.swingHandedness, s.atmosphere)
        s.language = .english
        s.language = .swedish
        #expect(s.units == before.0 && s.swingHandedness == before.1 && s.atmosphere == before.2)
    }

    @Test func atmosphereSettingPersistsAndStartsAsStandard() {
        let d = defaults()
        let first = SettingsStore(defaults: d)
        #expect(first.atmosphere == AtmosphereSetting())
        let manual = AtmosphereSetting(
            mode: .manual,
            pressureHPa: 845.5,
            temperatureC: 8.5,
            enteredAt: Date(timeIntervalSince1970: 1_791_716_400)
        )
        first.atmosphere = manual
        #expect(SettingsStore(defaults: d).atmosphere == manual)
        #expect(SettingsStore(defaults: d, resetting: true).atmosphere == AtmosphereSetting())
    }

    @Test func aCorruptStoredAtmosphereFallsBackToStandardNotToGarbage() {
        let d = defaults()
        d.set(Data("not json".utf8), forKey: "settings.atmosphere")
        #expect(SettingsStore(defaults: d).atmosphere == AtmosphereSetting())
    }

    @Test func handednessIsStillNilUntilChosenAndPersistsWhenChosen() {
        let d = defaults()
        #expect(SettingsStore(defaults: d).swingHandedness == nil)
        SettingsStore(defaults: d).swingHandedness = .left
        #expect(SettingsStore(defaults: d).swingHandedness == .left)
    }
}
