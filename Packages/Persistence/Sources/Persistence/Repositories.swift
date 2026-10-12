import Domain
import Foundation

public enum PersistenceError: Error, Equatable, Sendable {
    case notFound(String)
    case unknownSession(UUID)
    case unknownCalibration(UUID)
    /// Another shot already holds this sequence number in the session.
    case duplicateSequence(sessionID: UUID, sequence: Int)
    /// Same shot ID committed again with different content: never silently overwritten.
    case conflictingDuplicate(UUID)
    /// The ledger entry does not belong to the shot being committed.
    case ledgerMismatch
    /// Synthetic (fixture/demo) shots are refused by production stores (spec T13).
    case syntheticShotRejected(UUID)
    case storageFailure(String)
    /// The file is not a readable database. It is left untouched; nothing is re-created over it.
    case corrupt(String)
    /// The database was written by a newer app version; it is not modified.
    case schemaTooNew(found: Int, supported: Int)
}

/// Proof that an accepted shot and its ledger entry are durable. Feedback may be presented only after one of these exists.
public struct DurableReceipt: Sendable, Equatable {
    public let shotID: UUID
    public let ledgerEntry: LedgerEntry
    /// True when this commit was a retry of an already-committed shot; no second shot or credit was created.
    public let wasAlreadyCommitted: Bool

    public init(shotID: UUID, ledgerEntry: LedgerEntry, wasAlreadyCommitted: Bool) {
        self.shotID = shotID
        self.ledgerEntry = ledgerEntry
        self.wasAlreadyCommitted = wasAlreadyCommitted
    }
}

public protocol SessionRepository: Sendable {
    func save(_ session: Session) async throws
    func session(id: UUID) async throws -> Session?
    /// Newest first.
    func sessions() async throws -> [Session]
    /// Removes the session and its shots. Ledger entries are kept: usage history is separate from deletable history.
    func deleteSession(id: UUID) async throws
}

public protocol CalibrationRepository: Sendable {
    func save(_ calibration: CalibrationRecord) async throws
    func calibration(id: UUID) async throws -> CalibrationRecord?
}

public protocol ShotRepository: Sendable {
    /// Atomic and idempotent (spec section 6): the shot and its ledger entry are stored together or not at all.
    /// Retrying the same shot returns the original receipt with `wasAlreadyCommitted == true`.
    func commitAccepted(_ shot: Shot, ledger: LedgerEntry) async throws -> DurableReceipt
    func shot(id: UUID) async throws -> Shot?
    /// Ordered by sequence.
    func shots(sessionID: UUID) async throws -> [Shot]
    /// Exclude/restore. The shot stays stored; aggregates must filter on `included`.
    @discardableResult
    func setIncluded(shotID: UUID, included: Bool) async throws -> Shot
    /// Hard delete. The ledger entry is deliberately kept.
    func deleteShot(id: UUID) async throws
}

public protocol LedgerRepository: Sendable {
    func entries() async throws -> [LedgerEntry]
    func entry(forShot shotID: UUID) async throws -> LedgerEntry?
    /// Sum of credit cost for one allowance kind.
    func creditsSpent(kind: AllowanceKind) async throws -> Int
}

/// Everything the app needs from persistence in one type (the in-memory fake and the SQLite store both conform).
public typealias PersistenceStore = CalibrationRepository & LedgerRepository & SessionRepository & ShotRepository
