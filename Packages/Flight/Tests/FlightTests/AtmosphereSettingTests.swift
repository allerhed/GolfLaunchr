import Domain
@testable import Flight
import Foundation
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400)

struct AtmosphereSettingTests {
    func manual(_ hPa: Double?, _ c: Double?, at: Date? = t0) -> AtmosphereSetting {
        AtmosphereSetting(mode: .manual, pressureHPa: hPa, temperatureC: c, enteredAt: at)
    }

    @Test func standardIsTheDefaultAndMatchesTheDeclaredAtmosphere() throws {
        let setting = AtmosphereSetting()
        guard case let .standard(env) = setting.resolve(now: t0) else { Issue.record("expected standard"); return }
        #expect(try env == (Atmosphere.standard()) && env.source == .standard)
    }

    @Test func manualValuesConvertToSIAndKeepTheirSource() {
        guard case let .manual(env, stale) = manual(1013.25, 15).resolve(now: t0) else { Issue.record("expected manual"); return }
        #expect(abs(env.pressurePa - 101_325) < 1e-9 && abs(env.temperatureK - 288.15) < 1e-9)
        #expect(env.source == .manual && !stale)
    }

    /// Manual mode never falls back silently to the standard atmosphere: an invalid entry is reported.
    @Test func invalidManualIsReportedNeverReplacedByStandard() {
        #expect(manual(nil, 15).resolve(now: t0) == .invalid([.missingPressure]))
        #expect(manual(1000, nil).resolve(now: t0) == .invalid([.missingTemperature]))
        #expect(manual(nil, nil).resolve(now: t0) == .invalid([.missingPressure, .missingTemperature]))
        #expect(manual(299.9, 15).resolve(now: t0) == .invalid([.pressureOutOfRange]))
        #expect(manual(1100.1, 15).resolve(now: t0) == .invalid([.pressureOutOfRange]))
        #expect(manual(1000, -30.1).resolve(now: t0) == .invalid([.temperatureOutOfRange]))
        #expect(manual(1000, 50.1).resolve(now: t0) == .invalid([.temperatureOutOfRange]))
        #expect(manual(.nan, 15).resolve(now: t0) == .invalid([.pressureOutOfRange]))
        #expect(manual(1000, .infinity).resolve(now: t0) == .invalid([.temperatureOutOfRange]))
    }

    @Test func rangeBoundariesAreInclusive() {
        for (p, c) in [(300.0, -30.0), (1100, 50), (1013.25, 0)] {
            if case .manual = manual(p, c).resolve(now: t0) {} else {
                Issue.record("\(p) hPa \(c) C should be accepted")
            }
        }
    }

    @Test func ambientValuesAreFlaggedStaleAfterTwelveHours() {
        let setting = manual(1000, 10)
        for (offset, stale) in [(0.0, false), (11.9 * 3600, false), (12 * 3600 + 1, true), (48 * 3600, true)] {
            guard case let .manual(_, flagged) = setting.resolve(now: t0.addingTimeInterval(offset)) else { Issue.record("manual"); return }
            #expect(flagged == stale)
        }
        // A manual value without a timestamp cannot be shown as fresh.
        guard case let .manual(_, flagged) = manual(1000, 10, at: nil).resolve(now: t0) else { Issue.record("manual"); return }
        #expect(flagged)
    }

    @Test func standardNeverGoesStale() {
        #expect(AtmosphereSetting().resolve(now: t0.addingTimeInterval(1e9)) == AtmosphereSetting().resolve(now: t0))
    }

    @Test func codableRoundTripKeepsEverything() throws {
        let setting = manual(987.6, 8.5)
        #expect(try JSONDecoder().decode(AtmosphereSetting.self, from: JSONEncoder().encode(setting)) == setting)
    }

    @Test func aManualAtmosphereChangesTheFlightConsistently() throws {
        guard case let .manual(env, _) = manual(845, 8.5).resolve(now: t0) else { Issue.record("manual"); return }
        let inputs = try LaunchInputs(ballSpeedMps: 50, verticalLaunchRad: 0.314, backspinRadPerSec: 680)
        let high = try FlightModel.compute(inputs, environment: env)
        let sea = try FlightModel.compute(inputs, environment: Atmosphere.standard())
        #expect(high.carryM > sea.carryM && high.environment == env) // thinner air, longer flight, snapshot kept
    }
}
