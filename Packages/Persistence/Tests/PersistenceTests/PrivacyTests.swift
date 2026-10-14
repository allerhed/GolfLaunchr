import Domain
import Foundation
@testable import Persistence
import PersistenceTestSupport
import Testing

/// F21: delete all local practice data. The usage ledger is deliberately kept (a disclosed rule): deleting data must not reset the
/// free allowance.
struct PrivacyTests {
    func fill(_ w: World, shots: Int = 3) async throws -> [Shot] {
        var made: [Shot] = []
        for seq in 1 ... shots {
            let shot = try w.shot(sequence: seq)
            _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
            made.append(shot)
        }
        try await w.store.saveBag(Bag.seeded { "\($0)" })
        return made
    }

    @Test(arguments: Backend
        .allCases) func deleteAllRemovesSessionsShotsCalibrationsAndBagButKeepsTheLedger(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let made = try await fill(w)
        let summary = try await w.store.deleteAllPracticeData()
        #expect(summary == DeletionSummary(sessions: 1, shots: 3, calibrations: 1, bagDeleted: true))
        #expect(try await w.store.sessions().isEmpty)
        #expect(try await w.store.shot(id: made[0].id) == nil)
        #expect(try await w.store.calibration(id: w.calibration.id) == nil)
        #expect(try await w.store.loadBag() == nil)
        #expect(try await w.store.entries().count == 3, "the ledger is kept")
        #expect(try await w.store.creditsSpent(kind: .introductory) == 3)
    }

    @Test(arguments: Backend.allCases) func deletingAnEmptyStoreIsHarmlessAndReportsNothing(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        _ = try await w.store.deleteAllPracticeData()
        let again = try await w.store.deleteAllPracticeData()
        #expect(again == DeletionSummary(sessions: 0, shots: 0, calibrations: 0, bagDeleted: false))
    }

    @Test(arguments: Backend.allCases) func practiceCanStartAgainAfterADeletionAndTheLedgerKeepsCounting(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        _ = try await fill(w, shots: 2)
        _ = try await w.store.deleteAllPracticeData()
        let session = try Session(mode: .practice, createdAt: w.t0.addingTimeInterval(100))
        try await w.store.save(session)
        try await w.store.save(w.calibration)
        let shot = try w.shot(sequence: 1, sessionID: session.id)
        _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
        #expect(try await w.store.shots(sessionID: session.id).count == 1)
        #expect(try await w.store.creditsSpent(kind: .introductory) == 3, "2 kept from before plus 1 new")
    }

    @Test func deletedContentIsGoneFromTheDatabaseFileToo() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let marker = "ZZ-UNIQUE-CLUB-NAME-\(UUID().uuidString)"
        let session = try Session(mode: .practice, createdAt: w.t0.addingTimeInterval(5))
        try await w.store.save(session)
        let shot = try Shot(
            id: UUID(), sessionID: session.id, sequence: 1, mode: .practice, swingHandedness: .right,
            clubSnapshot: ClubSnapshot(id: UUID(), name: marker, loftRad: nil), calibrationID: w.calibration.id, impactTimeUTC: w.t0,
            metrics: [:], environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
        _ = try await w.store.deleteAllPracticeData()
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            guard let data = try? Data(contentsOf: file) else { continue }
            #expect(data.range(of: Data(marker.utf8)) == nil, "\(file.lastPathComponent) still holds deleted text")
        }
    }

    // MARK: media only

    @Test func deleteAllMediaRemovesCommittedAndStagedFilesAndKeepsTheFolderUsable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("media-\(UUID().uuidString)")
        let media = try MediaDirectory(root: root)
        try media.commit(media.stage(Data(repeating: 1, count: 1000)), as: "a/one.mov")
        try media.commit(media.stage(Data(repeating: 2, count: 500)), as: "two.mov")
        _ = try media.stage(Data(repeating: 3, count: 10)) // an interrupted write
        let result = try media.deleteAll()
        #expect(result == MediaDeletion(files: 3, bytes: 1510))
        #expect(try media.scanOrphans(referenced: []).isEmpty)
        try media.commit(media.stage(Data("new".utf8)), as: "after.mov")
        #expect(try media.exists("after.mov"))
        #expect(try media.deleteAll() == MediaDeletion(files: 1, bytes: 3))
        #expect(try media.deleteAll() == MediaDeletion(files: 0, bytes: 0))
    }
}
