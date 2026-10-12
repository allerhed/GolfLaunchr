import Domain
import Foundation
@testable import Modes
import Persistence
import PersistenceTestSupport
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400)

private struct Rig {
    let store: InMemoryStore
    let lifecycle: SessionLifecycle
    let calibration: CalibrationRecord

    static func make() async throws -> Rig {
        let store = InMemoryStore(allowsSynthetic: true)
        let calibration = try CalibrationRecord(
            deviceProfileID: "x", format: CaptureFormatRecord(widthPx: 1, heightPx: 1, framesPerSecond: 240, lens: "w"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
        await store.save(calibration)
        return Rig(store: store, lifecycle: SessionLifecycle(sessions: store, shots: store), calibration: calibration)
    }

    func addShot(_ session: Session, seq: Int, at: Date) async throws {
        let shot = try Shot(
            id: UUID(), sessionID: session.id, sequence: seq, mode: session.mode, swingHandedness: .right,
            clubSnapshot: ClubSnapshot(id: UUID(), name: "7i", loftRad: nil), calibrationID: calibration.id, impactTimeUTC: at,
            metrics: [:],
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        let ledger = try LedgerEntry(acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: at)
        _ = try await store.commitAccepted(shot, ledger: ledger)
    }
}

struct SessionLifecycleTests {
    @Test func startingSavesAnActiveSessionWithTheRightMode() async throws {
        let rig = try await Rig.make()
        let quick = try await rig.lifecycle.start(.quickShot, now: t0)
        #expect(quick.mode == .quickShot && quick.recoveryState == .active && quick.endedAt == nil)
        #expect(try await rig.store.session(id: quick.id) == quick)
        let standard = try await rig.lifecycle.start(.standard, now: t0)
        #expect(standard.mode == .practice)
    }

    @Test func finishingClosesTheSessionOnceAndTwiceChangesNothing() async throws {
        let rig = try await Rig.make()
        let s = try await rig.lifecycle.start(.standard, now: t0)
        try await rig.addShot(s, seq: 1, at: t0.addingTimeInterval(60))
        #expect(try await rig.lifecycle.finish(s.id, shotCount: 1, now: t0.addingTimeInterval(120)) == .closed)
        let closed = try #require(await rig.store.session(id: s.id))
        #expect(closed.recoveryState == .endedCleanly && closed.endedAt == t0.addingTimeInterval(120))
        #expect(try await rig.lifecycle.finish(s.id, shotCount: 1, now: t0.addingTimeInterval(999)) == .alreadyClosed) // double tap
        #expect(try await rig.store.session(id: s.id)?.endedAt == t0.addingTimeInterval(120)) // not rewritten
        #expect(try await rig.store.sessions().count == 1)
    }

    @Test func aSessionWithoutShotsIsNotKept() async throws {
        let rig = try await Rig.make()
        let s = try await rig.lifecycle.start(.quickShot, now: t0)
        #expect(try await rig.lifecycle.finish(s.id, shotCount: 0, now: t0.addingTimeInterval(30)) == .discardedEmpty)
        #expect(try await rig.store.sessions().isEmpty)
    }

    /// An interrupted session (app killed) is recovered at the next launch, not lost and not left "active" forever.
    @Test func interruptedSessionsAreRecoveredWithTheirShots() async throws {
        let rig = try await Rig.make()
        let live = try await rig.lifecycle.start(.standard, now: t0)
        try await rig.addShot(live, seq: 1, at: t0.addingTimeInterval(60))
        try await rig.addShot(live, seq: 2, at: t0.addingTimeInterval(200))
        let empty = try await rig.lifecycle.start(.quickShot, now: t0.addingTimeInterval(1000))
        let finished = try await rig.lifecycle.start(.standard, now: t0.addingTimeInterval(2000))
        try await rig.addShot(finished, seq: 1, at: t0.addingTimeInterval(2060))
        _ = try await rig.lifecycle.finish(finished.id, shotCount: 1, now: t0.addingTimeInterval(2100))

        let recovered = try await rig.lifecycle.recoverInterrupted()
        #expect(Set(recovered.recovered) == [live.id] && recovered.discarded == [empty.id])
        let back = try #require(await rig.store.session(id: live.id))
        #expect(back.recoveryState == .interrupted && back.endedAt == t0.addingTimeInterval(200)) // ends at its last shot
        #expect(try await rig.store.shots(sessionID: live.id).count == 2)
        #expect(try await rig.store.session(id: empty.id) == nil)
        #expect(try await rig.store.session(id: finished.id)?.recoveryState == .endedCleanly) // untouched
        // idempotent: running it again changes nothing
        let again = try await rig.lifecycle.recoverInterrupted()
        #expect(again.recovered.isEmpty && again.discarded.isEmpty)
    }

    @Test func recoveringNeverTouchesTheLedger() async throws {
        let rig = try await Rig.make()
        let s = try await rig.lifecycle.start(.standard, now: t0)
        try await rig.addShot(s, seq: 1, at: t0.addingTimeInterval(10))
        _ = try await rig.lifecycle.recoverInterrupted()
        #expect(try await rig.store.entries().count == 1)
    }
}
