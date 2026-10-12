import Domain
import Foundation
import Persistence

/// Where a simulated crash/failure interrupts `commitAccepted`.
public enum FaultPoint: Sendable {
    case afterShotStaged
    case afterLedgerStaged
}

/// In-memory fake of every repository protocol, for tests and previews only. Real store arrives in plan item 2.1.
/// Mutations are staged on a copy and published in one assignment, so a failure leaves nothing half-written.
public actor InMemoryStore: SessionRepository, CalibrationRepository, ShotRepository, LedgerRepository, ClubRepository {
    private struct State {
        var sessions: [UUID: Session] = [:]
        var calibrations: [UUID: CalibrationRecord] = [:]
        var shots: [UUID: Shot] = [:]
        var ledger: [UUID: LedgerEntry] = [:]
        var bag: Bag?
    }

    private var state = State()
    private var pendingFault: FaultPoint?
    private let allowsSynthetic: Bool

    /// - Parameter allowsSynthetic: tests that use the synthetic spec fixture opt in; production stores must keep `false` (T13).
    public init(allowsSynthetic: Bool = false) {
        self.allowsSynthetic = allowsSynthetic
    }

    /// Makes the next `commitAccepted` fail at `point`, once.
    public func armFault(_ point: FaultPoint?) {
        pendingFault = point
    }

    private func trip(_ point: FaultPoint) throws {
        if pendingFault == point {
            pendingFault = nil
            throw PersistenceError.storageFailure("injected fault \(point)")
        }
    }

    // MARK: SessionRepository

    public func save(_ session: Session) {
        state.sessions[session.id] = session
    }

    public func session(id: UUID) -> Session? {
        state.sessions[id]
    }

    public func sessions() -> [Session] {
        state.sessions.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func deleteSession(id: UUID) throws {
        guard state.sessions[id] != nil else { throw PersistenceError.notFound("session \(id)") }
        state.sessions[id] = nil
        state.shots = state.shots.filter { $0.value.sessionID != id }
    }

    // MARK: CalibrationRepository

    public func save(_ calibration: CalibrationRecord) {
        state.calibrations[calibration.id] = calibration
    }

    public func calibration(id: UUID) -> CalibrationRecord? {
        state.calibrations[id]
    }

    // MARK: ShotRepository

    public func commitAccepted(_ shot: Shot, ledger: LedgerEntry) throws -> DurableReceipt {
        if let existing = state.shots[shot.id] {
            guard existing == shot, let stored = state.ledger[shot.id], stored == ledger else {
                throw PersistenceError.conflictingDuplicate(shot.id)
            }
            return DurableReceipt(shotID: shot.id, ledgerEntry: stored, wasAlreadyCommitted: true)
        }
        if shot.isSynthetic, !allowsSynthetic {
            throw PersistenceError.syntheticShotRejected(shot.id)
        }
        guard ledger.acceptedShotID == shot.id else { throw PersistenceError.ledgerMismatch }
        guard state.sessions[shot.sessionID] != nil else { throw PersistenceError.unknownSession(shot.sessionID) }
        guard state.calibrations[shot.calibrationID] != nil else { throw PersistenceError.unknownCalibration(shot.calibrationID) }
        let sequenceTaken = state.shots.values.contains { $0.sessionID == shot.sessionID && $0.sequence == shot.sequence }
        guard !sequenceTaken else { throw PersistenceError.duplicateSequence(sessionID: shot.sessionID, sequence: shot.sequence) }

        var staged = state
        staged.shots[shot.id] = shot
        try trip(.afterShotStaged)
        staged.ledger[shot.id] = ledger
        try trip(.afterLedgerStaged)
        state = staged // single publish: both rows or neither
        return DurableReceipt(shotID: shot.id, ledgerEntry: ledger, wasAlreadyCommitted: false)
    }

    public func shot(id: UUID) -> Shot? {
        state.shots[id]
    }

    public func shots(sessionID: UUID) -> [Shot] {
        state.shots.values.filter { $0.sessionID == sessionID }.sorted { $0.sequence < $1.sequence }
    }

    @discardableResult
    public func setIncluded(shotID: UUID, included: Bool) throws -> Shot {
        guard var shot = state.shots[shotID] else { throw PersistenceError.notFound("shot \(shotID)") }
        shot.included = included
        state.shots[shotID] = shot
        return shot
    }

    public func deleteShot(id: UUID) throws {
        guard state.shots[id] != nil else { throw PersistenceError.notFound("shot \(id)") }
        state.shots[id] = nil // ledger entry stays
    }

    // MARK: ClubRepository

    public func loadBag() -> Bag? {
        state.bag
    }

    public func saveBag(_ bag: Bag) {
        state.bag = bag
    }

    // MARK: LedgerRepository

    public func entries() -> [LedgerEntry] {
        state.ledger.values.sorted { $0.committedAt < $1.committedAt }
    }

    public func entry(forShot shotID: UUID) -> LedgerEntry? {
        state.ledger[shotID]
    }

    public func creditsSpent(kind: AllowanceKind) -> Int {
        state.ledger.values.filter { $0.allowanceKind == kind }.reduce(0) { $0 + $1.creditCost }
    }
}
