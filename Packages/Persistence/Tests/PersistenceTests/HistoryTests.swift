import Domain
import Foundation
@testable import Persistence
import PersistenceTestSupport
import Testing

struct HistoryTests {
    func commit(_ w: World, sequence: Int, kind: AllowanceKind = .introductory, cost: Int = 1) async throws -> Shot {
        let shot = try w.shot(sequence: sequence)
        _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot, kind: kind, cost: cost))
        return shot
    }

    @Test func shotsComeBackInSequenceOrder() async throws {
        let w = try await World.make()
        for seq in [3, 1, 2] {
            _ = try await commit(w, sequence: seq)
        }
        #expect(await w.store.shots(sessionID: w.session.id).map(\.sequence) == [1, 2, 3])
    }

    /// T09: exclude then re-include keeps the shot and does not touch the ledger.
    @Test func excludeAndRestoreKeepShotAndLedger() async throws {
        let w = try await World.make()
        let shot = try await commit(w, sequence: 1)
        let excluded = try await w.store.setIncluded(shotID: shot.id, included: false)
        #expect(excluded.included == false)
        #expect(await w.store.shot(id: shot.id)?.included == false)
        #expect(await w.store.creditsSpent(kind: .introductory) == 1)
        try await w.store.setIncluded(shotID: shot.id, included: true)
        #expect(await w.store.shot(id: shot.id)?.included == true)
        #expect(await w.store.entries().count == 1)
    }

    /// T09: hard delete removes the shot but the usage ledger survives (no free credit by deleting history).
    @Test func deletingAShotKeepsItsLedgerEntry() async throws {
        let w = try await World.make()
        let shot = try await commit(w, sequence: 1)
        try await w.store.deleteShot(id: shot.id)
        #expect(await w.store.shot(id: shot.id) == nil)
        #expect(await w.store.entry(forShot: shot.id) != nil)
        #expect(await w.store.creditsSpent(kind: .introductory) == 1)
    }

    @Test func deletingASessionRemovesItsShotsButNotOtherSessionsOrTheLedger() async throws {
        let w = try await World.make()
        _ = try await commit(w, sequence: 1)
        _ = try await commit(w, sequence: 2)
        let other = try Session(mode: .target, createdAt: w.t0.addingTimeInterval(10))
        await w.store.save(other)
        let kept = try w.shot(sequence: 1, sessionID: other.id)
        _ = try await w.store.commitAccepted(kept, ledger: w.ledger(for: kept))
        try await w.store.deleteSession(id: w.session.id)
        #expect(await w.store.shots(sessionID: w.session.id).isEmpty)
        #expect(await w.store.session(id: w.session.id) == nil)
        #expect(await w.store.shots(sessionID: other.id).count == 1)
        #expect(await w.store.entries().count == 3)
    }

    @Test func operationsOnMissingRecordsReportNotFound() async throws {
        let w = try await World.make()
        let ghost = UUID()
        await #expect(throws: PersistenceError.notFound("shot \(ghost)")) { try await w.store.deleteShot(id: ghost) }
        await #expect(throws: PersistenceError.notFound("shot \(ghost)")) { try await w.store.setIncluded(shotID: ghost, included: false) }
        await #expect(throws: PersistenceError.notFound("session \(ghost)")) { try await w.store.deleteSession(id: ghost) }
        #expect(await w.store.shot(id: ghost) == nil)
        #expect(await w.store.entry(forShot: ghost) == nil)
    }

    @Test func creditsAreSummedPerAllowanceKind() async throws {
        let w = try await World.make()
        _ = try await commit(w, sequence: 1, kind: .introductory, cost: 1)
        _ = try await commit(w, sequence: 2, kind: .introductory, cost: 1)
        _ = try await commit(w, sequence: 3, kind: .monthly, cost: 1)
        _ = try await commit(w, sequence: 4, kind: .paid, cost: 0)
        #expect(await w.store.creditsSpent(kind: .introductory) == 2)
        #expect(await w.store.creditsSpent(kind: .monthly) == 1)
        #expect(await w.store.creditsSpent(kind: .paid) == 0)
        #expect(await w.store.creditsSpent(kind: .complimentary) == 0)
    }

    @Test func sessionsListNewestFirst() async throws {
        let w = try await World.make()
        let newer = try Session(mode: .practice, createdAt: w.t0.addingTimeInterval(100))
        await w.store.save(newer)
        #expect(await w.store.sessions().map(\.id) == [newer.id, w.session.id])
    }
}
