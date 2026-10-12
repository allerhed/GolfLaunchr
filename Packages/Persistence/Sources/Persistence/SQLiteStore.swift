import Domain
import Foundation

/// Where a simulated failure strikes inside `commitAccepted`. The hook that arms it exists in Debug builds only.
public enum CommitFault: String, Sendable {
    case afterShotInsert, afterLedgerInsert, afterCommit
}

public enum FaultAction: String, Sendable {
    /// Throw, so the transaction rolls back.
    case throwError
    /// SIGKILL the process, like the system terminating the app mid-write.
    case killProcess
}

/// The real local store (spec F20): SQLite in write-ahead-log mode with full synchronous commits.
/// A shot and its ledger entry are written in one transaction; a crash leaves both or neither.
public actor SQLiteStore: SessionRepository, CalibrationRepository, ShotRepository, LedgerRepository {
    private let database: SQLiteDatabase
    private let allowsSynthetic: Bool
    private let encoder = ContractJSON.encoder()
    private let decoder = ContractJSON.decoder()
    #if DEBUG
        private var fault: (point: CommitFault, action: FaultAction)?
    #endif

    /// Opens or creates the database and migrates it.
    /// - Throws: `.corrupt` for a non-database file, `.schemaTooNew` for a newer database: neither is modified.
    public init(url: URL, migrations: [SQLMigration] = SQLMigrations.all, allowsSynthetic: Bool = false) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        database = try SQLiteDatabase(path: url.path)
        do { try database.migrate(migrations) } catch {
            database.close()
            throw error
        }
        self.allowsSynthetic = allowsSynthetic
    }

    #if DEBUG
        /// Test hook (Debug builds only): make the next commit fail at `point`.
        public func armFault(_ point: CommitFault?, action: FaultAction = .throwError) {
            fault = point.map { ($0, action) }
        }
    #endif

    private func trip(_ point: CommitFault) throws {
        #if DEBUG
            guard let armed = fault, armed.point == point else { return }
            fault = nil
            switch armed.action {
            case .throwError: throw PersistenceError.storageFailure("injected fault \(point.rawValue)")
            case .killProcess: kill(getpid(), SIGKILL)
            }
        #endif
    }

    private func json(_ value: some Encodable) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(bytes: data, encoding: .utf8) else { throw PersistenceError.storageFailure("record is not valid UTF-8") }
        return text
    }

    private func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        do { return try decoder.decode(type, from: Data(text.utf8)) } catch {
            throw PersistenceError.storageFailure("stored record cannot be decoded: \(error)")
        }
    }

    /// Schema version the open database is at (for tests and diagnostics).
    public func schemaVersion() throws -> Int {
        try Int(database.query("PRAGMA user_version") { $0.int(0) }.first ?? 0)
    }

    public func appliedMigrations() throws -> [Int] {
        try database.query("SELECT version FROM migrations ORDER BY version") { Int($0.int(0)) }
    }

    // MARK: SessionRepository

    public func save(_ session: Session) throws {
        try database.run(
            """
            INSERT INTO sessions (id, created_at, json) VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET created_at = excluded.created_at, json = excluded.json
            """,
            [.text(session.id.uuidString), .double(session.createdAt.timeIntervalSince1970), .text(json(session))]
        )
    }

    public func session(id: UUID) throws -> Session? {
        try database.query("SELECT json FROM sessions WHERE id = ?", [.text(id.uuidString)]) { $0.text(0) }
            .first.map { try decode(Session.self, $0) }
    }

    public func sessions() throws -> [Session] {
        try database.query("SELECT json FROM sessions ORDER BY created_at DESC, id") { $0.text(0) }.map { try decode(Session.self, $0) }
    }

    public func deleteSession(id: UUID) throws {
        try database.transaction {
            // Shots go with the session (ON DELETE CASCADE). The ledger table is untouched.
            guard try database.run("DELETE FROM sessions WHERE id = ?", [.text(id.uuidString)]) == 1 else {
                throw PersistenceError.notFound("session \(id)")
            }
        }
    }

    // MARK: CalibrationRepository

    public func save(_ calibration: CalibrationRecord) throws {
        try database.run(
            "INSERT INTO calibrations (id, json) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET json = excluded.json",
            [.text(calibration.id.uuidString), .text(json(calibration))]
        )
    }

    public func calibration(id: UUID) throws -> CalibrationRecord? {
        try database.query("SELECT json FROM calibrations WHERE id = ?", [.text(id.uuidString)]) { $0.text(0) }
            .first.map { try decode(CalibrationRecord.self, $0) }
    }

    // MARK: ShotRepository

    public func commitAccepted(_ shot: Shot, ledger: LedgerEntry) throws -> DurableReceipt {
        do {
            return try database.transaction {
                if let existing = try storedShot(shot.id) {
                    guard existing == shot, let stored = try storedLedger(shot.id), stored == ledger else {
                        throw PersistenceError.conflictingDuplicate(shot.id)
                    }
                    return DurableReceipt(shotID: shot.id, ledgerEntry: stored, wasAlreadyCommitted: true)
                }
                if shot.isSynthetic, !allowsSynthetic {
                    throw PersistenceError.syntheticShotRejected(shot.id)
                }
                guard ledger.acceptedShotID == shot.id else { throw PersistenceError.ledgerMismatch }
                guard try exists("sessions", id: shot.sessionID) else { throw PersistenceError.unknownSession(shot.sessionID) }
                guard try exists("calibrations", id: shot.calibrationID)
                else { throw PersistenceError.unknownCalibration(shot.calibrationID) }
                let taken = try database.query(
                    "SELECT 1 FROM shots WHERE session_id = ? AND sequence = ?", [
                        .text(shot.sessionID.uuidString),
                        .int(Int64(shot.sequence))
                    ]
                ) { $0.int(0) }
                guard taken.isEmpty else { throw PersistenceError.duplicateSequence(sessionID: shot.sessionID, sequence: shot.sequence) }

                try database.run(
                    "INSERT INTO shots (id, session_id, sequence, included, is_synthetic, json) VALUES (?, ?, ?, ?, ?, ?)",
                    [
                        .text(shot.id.uuidString), .text(shot.sessionID.uuidString), .int(Int64(shot.sequence)),
                        .int(shot.included ? 1 : 0), .int(shot.isSynthetic ? 1 : 0), .text(json(shot)),
                    ]
                )
                try trip(.afterShotInsert)
                try database.run(
                    "INSERT INTO ledger (shot_id, kind, credit_cost, committed_at, json) VALUES (?, ?, ?, ?, ?)",
                    [
                        .text(ledger.acceptedShotID.uuidString), .text(ledger.allowanceKind.rawValue), .int(Int64(ledger.creditCost)),
                        .double(ledger.committedAt.timeIntervalSince1970), .text(json(ledger)),
                    ]
                )
                try trip(.afterLedgerInsert)
                return DurableReceipt(shotID: shot.id, ledgerEntry: ledger, wasAlreadyCommitted: false)
            }
            .afterCommit { try trip(.afterCommit) }
        }
    }

    public func shot(id: UUID) throws -> Shot? {
        try storedShot(id)
    }

    public func shots(sessionID: UUID) throws -> [Shot] {
        try database.query("SELECT json FROM shots WHERE session_id = ? ORDER BY sequence", [.text(sessionID.uuidString)]) { $0.text(0) }
            .map { try decode(Shot.self, $0) }
    }

    @discardableResult
    public func setIncluded(shotID: UUID, included: Bool) throws -> Shot {
        try database.transaction {
            guard var shot = try storedShot(shotID) else { throw PersistenceError.notFound("shot \(shotID)") }
            shot.included = included
            try database.run(
                "UPDATE shots SET included = ?, json = ? WHERE id = ?", [
                    .int(included ? 1 : 0),
                    .text(json(shot)),
                    .text(shotID.uuidString)
                ]
            )
            return shot
        }
    }

    public func deleteShot(id: UUID) throws {
        guard try database.run("DELETE FROM shots WHERE id = ?", [.text(id.uuidString)]) == 1 else {
            throw PersistenceError.notFound("shot \(id)")
        } // the ledger row stays
    }

    // MARK: LedgerRepository

    public func entries() throws -> [LedgerEntry] {
        try database.query("SELECT json FROM ledger ORDER BY committed_at, shot_id") { $0.text(0) }.map { try decode(LedgerEntry.self, $0) }
    }

    public func entry(forShot shotID: UUID) throws -> LedgerEntry? {
        try storedLedger(shotID)
    }

    public func creditsSpent(kind: AllowanceKind) throws -> Int {
        try Int(database.query("SELECT COALESCE(SUM(credit_cost), 0) FROM ledger WHERE kind = ?", [.text(kind.rawValue)]) { $0.int(0) }
            .first ?? 0)
    }

    // MARK: helpers

    private func storedShot(_ id: UUID) throws -> Shot? {
        try database.query("SELECT json FROM shots WHERE id = ?", [.text(id.uuidString)]) { $0.text(0) }.first.map { try decode(
            Shot.self,
            $0
        ) }
    }

    private func storedLedger(_ id: UUID) throws -> LedgerEntry? {
        try database.query("SELECT json FROM ledger WHERE shot_id = ?", [.text(id.uuidString)]) { $0.text(0) }
            .first.map { try decode(LedgerEntry.self, $0) }
    }

    private func exists(_ table: String, id: UUID) throws -> Bool {
        try !database.query("SELECT 1 FROM \(table) WHERE id = ?", [.text(id.uuidString)]) { $0.int(0) }.isEmpty
    }
}

private extension DurableReceipt {
    /// Runs `action` after the surrounding transaction has committed, then returns the receipt unchanged.
    func afterCommit(_ action: () throws -> Void) rethrows -> DurableReceipt {
        try action()
        return self
    }
}
