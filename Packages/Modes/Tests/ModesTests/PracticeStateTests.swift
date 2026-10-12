import Domain
import Foundation
@testable import Modes
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400)

private func club(_ name: String) -> ClubSnapshot {
    guard let c = try? ClubSnapshot(id: UUID(), name: name, loftRad: nil) else { preconditionFailure("club") }
    return c
}

private func shot(_ state: PracticeState, club: ClubSnapshot, carry: Double? = 130) throws -> Shot {
    var m: [MetricKey: Domain.Measurement] = [:]
    if let carry {
        m[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional)
    }
    return try Shot(
        id: UUID(), sessionID: state.sessionID, sequence: state.shots.count + 1, mode: .practice, swingHandedness: .right,
        clubSnapshot: club, calibrationID: UUID(), impactTimeUTC: t0, metrics: m,
        environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
        versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t")
    )
}

struct PracticeStateTests {
    let seven = club("7 iron"), driver = club("Driver")

    func state(_ mode: PracticeMode = .standard, club: ClubSnapshot? = nil) -> PracticeState {
        PracticeState(sessionID: UUID(), mode: mode, selectedClub: club ?? seven)
    }

    @Test func armingNeedsAnActiveSessionAClubAndASafeSetup() {
        var s = state()
        #expect(s.arm(setupReady: false) == .blocked(.setupNotReady) && !s.isArmed) // measurement safeguards are never skipped
        var noClub = PracticeState(sessionID: UUID(), mode: .standard, selectedClub: nil)
        #expect(noClub.arm(setupReady: true) == .blocked(.noClub))
        #expect(s.arm(setupReady: true) == .armed && s.isArmed && s.armedClub == seven)
        s.pause()
        #expect(!s.isArmed && s.arm(setupReady: true) == .blocked(.notActive)) // pausing disarms; no arming while paused
    }

    /// F05: a club change is applied only to the next armed shot.
    @Test func aClubChangeWhileArmedAppliesToTheNextShotOnly() throws {
        var s = state()
        _ = s.arm(setupReady: true)
        s.selectClub(driver)
        #expect(s.armedClub == seven && s.selectedClub == driver)
        let first = try shot(s, club: seven)
        #expect(s.accept(first) == .accepted && !s.isArmed)
        _ = s.arm(setupReady: true)
        #expect(s.armedClub == driver)
        // A shot carrying a different club than the armed one is refused.
        #expect(try s.accept(shot(s, club: seven)) == .rejected(.clubMismatch))
        #expect(try s.accept(shot(s, club: driver)) == .accepted && s.shots.map(\.clubSnapshot.name) == ["7 iron", "Driver"])
    }

    @Test func shotsAreOnlyAcceptedWhileArmedAndInOrder() throws {
        var s = state()
        #expect(try s.accept(shot(s, club: seven)) == .rejected(.notArmed))
        _ = s.arm(setupReady: true)
        let wrongSession = try Shot(
            id: UUID(), sessionID: UUID(), sequence: 1, mode: .practice, swingHandedness: .right, clubSnapshot: seven,
            calibrationID: UUID(), impactTimeUTC: t0, metrics: [:], environment: Environment(
                pressurePa: 1,
                temperatureK: 1,
                source: .standard
            ),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t")
        )
        #expect(s.accept(wrongSession) == .rejected(.wrongSession))
        #expect(try s.accept(shot(s, club: seven)) == .accepted)
        #expect(s.isArmed == false) // one armed shot accepts exactly one result
        _ = s.arm(setupReady: true)
        let skipped = try Shot(
            id: UUID(), sessionID: s.sessionID, sequence: 5, mode: .practice, swingHandedness: .right, clubSnapshot: seven,
            calibrationID: UUID(), impactTimeUTC: t0, metrics: [:], environment: Environment(
                pressurePa: 1,
                temperatureK: 1,
                source: .standard
            ),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t")
        )
        #expect(s.accept(skipped) == .rejected(.badSequence))
    }

    @Test func endingTwiceIsASingleEndAndAnEndedSessionIsFrozen() throws {
        var s = state()
        _ = s.arm(setupReady: true)
        _ = try s.accept(shot(s, club: seven))
        #expect(s.end() == .ended(shotCount: 1))
        #expect(s.end() == .alreadyEnded) // double tap cannot end (and so save) twice
        #expect(s.status == .ended && s.arm(setupReady: true) == .blocked(.notActive))
        s.resume()
        #expect(s.status == .ended)
    }

    @Test func endingWithNoShotsReportsZeroSoNothingMisleadingIsSaved() {
        var s = state()
        #expect(s.end() == .ended(shotCount: 0))
    }

    @Test func pauseAndResumeAreExplicit() {
        var s = state()
        s.pause(); #expect(s.status == .paused)
        s.resume(); #expect(s.status == .active)
        s.resume(); #expect(s.status == .active)
    }

    /// Target changes never rewrite the target a previous shot was taken against.
    @Test func eachShotKeepsTheTargetItWasArmedWith() throws {
        var s = state()
        s.setTargetCarry(150)
        _ = s.arm(setupReady: true)
        s.setTargetCarry(170) // changed after arming
        _ = try s.accept(shot(s, club: seven))
        _ = s.arm(setupReady: true)
        _ = try s.accept(shot(s, club: seven))
        #expect(s.targetSnapshots == [150, 170]) // the first shot still says 150
        s.setTargetCarry(nil)
        #expect(s.targetSnapshots == [150, 170])
    }

    @Test func shotGoalIsReportedNotEnforced() throws {
        var s = state()
        s.shotGoal = 2
        for _ in 0 ..< 3 {
            _ = s.arm(setupReady: true); _ = try s.accept(shot(s, club: seven))
        }
        #expect(s.goalReached && s.shots.count == 3)
    }
}
