import Domain
import Foundation
@testable import Modes
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400)
private let sessionID = UUID()
private let seven = ClubSnapshot.test("7 iron")
private let driver = ClubSnapshot.test("Driver")

private extension ClubSnapshot {
    static func test(_ name: String) -> ClubSnapshot {
        guard let c = try? ClubSnapshot(id: UUID(), name: name, loftRad: nil) else { preconditionFailure("club") }
        return c
    }
}

private func shot(
    _ seq: Int, carry: Double?, lateral: Double? = nil, club: ClubSnapshot = seven, included: Bool = true,
    quality: MetricQuality = .provisional
) throws -> Shot {
    var m: [MetricKey: Domain.Measurement] = [:]
    if let carry {
        m[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: quality, uncertainty95: 2.5)
    } else {
        m[.carry] = Domain.Measurement.unavailable(.carry, failure: .occlusion)
    }
    if let lateral {
        m[.lateralLanding] = try Domain.Measurement(key: .lateralLanding, value: lateral, provenance: .estimated, quality: .provisional)
    }
    return try Shot(
        id: UUID(), sessionID: sessionID, sequence: seq, mode: .target, swingHandedness: .right, clubSnapshot: club,
        calibrationID: UUID(), impactTimeUTC: t0.addingTimeInterval(Double(seq)), metrics: m,
        environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
        versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), included: included, isSynthetic: true
    )
}

private func config(
    target: Double = 100, tol: Double = 5, lateral: Double? = nil, attempts: Int = 10, clubs: Set<UUID>? = nil
) throws -> TargetDrillConfig {
    try TargetDrillConfig(targetCarryM: target, longitudinalToleranceM: tol, lateralToleranceM: lateral, attempts: attempts, clubIDs: clubs)
}

