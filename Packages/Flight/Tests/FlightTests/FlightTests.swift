import Domain
@testable import Flight
import Foundation
import Testing

private func deg(_ d: Double) -> Double {
    d * .pi / 180
}

private func rpm(_ r: Double) -> Double {
    r * 2 * .pi / 60
}

private func fly(_ v: Double, _ vert: Double, _ horiz: Double = 0, spin: Double? = nil, env: Environment? = nil) throws -> FlightResult {
    let inputs = try LaunchInputs(
        ballSpeedMps: v,
        verticalLaunchRad: deg(vert),
        horizontalLaunchRad: deg(horiz),
        backspinRadPerSec: spin.map(rpm)
    )
    return try FlightModel.compute(inputs, environment: env ?? Atmosphere.standard())
}

struct AtmosphereTests {
    @Test func standardDensityIs1p225() throws {
        #expect(try abs(Atmosphere.density(Atmosphere.standard()) - 1.2250) < 0.0005)
    }

    @Test func densityFallsWithPressureAndTemperatureRise() throws {
        let sea = try Environment(pressurePa: 101_325, temperatureK: 288.15, source: .manual)
        let high = try Environment(pressurePa: 84500, temperatureK: 288.15, source: .manual)
        let hot = try Environment(pressurePa: 101_325, temperatureK: 308.15, source: .manual)
        #expect(Atmosphere.density(high) < Atmosphere.density(sea) && Atmosphere.density(hot) < Atmosphere.density(sea))
        #expect(abs(Atmosphere.density(high) / Atmosphere.density(sea) - 84500.0 / 101_325) < 1e-12)
    }
}

struct FlightModelTests {
    /// With (almost) no air and no spin the flight is a vacuum parabola: range = v^2 sin(2a) / g, apex = (v sin a)^2 / 2g.
    @Test func vacuumLimitMatchesTheAnalyticParabola() throws {
        let vacuum = try Environment(pressurePa: 1e-9, temperatureK: 288.15, source: .manual)
        let r = try fly(50, 20, env: vacuum)
        let g = FlightModel.gravity
        #expect(abs(r.carryM - 50 * 50 * sin(deg(40)) / g) < 0.01)
        #expect(abs(r.apexM - pow(50 * sin(deg(20)), 2) / (2 * g)) < 0.01)
        #expect(abs(r.flightTimeS - 2 * 50 * sin(deg(20)) / g) < 1e-3)
        #expect(abs(r.landingAngleRad - deg(20)) < 1e-3)
    }

    /// Values from an independent Python implementation of the same equations (own RK4, 0.2 ms step).
    struct Reference: CustomTestStringConvertible {
        let speed: Double, vertical: Double, horizontal: Double
        let spin: Double?
        let carry: Double, apex: Double, time: Double, lateral: Double
        var testDescription: String {
            "v=\(speed) vert=\(vertical) horiz=\(horizontal) spin=\(String(describing: spin))"
        }
    }

    @Test(arguments: [
        Reference(speed: 70, vertical: 11, horizontal: 0, spin: 2700, carry: 218.691096, apex: 23.735396, time: 5.950287, lateral: 0),
        Reference(speed: 50, vertical: 18, horizontal: 0, spin: 6500, carry: 167.497511, apex: 26.100135, time: 6.00229, lateral: 0),
        Reference(speed: 50, vertical: 18, horizontal: 0, spin: nil, carry: 103.761616, apex: 9.949541, time: 2.839662, lateral: 0),
        Reference(speed: 60, vertical: 14, horizontal: 3, spin: 4000, carry: 196.883944, apex: 25.345067, time: 6.079478, lateral: 10.31825)
    ])
    func matchesTheIndependentReference(_ c: Reference) throws {
        let r = try fly(c.speed, c.vertical, c.horizontal, spin: c.spin)
        #expect(abs(r.carryM - c.carry) < 0.02 && abs(r.apexM - c.apex) < 0.02)
        #expect(abs(r.flightTimeS - c.time) < 0.005 && abs(r.lateralLandingM - c.lateral) < 0.02)
    }

