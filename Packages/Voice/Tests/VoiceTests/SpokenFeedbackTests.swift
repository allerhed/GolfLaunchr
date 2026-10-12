import Domain
import Formatting
import Foundation
import Testing
@testable import Voice

private func shot(
    carry: Double? = 130.4,
    speed: Double? = 45,
    launch: Double? = 0.2182,
    carryProvenance: Provenance = .estimated
) throws -> Shot {
    var m: [MetricKey: Domain.Measurement] = [:]
    if let carry {
        m[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: carryProvenance, quality: .provisional)
    }
    if let speed {
        m[.ballSpeed] = try Domain.Measurement(key: .ballSpeed, value: speed, provenance: .measured, quality: .valid)
    }
    if let launch {
        m[.verticalLaunch] = try Domain.Measurement(key: .verticalLaunch, value: launch, provenance: .measured, quality: .valid)
    }
    return try Shot(
        id: UUID(), sessionID: UUID(), sequence: 1, mode: .practice, swingHandedness: .right,
        clubSnapshot: ClubSnapshot(id: UUID(), name: "7 iron", loftRad: nil), calibrationID: UUID(), impactTimeUTC: Date(), metrics: m,
        environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
        versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t")
    )
}

private func feedback(
    _ lang: String,
    _ units: DisplayUnits = DisplayUnits(distance: .metres, speed: .kilometresPerHour)
) -> SpokenFeedback {
    SpokenFeedback(units: units, locale: Locale(identifier: lang))
}

struct SpokenFeedbackTests {
    let all = VoicePreferences(enabled: true, metrics: [.carry, .ballSpeed, .verticalLaunch])

    @Test func speaksSelectedMetricsInAStableOrderWithUnitsAndQualification() throws {
        let text = try #require(feedback("en").result(for: shot(), preferences: all))
        #expect(text == "Estimated carry: 130 metres. Ball speed: 162.0 kilometres per hour. Vertical launch angle: 12.5 degrees.")
    }

    @Test func orderIsStableWhateverOrderTheSetWasBuiltIn() throws {
        let reversed = VoicePreferences(enabled: true, metrics: [.verticalLaunch, .ballSpeed, .carry])
        #expect(try feedback("en").result(for: shot(), preferences: reversed) == feedback("en").result(for: shot(), preferences: all))
    }

    @Test func swedishUsesSwedishWordsAndDecimalComma() throws {
        let text = try #require(feedback("sv").result(for: shot(), preferences: all))
        #expect(text == "Beräknad flyglängd: 130 meter. Bollhastighet: 162,0 kilometer i timmen. Vertikal utgångsvinkel: 12,5 grader.")
    }

    @Test func unitsFollowTheSettingAndNeverChangeTheStoredValue() throws {
        let yards = feedback("en", DisplayUnits(distance: .yards, speed: .milesPerHour))
        let text = try #require(yards.result(
            for: shot(carry: 130.4, speed: 45),
            preferences: VoicePreferences(enabled: true, metrics: [.carry, .ballSpeed])
        ))
        #expect(text == "Estimated carry: 143 yards. Ball speed: 100.7 miles per hour.")
    }

    /// Missing is spoken as unavailable, never as zero.
    @Test func unavailableIsSaidNotZero() throws {
        let text = try #require(feedback("en").result(for: shot(carry: nil, speed: nil), preferences: all))
        #expect(text.contains("Carry unavailable") && text.contains("Ball speed unavailable") && !text.contains(" 0 "))
        let sv = try #require(feedback("sv").result(for: shot(carry: nil), preferences: VoicePreferences(enabled: true, metrics: [.carry])))
        #expect(sv == "Flyglängd inte tillgänglig.")
    }

    @Test func measuredHasNoQualifierDerivedAndEstimatedDo() throws {
        let prefs = VoicePreferences(enabled: true, metrics: [.carry])
        #expect(try feedback("en").result(for: shot(carryProvenance: .measured), preferences: prefs) == "Carry: 130 metres.")
        #expect(try feedback("en").result(for: shot(carryProvenance: .derived), preferences: prefs) == "Derived carry: 130 metres.")
    }

    @Test func singularUnitsAreUsedForOne() throws {
        let one = try shot(carry: 1.2)
        #expect(try feedback("en")
            .result(for: one, preferences: VoicePreferences(enabled: true, metrics: [.carry])) == "Estimated carry: 1 metre.")
        #expect(try feedback("sv")
            .result(for: one, preferences: VoicePreferences(enabled: true, metrics: [.carry])) == "Beräknad flyglängd: 1 meter.")
    }

    @Test func silentOrEmptyPreferencesSpeakNothing() throws {
        #expect(try feedback("en").result(for: shot(), preferences: VoicePreferences(enabled: false, metrics: [.carry])) == nil)
        #expect(try feedback("en").result(for: shot(), preferences: VoicePreferences(enabled: true, metrics: [])) == nil)
    }

    @Test func promptsAndPreviewExistInBothLanguages() {
        for lang in ["en", "sv"] {
            for prompt in SpokenPrompt.allCases {
                #expect(!feedback(lang).prompt(prompt).isEmpty)
            }
        }
        #expect(feedback("en").prompt(.ready) != feedback("sv").prompt(.ready))
        #expect(feedback("en").preview(preferences: all).contains("Estimated carry"))
    }

    @Test func preferencesRoundTripAndKeepAStableOrder() throws {
        let prefs = VoicePreferences(enabled: false, metrics: [.verticalLaunch, .carry])
        let data = try JSONEncoder().encode(prefs)
        #expect(try JSONDecoder().decode(VoicePreferences.self, from: data) == prefs)
        #expect(prefs.orderedMetrics == [.carry, .verticalLaunch])
        #expect(VoicePreferences.default.metrics == [.carry, .ballSpeed])
    }
}
