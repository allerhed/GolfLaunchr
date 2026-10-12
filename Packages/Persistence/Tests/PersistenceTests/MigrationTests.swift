import Domain
import Foundation
@testable import Persistence
import Testing

struct MigrationTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("golflaunchr-migrate-\(UUID().uuidString)/store.sqlite")
    }

    /// A pretend future change: a new column on sessions, backfilled from existing rows.
    let v3 = SQLMigration(version: 3, name: "sessions.note", statements: [
        "ALTER TABLE sessions ADD COLUMN note TEXT",
        "UPDATE sessions SET note = 'migrated'",
    ])

    func seed(_ url: URL, migrations: [SQLMigration] = [SQLMigrations.v1, SQLMigrations.v2]) async throws -> (ids: [UUID], shotID: UUID) {
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
        #expect(try await store.schemaVersion() == 2)
        #expect(try await store.appliedMigrations() == [1, 2])
    }

    @Test func reopeningDoesNotReapplyMigrations() async throws {
        let url = tempURL()
        _ = try SQLiteStore(url: url)
        let again = try SQLiteStore(url: url)
        #expect(try await again.appliedMigrations() == [1, 2])
    }

    /// F20 acceptance: schema migration preserves counts and IDs.
    @Test func upgradingKeepsEveryRecordAndID() async throws {
        let url = tempURL()
        let before = try await seed(url)
        let upgraded = try SQLiteStore(url: url, migrations: [SQLMigrations.v1, SQLMigrations.v2, v3], allowsSynthetic: true)
        #expect(try await upgraded.schemaVersion() == 3)
        #expect(try await upgraded.appliedMigrations() == [1, 2, 3])
        #expect(try await upgraded.session(id: before.ids[0]) != nil)
        #expect(try await upgraded.calibration(id: before.ids[1]) != nil)
        #expect(try await upgraded.shot(id: before.shotID) != nil)
        #expect(try await upgraded.entries().count == 1)
        let raw = try SQLiteDatabase(path: url.path)
        #expect(try raw.query("SELECT note FROM sessions") { $0.text(0) } == ["migrated"]) // the migration really ran
    }

    /// The real v1 -> v2 step (the bag table) on a database that already holds shots.
    @Test func theBagMigrationKeepsExistingDataAndAddsAnEmptyBag() async throws {
        let url = tempURL()
        let before = try await seed(url, migrations: [SQLMigrations.v1])
        let store = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await store.schemaVersion() == 2)
        #expect(try await store.shot(id: before.shotID) != nil)
        #expect(try await store.loadBag() == nil) // nothing saved yet: the app seeds
        try await store.saveBag(Bag.seeded { "\($0)" })
        #expect(try await store.loadBag()?.clubs.count == 13)
    }

    @Test func aFailingMigrationChangesNothing() async throws {
        let url = tempURL()
        let before = try await seed(url)
        let broken = SQLMigration(version: 3, name: "broken", statements: [
            "ALTER TABLE sessions ADD COLUMN note TEXT", "THIS IS NOT SQL",
        ])
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: url, migrations: [SQLMigrations.v1, SQLMigrations.v2, broken]) }
        let intact = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await intact.schemaVersion() == 2) // still version 2
        #expect(try await intact.shot(id: before.shotID) != nil)
        let raw = try SQLiteDatabase(path: url.path)
        #expect(try raw.query("SELECT name FROM pragma_table_info('sessions') WHERE name = 'note'") { $0.text(0) }
            .isEmpty) // half-step rolled back
    }

    @Test func aDatabaseFromANewerAppIsRefusedAndNotModified() async throws {
        let url = tempURL()
        _ = try await seed(url, migrations: [SQLMigrations.v1, SQLMigrations.v2, v3])
        #expect(throws: PersistenceError.schemaTooNew(found: 3, supported: 2)) { try SQLiteStore(url: url, migrations: SQLMigrations.all) }
        let still = try SQLiteStore(url: url, migrations: [SQLMigrations.v1, SQLMigrations.v2, v3], allowsSynthetic: true)
        #expect(try await still.schemaVersion() == 3)
        #expect(try await still.entries().count == 1)
    }

    @Test func migrationListsMustBeContiguousFromOne() {
        let gap = SQLMigration(version: 4, name: "gap", statements: [])
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: tempURL(), migrations: [SQLMigrations.v1, SQLMigrations.v2, gap]) }
        #expect(throws: PersistenceError.self) { try SQLiteStore(url: tempURL(), migrations: [v3]) }
    }
}