    @Test func lowerPressureCarriesFurtherAndRecalculatesConsistently() throws {
        let alt = try Environment(pressurePa: 84500, temperatureK: 281.65, source: .manual)
        let r = try fly(50, 18, spin: 6500, env: alt)
        #expect(abs(r.carryM - 174.109957) < 0.02) // independent reference
        let std = try fly(50, 18, spin: 6500)
        #expect(r.carryM > std.carryM && r.environment == alt && std.environment.source == .standard)
        #expect(r.airDensity < std.airDensity)
    }

    @Test func rightAimGoesRightLeftGoesLeftAndSymmetrically() throws {
        let right = try fly(60, 14, 3, spin: 4000), left = try fly(60, 14, -3, spin: 4000)
        #expect(right.lateralLandingM > 0 && left.lateralLandingM < 0)
        #expect(abs(right.lateralLandingM + left.lateralLandingM) < 1e-9 && abs(right.carryM - left.carryM) < 1e-9)
    }

    @Test func noSpinAxisCurvatureAndStraightWhenAimedStraight() throws {
        let r = try fly(60, 14, 0, spin: 4000)
        #expect(r.lateralLandingM == 0 && r.assumptions.contains(.noSpinAxisCurvature)) // does not invent a hook or slice
    }

    @Test func unknownSpinIsALowerBoundAndNeverStoredAsCarry() throws {
        let r = try fly(50, 18)
        #expect(r.isLowerBound && r.assumptions.contains(.spinUnknownNoLift))
        let m = try r.measurements()
        #expect(m[.carry]?.provenance == .unavailable && m[.carry]?.value == nil) // never a fake or zero carry
        #expect(m[.apex]?.provenance == .estimated)
    }

    @Test func knownSpinProducesEstimatedMetricsNeverMeasured() throws {
        let m = try fly(50, 18, spin: 6500).measurements()
        #expect(m[.carry]?.provenance == .estimated && m[.carry]?.quality == .provisional && m[.carry]?.value != nil)
        #expect(m[.totalDistance]?.provenance == .unavailable) // no validated runout model
        #expect(m.values.allSatisfy { $0.provenance != .measured && $0.provenance != .derived })
    }

    @Test func moreSpinFliesHigherAndMoreLiftMeansLongerUpToTheModelLimit() throws {
        let low = try fly(50, 18, spin: 2000), high = try fly(50, 18, spin: 6500), none = try fly(50, 18)
        #expect(high.apexM > low.apexM && low.apexM > none.apexM && high.carryM > none.carryM)
    }

    @Test func plausibleRangesForTypicalClubs() throws {
        let driver = try fly(70, 11, spin: 2700), iron7 = try fly(50, 18, spin: 6500)
        #expect((180 ... 260).contains(driver.carryM) && (120 ... 190).contains(iron7.carryM) && driver.carryM > iron7.carryM)
        #expect((15 ... 40).contains(iron7.apexM) && (3 ... 9).contains(iron7.flightTimeS))
    }

    @Test func deterministicAndVersioned() throws {
        let a = try fly(55, 16, 1, spin: 5000), b = try fly(55, 16, 1, spin: 5000)
        #expect(a == b && a.modelVersion == "flight-0.1-unvalidated")
    }

    @Test func invalidInputsAreRejectedNotComputed() {
        #expect(throws: FlightError.invalidInput("ballSpeed")) { try LaunchInputs(ballSpeedMps: 0, verticalLaunchRad: 0.2) }
        #expect(throws: FlightError.invalidInput("ballSpeed")) { try LaunchInputs(ballSpeedMps: .nan, verticalLaunchRad: 0.2) }
        #expect(throws: FlightError.invalidInput("verticalLaunch")) { try LaunchInputs(ballSpeedMps: 50, verticalLaunchRad: -0.1) }
        #expect(throws: FlightError.invalidInput("verticalLaunch")) { try LaunchInputs(ballSpeedMps: 50, verticalLaunchRad: 1.6) }
        #expect(throws: FlightError.invalidInput("backspin")) { try LaunchInputs(
            ballSpeedMps: 50,
            verticalLaunchRad: 0.3,
            backspinRadPerSec: -1
        ) }
        #expect(throws: FlightError.invalidInput("horizontalLaunch")) { try LaunchInputs(
            ballSpeedMps: 50,
            verticalLaunchRad: 0.3,
            horizontalLaunchRad: 2
        ) }
    }
}
