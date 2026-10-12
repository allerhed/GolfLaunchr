import Domain
import Foundation
@testable import Persistence
import PersistenceTestSupport
import Testing

/// Behaviour specific to the SQLite store: durability, rollback, real crashes, migrations, corruption.
struct SQLiteStoreTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("golflaunchr-sqlite-\(UUID().uuidString)/store.sqlite")
    }

    @Test func dataSurvivesClosingAndReopeningTheDatabase() async throws {
        let w = try await World.make(backend: .sqlite)
        let shot = try w.shot()
        _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
        try await w.store.setIncluded(shotID: shot.id, included: false)
        let url = try #require(w.databaseURL)
        let reopened = try SQLiteStore(url: url, allowsSynthetic: true)
        let back = try #require(await reopened.shot(id: shot.id))
        #expect(back.included == false) // the exclusion survived too
        #expect(try await (reopened.entries()).count == 1)
        #expect(try await reopened.session(id: w.session.id) == w.session)
        #expect(try await reopened.calibration(id: w.calibration.id) == w.calibration)
    }

    @Test(arguments: [CommitFault.afterShotInsert, .afterLedgerInsert])
    func aThrownFailureMidCommitRollsEverythingBack(point: CommitFault) async throws {
        let w = try await World.make(backend: .sqlite)
        let sqlite = try #require(w.sqlite)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        await sqlite.armFault(point, action: .throwError)
        await #expect(throws: PersistenceError.self) { try await sqlite.commitAccepted(shot, ledger: ledger) }
        #expect(try await sqlite.shot(id: shot.id) == nil)
        #expect(try await sqlite.entries().isEmpty)
        let receipt = try await sqlite.commitAccepted(shot, ledger: ledger)
        #expect(receipt.wasAlreadyCommitted == false)
        #expect(try await sqlite.shots(sessionID: w.session.id).count == 1)
        #expect(try await sqlite.entries().count == 1)
    }

    // MARK: real crashes (T03): a separate process SIGKILLs itself mid-commit

    private final class BundleAnchor {}

    /// The helper is built next to the test bundle (`.build/.../Products/Debug`).
    func helperURL() throws -> URL {
        var candidates: [URL] = [Bundle(for: BundleAnchor.self).bundleURL.deletingLastPathComponent()]
        if let path = ProcessInfo.processInfo.environment["XCTestBundlePath"] {
            candidates.append(URL(fileURLWithPath: path).deletingLastPathComponent())
        }
        for dir in candidates {
            let url = dir.appendingPathComponent("PersistenceCrashHelper")
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        throw PersistenceError.storageFailure("PersistenceCrashHelper not found next to the test bundle: \(candidates.map(\.path))")
    }

    /// Runs the helper against `url` and returns (terminated by signal, exit status, stdout).
    func runHelper(url: URL, shot: Shot, ledger: LedgerEntry, fault: String) throws -> (killed: Bool, output: String) {
        let dir = url.deletingLastPathComponent()
        let encoder = ContractJSON.encoder()
        let shotFile = dir.appendingPathComponent("shot.json"), ledgerFile = dir.appendingPathComponent("ledger.json")
        try encoder.encode(shot).write(to: shotFile)
        try encoder.encode(ledger).write(to: ledgerFile)
        let process = Process()
        process.executableURL = try helperURL()
        process.arguments = [url.path, shotFile.path, ledgerFile.path, fault]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationReason == .uncaughtSignal, output)
    }

    @Test(arguments: ["afterShotInsert", "afterLedgerInsert"])
    func killingTheProcessBeforeCommitLeavesNothing(fault: String) async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        let run = try runHelper(url: url, shot: shot, ledger: ledger, fault: fault)
        #expect(run.killed, "the helper must have been killed: \(run.output)")
        let reopened = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await reopened.shot(id: shot.id) == nil)
        #expect(try await reopened.entries().isEmpty)
        // And the store is usable afterwards: the retry commits exactly once.
        let receipt = try await reopened.commitAccepted(shot, ledger: ledger)
        #expect(receipt.wasAlreadyCommitted == false)
        #expect(try await reopened.shots(sessionID: w.session.id).count == 1)
    }

    @Test func killingTheProcessAfterCommitKeepsExactlyOneShotAndOneLedgerEntry() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let shot = try w.shot()
        let ledger = try w.ledger(for: shot)
        let run = try runHelper(url: url, shot: shot, ledger: ledger, fault: "afterCommit")
        #expect(run.killed, "the helper must have been killed: \(run.output)")
        let reopened = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await reopened.shot(id: shot.id) == shot)
        #expect(try await reopened.entries().count == 1)
        #expect(try await reopened.creditsSpent(kind: .introductory) == 1)
        let again = try await reopened.commitAccepted(shot, ledger: ledger) // the app retries after relaunch
        #expect(again.wasAlreadyCommitted)
        #expect(try await reopened.entries().count == 1)
    }

    @Test func theHelperWithoutAFaultCommitsNormally() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let shot = try w.shot()
        let run = try runHelper(url: url, shot: shot, ledger: w.ledger(for: shot), fault: "none")
        #expect(!run.killed)
        #expect(run.output.contains("committed duplicate=false"))
    }

    // MARK: corrupt and unreadable data

    @Test func aFileThatIsNotADatabaseIsRefusedAndLeftUntouched() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let garbage = Data("this is definitely not a sqlite database, just text".utf8)
        try garbage.write(to: url)
        #expect(throws: PersistenceError.corrupt(url.path)) { try SQLiteStore(url: url) }
        #expect(try Data(contentsOf: url) == garbage)
    }

    @Test func anUnreadableStoredRecordIsAnErrorNotACrashOrAFakeRecord() async throws {
        let w = try await World.make(backend: .sqlite)
        let shot = try w.shot()
        _ = try await w.store.commitAccepted(shot, ledger: w.ledger(for: shot))
        let raw = try SQLiteDatabase(path: #require(w.databaseURL).path)
        try raw.run("UPDATE shots SET json = '{not json' WHERE id = ?", [.text(shot.id.uuidString)])
        await #expect(throws: PersistenceError.self) { try await w.store.shot(id: shot.id) }
        await #expect(throws: PersistenceError.self) { try await w.store.shots(sessionID: w.session.id) }
    }

    @Test func foreignKeysAreEnforcedSoAShotCannotPointAtNothing() async throws {
        let w = try await World.make(backend: .sqlite)
        let raw = try SQLiteDatabase(path: #require(w.databaseURL).path)
        #expect(throws: PersistenceError.self) {
            try raw
                .run(
                    "INSERT INTO shots (id, session_id, sequence, included, is_synthetic, json) "
                        + "VALUES ('x', 'no-such-session', 1, 1, 0, '{}')"
                )
        }
    }
}
