import Domain
import Foundation
@testable import Persistence
import PersistenceTestSupport
import Testing

struct CommitTests {
    @Test(arguments: Backend.allCases) func commitStoresShotAndLedgerTogether(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let shot = try w.shot()
        let receipt = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
        #expect(receipt.shotID == shot.id)
        #expect(receipt.wasAlreadyCommitted == false)
        #expect(try await w.store.shot(id: shot.id) == shot)
        #expect(try await w.store.entry(forShot: shot.id)?.creditCost == 1)
    }

    /// T02: duplicate commit gives one shot and one credit.
    @Test(arguments: Backend.allCases) func retryingACommitIsIdempotent(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        let first = try await w.store.commitAccepted(shot, ledger: ledger)
        let second = try await w.store.commitAccepted(shot, ledger: ledger)
        #expect(second.wasAlreadyCommitted)
        #expect(second.ledgerEntry == first.ledgerEntry)
        #expect(try await w.store.shots(sessionID: w.session.id).count == 1)
        #expect(try await w.store.entries().count == 1)
        #expect(try await w.store.creditsSpent(kind: .introductory) == 1)
    }

    @Test(arguments: Backend.allCases) func concurrentDuplicateCommitsCreateOneShotOneCredit(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        let store = w.store
        let receipts = try await withThrowingTaskGroup(of: DurableReceipt.self) { group in
            for _ in 0 ..< 20 {
                group.addTask { try await store.commitAccepted(shot, ledger: ledger) }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(receipts.count == 20)
        #expect(receipts.filter { !$0.wasAlreadyCommitted }.count == 1)
        #expect(try await w.store.shots(sessionID: w.session.id).count == 1)
        #expect(try await w.store.creditsSpent(kind: .introductory) == 1)
    }

    @Test(arguments: Backend.allCases) func sameIDWithDifferentContentIsAConflictAndKeepsTheOriginal(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let id = UUID()
        let original = try w.shot(id: id, ballSpeed: 45)
        _ = try await w.store.commitAccepted(original, ledger: w.ledger(for: original))
        let altered = try w.shot(id: id, ballSpeed: 60)
        await #expect(throws: PersistenceError.conflictingDuplicate(id)) {
            try await w.store.commitAccepted(altered, ledger: w.ledger(for: altered))
        }
        #expect(try await w.store.shot(id: id)?.value(.ballSpeed) == 45)
        #expect(try await w.store.creditsSpent(kind: .introductory) == 1)
    }

    /// T03 (in-memory part): a failure mid-commit leaves neither shot nor ledger, and a retry then succeeds exactly once.
    @Test(arguments: [FaultPoint.afterShotStaged, .afterLedgerStaged])
    func failureMidCommitLeavesNothingHalfWritten(point: FaultPoint) async throws {
        let w = try await World.make(backend: .inMemory)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        let memory = try #require(w.memory)
        await memory.armFault(point)
        await #expect(throws: PersistenceError.self) { try await w.store.commitAccepted(shot, ledger: ledger) }
        #expect(try await w.store.shot(id: shot.id) == nil)
        #expect(try await w.store.entries().isEmpty)
        let receipt = try await w.store.commitAccepted(shot, ledger: ledger)
        #expect(receipt.wasAlreadyCommitted == false)
        #expect(try await w.store.shots(sessionID: w.session.id).count == 1)
        #expect(try await w.store.entries().count == 1)
    }

    @Test(arguments: Backend.allCases) func invalidReferencesAreRejectedAndWriteNothing(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let ghostSession = UUID(), ghostCalibration = UUID()
        let noSession = try w.shot(sessionID: ghostSession)
        await #expect(throws: PersistenceError.unknownSession(ghostSession)) {
            try await w.store.commitAccepted(noSession, ledger: w.ledger(for: noSession))
        }
        let noCalibration = try w.shot(calibrationID: ghostCalibration)
        await #expect(throws: PersistenceError.unknownCalibration(ghostCalibration)) {
            try await w.store.commitAccepted(noCalibration, ledger: w.ledger(for: noCalibration))
        }
        let shot = try w.shot()
        let other = try w.shot()
        await #expect(throws: PersistenceError.ledgerMismatch) {
            try await w.store.commitAccepted(shot, ledger: w.ledger(for: other))
        }
        #expect(try await w.store.entries().isEmpty)
        #expect(try await w.store.shot(id: shot.id) == nil)
    }

    @Test(arguments: Backend.allCases) func sequenceNumbersAreUniquePerSession(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let a = try w.shot(sequence: 1)
        _ = try await w.store.commitAccepted(a, ledger: w.ledger(for: a))
        let b = try w.shot(sequence: 1)
        await #expect(throws: PersistenceError.duplicateSequence(sessionID: w.session.id, sequence: 1)) {
            try await w.store.commitAccepted(b, ledger: w.ledger(for: b))
        }
        #expect(try await w.store.entries().count == 1)
    }

    /// T13: synthetic shots cannot enter a production store.
    @Test(arguments: Backend.allCases) func productionStoreRejectsSyntheticShots(backend: Backend) async throws {
        let w = try await World.make(allowsSynthetic: false, backend: backend)
        let fake = try w.shot(synthetic: true)
        await #expect(throws: PersistenceError.syntheticShotRejected(fake.id)) {
            try await w.store.commitAccepted(fake, ledger: w.ledger(for: fake))
        }
        #expect(try await w.store.entries().isEmpty)
        let real = try w.shot(synthetic: false)
        _ = try await w.store.commitAccepted(real, ledger: w.ledger(for: real))
        #expect(try await w.store.entries().count == 1)
    }
}