struct TargetDrillTests {
    @Test func defaultsAreTheSpecDefaults() throws {
        let c = try TargetDrillConfig()
        #expect(c.targetCarryM == 100 && c.longitudinalToleranceM == 5 && c.attempts == 10 && c.lateralToleranceM == nil && c
            .clubIDs == nil)
    }

    // MARK: boundaries

    @Test(arguments: [95.0, 105.0, 100.0]) func anErrorExactlyEqualToTheToleranceIsAHit(carry: Double) throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: carry)], lateralValidated: false)
        #expect(r.attempts.first?.isHit == true)
    }

    @Test(arguments: [94.99, 105.01]) func justBeyondTheToleranceIsAMiss(carry: Double) throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: carry)], lateralValidated: false)
        #expect(r.attempts.first?.isHit == false)
    }

    @Test func unitConversionNoiseAtTheBoundaryStillCountsAsAHit() throws {
        let noisy = 100 + 5.0 + 1e-12 // 5 m in, e.g., yards and back
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: noisy)], lateralValidated: false)
        #expect(r.attempts.first?.isHit == true)
    }

    // MARK: signed errors

    @Test func shortIsNegativeAndLongIsPositive() throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: 92.5), shot(2, carry: 108)], lateralValidated: false)
        #expect(r.attempts[0].longitudinalErrorM == -7.5 && r.attempts[1].longitudinalErrorM == 8)
        #expect(r.shortCount == 1 && r.longCount == 1)
    }

    // MARK: invalid, excluded, other clubs

    @Test func aShotWithoutACarryDoesNotAdvanceTheAttempt() throws {
        let r = try TargetDrill.evaluate(
            config: config(attempts: 2), shots: [shot(1, carry: nil), shot(2, carry: 101), shot(3, carry: 98)], lateralValidated: false
        )
        #expect(r.scoredCount == 2 && r.unscoredShotCount == 1 && r.isComplete)
        #expect(r.attempts.map(\.number) == [1, 2])
    }

    @Test func invalidOrUnsupportedQualityIsNotScored() throws {
        let shots = try [shot(1, carry: 100, quality: .invalid), shot(2, carry: 100, quality: .unsupported), shot(3, carry: 100)]
        let r = try TargetDrill.evaluate(config: config(), shots: shots, lateralValidated: false)
        #expect(r.scoredCount == 1 && r.unscoredShotCount == 2)
    }

    @Test func anExcludedShotIsRemovedFromProgressScoringAndStreak() throws {
        var shots = try [shot(1, carry: 100), shot(2, carry: 130), shot(3, carry: 101)]
        let withMiss = try TargetDrill.evaluate(config: config(), shots: shots, lateralValidated: false)
        #expect(withMiss.misses == 1 && withMiss.currentStreak == 1 && withMiss.bestStreak == 1)
        shots[1] = try shot(2, carry: 130, included: false)
        let without = try TargetDrill.evaluate(config: config(), shots: shots, lateralValidated: false)
        #expect(without.scoredCount == 2 && without.misses == 0 && without.currentStreak == 2 && without.bestStreak == 2)
    }

    @Test func clubRestrictionCountsOnlyThoseClubs() throws {
        let r = try TargetDrill.evaluate(
            config: config(clubs: [seven.id]), shots: [shot(1, carry: 100, club: driver), shot(2, carry: 100)], lateralValidated: false
        )
        #expect(r.scoredCount == 1 && r.otherClubShotCount == 1)
    }

    // MARK: progress, streak, completion

    @Test func theDrillCompletesAtTheAttemptCountAndLaterShotsAreNotScored() throws {
        let shots = try (1 ... 5).map { try shot($0, carry: 100) }
        let r = try TargetDrill.evaluate(config: config(attempts: 3), shots: shots, lateralValidated: false)
        #expect(r.scoredCount == 3 && r.isComplete && r.extraShotCount == 2 && r.hits == 3)
    }

    @Test func streaksFollowTheOrderOfScoredAttempts() throws {
        let carries: [Double] = [100, 101, 130, 99, 120, 100, 100, 100]
        let shots = try carries.enumerated().map { try shot($0.offset + 1, carry: $0.element) }
        let r = try TargetDrill.evaluate(config: config(), shots: shots, lateralValidated: false)
        #expect(r.bestStreak == 3 && r.currentStreak == 3 && r.hits == 6 && r.misses == 2)
    }

    @Test func shotsAreScoredInSequenceOrderWhateverTheInputOrder() throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(2, carry: 130), shot(1, carry: 100)], lateralValidated: false)
        #expect(r.attempts.map(\.longitudinalErrorM) == [0, 30])
    }

    @Test func anEmptySessionIsAnEmptyResultNotAnError() throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [], lateralValidated: false)
        #expect(r.scoredCount == 0 && !r.isComplete && r.hitRate == nil && r.meanSignedErrorM == nil)
    }

    @Test func summaryNumbersAreExact() throws {
        let r = try TargetDrill.evaluate(
            config: config(), shots: [shot(1, carry: 96), shot(2, carry: 104), shot(3, carry: 110)], lateralValidated: false
        )
        #expect(r.hits == 2 && r.hitRate == 2.0 / 3.0)
        #expect(abs((r.meanSignedErrorM ?? 0) - 10.0 / 3.0) < 1e-9)
        #expect(abs((r.meanAbsoluteErrorM ?? 0) - 6.0) < 1e-9)
    }

    // MARK: lateral

    @Test func withoutValidatedLateralDataTheDrillIsDistanceOnly() throws {
        let r = try TargetDrill.evaluate(config: config(lateral: 3), shots: [shot(1, carry: 100, lateral: 20)], lateralValidated: false)
        #expect(r.attempts[0].basis == .distanceOnly && r.attempts[0].isHit && r.isDistanceOnly)
        #expect(r.attempts[0].lateralErrorM == nil, "an unvalidated lateral figure is not shown as an error")
    }

    @Test func withValidatedLateralDataAHitNeedsBothTolerances() throws {
        let cfg = try config(lateral: 3)
        let shots = try [
            shot(1, carry: 100, lateral: 2.9),
            shot(2, carry: 100, lateral: 3.0),
            shot(3, carry: 100, lateral: -3.1),
            shot(4, carry: 120, lateral: 0)
        ]
        let r = TargetDrill.evaluate(config: cfg, shots: shots, lateralValidated: true)
        #expect(r.attempts.map(\.isHit) == [true, true, false, false])
        #expect(r.attempts.allSatisfy { $0.basis == .distanceAndLateral } && !r.isDistanceOnly)
        #expect(r.leftCount == 1 && r.rightCount == 2, "right is positive, left negative, zero is neither")
    }

    @Test func aShotMissingItsLateralFigureIsScoredOnDistanceAndLabelledSo() throws {
        let r = try TargetDrill.evaluate(
            config: config(lateral: 3), shots: [shot(1, carry: 100, lateral: 1), shot(2, carry: 100)], lateralValidated: true
        )
        #expect(r.attempts[1].basis == .distanceOnly && r.isDistanceOnly)
    }

    @Test func noLateralToleranceMeansDistanceOnlyEvenWithValidatedData() throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: 100, lateral: 50)], lateralValidated: true)
        #expect(r.attempts[0].basis == .distanceOnly && r.attempts[0].isHit)
    }

    @Test func theResultOnlyUncertaintyIsCarriedSeparatelyFromTheTolerance() throws {
        let r = try TargetDrill.evaluate(config: config(), shots: [shot(1, carry: 104)], lateralValidated: false)
        #expect(r.attempts[0].carryUncertainty95M == 2.5)
        #expect(r.attempts[0].isHit, "uncertainty never widens or narrows the tolerance")
    }

    @Test func shortAndLongCountOnlyMissesBeyondTheTolerance() throws {
        // 97 is short but inside the tolerance: a hit, not a short miss. 90 and 110 are misses on each side.
        let shots = try [shot(1, carry: 97), shot(2, carry: 90), shot(3, carry: 110), shot(4, carry: 103), shot(5, carry: 105)]
        let r = try TargetDrill.evaluate(config: config(), shots: shots, lateralValidated: false)
        #expect(r.hits == 3 && r.shortCount == 1 && r.longCount == 1)
    }
}
