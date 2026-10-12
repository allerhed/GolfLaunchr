import Domain
import Foundation
@testable import Persistence
import Testing

struct MigrationTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("golflaunchr-migrate-\(UUID().uuidString)/store.sqlite")
    }

    /// A pretend future change: a new column on sessions, backfilled from existing rows.
    let v2 = SQLMigration(version: 2, name: "sessions.note", statements: [
        "ALTER TABLE sessions ADD COLUMN note TEXT",
        "UPDATE sessions SET note = 'migrated'",
    ])

    func seed(_ url: URL, migrations: [SQLMigration] = [SQLMigrations.v1]) async throws -> (ids: [UUID], shotID: UUID) {
        let store = try SQLiteStore(url: url, migrations: migrations, allowsSynthetic: true)
        let w = try await World.make(backend: .inMemory) // only for building valid objects
        try await store.save(w.session)
        try await store.save(w.calibration)
        let shot = try w.shot()
        _ = try await store.commitAccepted(shot, ledger: w.ledger(for: shot))
        return ([w.session.id, w.calibration.id], shot.id)
    }

    @Test func aFreshDatabaseIsAtTheNewestVersionAndRecordsTheStep() async throws {
        let store = try SQLiteStore(url: tempURL())
        #expect(try await store.schemaVersion() == 1)
        #expect(try await store.appliedMigrations() == [1])
    }

    @Test func reopeningDoesNotReapplyMigrations() async throws {
        let url = tempURL()
        _ = try SQLiteStore(url: url)
        let again = try SQLiteStore(url: url)
        #expect(try await again.appliedMigrations() == [1])
    }

    /// F20 acceptance: schema migration preserves counts and IDs.
    @Test func upgradingKeepsEveryRecordAndID() async throws {
        let url = tempURL()
        let before = try await seed(url)
        let upgraded = try SQLiteStore(url: url, migrations: [SQLMigrations.v1, v2], allowsSynthetic: true)
        #expect(try await upgraded.schemaVersion() == 2)
        #expect(try await upgraded.appliedMigrations() == [1, 2])
        #expect(try await upgraded.session(id: before.ids[0]) != nil)
        #expect(try await upgraded.calibration(id: before.ids[1]) != nil)
        #expect(try await upgraded.shot(id: before.shotID) != nil)
        #expect(try await upgraded.entries().count == 1)
        let raw = try SQLiteDatabase(path: url.path)
        #expect(try raw.query("SELECT note FROM sessions") { $0.text(0) } == ["migrated"]) // the migration really ran
    }

    @Test func aFailingMigrationChangesNothing() async throws {
        let url = tempURL()
        let before = try await seed(url)
        let broken = SQLMigration(version: 2, name: "broken", statements: [
            "ALTER TABLE sessions ADD COLUMN note TEXT", "THIS IS NOT SQL",
        ])
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: url, migrations: [SQLMigrations.v1, broken]) }
        let intact = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await intact.schemaVersion() == 1) // still version 1
        #expect(try await intact.shot(id: before.shotID) != nil)
        let raw = try SQLiteDatabase(path: url.path)
        #expect(try raw.query("SELECT name FROM pragma_table_info('sessions') WHERE name = 'note'") { $0.text(0) }
            .isEmpty) // half-step rolled back
    }

    @Test func aDatabaseFromANewerAppIsRefusedAndNotModified() async throws {
        let url = tempURL()
        _ = try await seed(url, migrations: [SQLMigrations.v1, v2])
        #expect(throws: PersistenceError.schemaTooNew(found: 2, supported: 1)) { try SQLiteStore(url: url, migrations: [SQLMigrations.v1]) }
        let still = try SQLiteStore(url: url, migrations: [SQLMigrations.v1, v2], allowsSynthetic: true)
        #expect(try await still.schemaVersion() == 2)
        #expect(try await still.entries().count == 1)
    }

    @Test func migrationListsMustBeContiguousFromOne() {
        let gap = SQLMigration(version: 3, name: "gap", statements: [])
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: tempURL(), migrations: [SQLMigrations.v1, gap]) }
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: tempURL(), migrations: [v2]) }
    }
}
