import Foundation

/// One schema step. Applied inside a single transaction together with the version bump, so a failing step changes nothing.
public struct SQLMigration: Sendable {
    public let version: Int
    public let name: String
    public let statements: [String]

    public init(version: Int, name: String, statements: [String]) {
        self.version = version
        self.name = name
        self.statements = statements
    }
}

public enum SQLMigrations {
    /// Version 1: the baseline schema. Domain objects are stored as contract JSON next to the columns needed for queries and
    /// integrity. The ledger deliberately has no foreign key to shots: usage history survives deleting golf history.
    public static let v1 = SQLMigration(version: 1, name: "baseline", statements: [
        "CREATE TABLE sessions (id TEXT PRIMARY KEY, created_at REAL NOT NULL, json TEXT NOT NULL)",
        "CREATE TABLE calibrations (id TEXT PRIMARY KEY, json TEXT NOT NULL)",
        """
        CREATE TABLE shots (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
            sequence INTEGER NOT NULL,
            included INTEGER NOT NULL,
            is_synthetic INTEGER NOT NULL,
            json TEXT NOT NULL,
            UNIQUE (session_id, sequence)
        )
        """,
        "CREATE INDEX shots_by_session ON shots (session_id, sequence)",
        """
        CREATE TABLE ledger (
            shot_id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            credit_cost INTEGER NOT NULL,
            committed_at REAL NOT NULL,
            json TEXT NOT NULL
        )
        """,
        "CREATE TABLE migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at REAL NOT NULL)",
    ])

    public static let all: [SQLMigration] = [v1]
}

extension SQLiteDatabase {
    /// Brings the database to the newest version in `migrations`. A database written by a newer app is refused untouched.
    func migrate(_ migrations: [SQLMigration]) throws {
        let supported = migrations.map(\.version).max() ?? 0
        guard migrations.map(\.version) == Array(1 ... max(supported, 1)).prefix(migrations.count).map(\.self) else {
            throw PersistenceError.storageFailure("migration versions must be 1, 2, 3 ... in order")
        }
        let current = try Int(query("PRAGMA user_version") { $0.int(0) }.first ?? 0)
        guard current <= supported else { throw PersistenceError.schemaTooNew(found: current, supported: supported) }
        for migration in migrations where migration.version > current {
            try transaction {
                for statement in migration.statements {
                    try exec(statement)
                }
                try run("INSERT INTO migrations (version, name, applied_at) VALUES (?, ?, ?)", [
                    .int(Int64(migration.version)), .text(migration.name), .double(Date().timeIntervalSince1970),
                ])
                try exec("PRAGMA user_version = \(migration.version)")
            }
        }
    }
}
