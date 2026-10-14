import Domain
import Foundation
import Persistence

public enum FinishOutcome: Equatable, Sendable {
    case closed, alreadyClosed, discardedEmpty
}

public struct RecoveryReport: Equatable, Sendable {
    public let recovered: [UUID]
    public let discarded: [UUID]
}

/// Saves, closes and recovers practice sessions (F05). Closing is idempotent, and a session that never produced a shot is not kept,
/// so history never shows an empty session with misleading averages.
public struct SessionLifecycle: Sendable {
    private let sessions: any SessionRepository
    private let shots: any ShotRepository

    public init(sessions: any SessionRepository, shots: any ShotRepository) {
        self.sessions = sessions
        self.shots = shots
    }

    /// A target session stores its drill configuration with it (history keeps the original). Without one it gets the spec defaults.
    public func start(_ mode: PracticeMode, drill: TargetDrillConfig? = nil, now: Date) async throws -> Session {
        let session = switch mode {
        case .standard: try Session(mode: .practice, createdAt: now)
        case .quickShot: try Session(mode: .quickShot, createdAt: now)
        case .target: try Session(mode: .target, createdAt: now, drill: drill ?? TargetDrillConfig())
        }
        try await sessions.save(session)
        return session
    }

    public func finish(_ id: UUID, shotCount: Int, now: Date) async throws -> FinishOutcome {
        guard var session = try await sessions.session(id: id) else { return .alreadyClosed }
        if session.recoveryState != .active {
            return .alreadyClosed
        }
        if shotCount == 0, try await shots.shots(sessionID: id).isEmpty {
            try await sessions.deleteSession(id: id)
            return .discardedEmpty
        }
        session.endedAt = max(now, session.createdAt)
        session.recoveryState = .endedCleanly
        try await sessions.save(session)
        return .closed
    }

    /// Run once at launch, before any session can be live: every session still `active` was cut short.
    public func recoverInterrupted() async throws -> RecoveryReport {
        var recovered: [UUID] = [], discarded: [UUID] = []
        for var session in try await sessions.sessions() where session.recoveryState == .active {
            let stored = try await shots.shots(sessionID: session.id)
            guard let last = stored.map(\.impactTimeUTC).max() else {
                try await sessions.deleteSession(id: session.id)
                discarded.append(session.id)
                continue
            }
            session.endedAt = max(last, session.createdAt)
            session.recoveryState = .interrupted
            try await sessions.save(session)
            recovered.append(session.id)
        }
        return RecoveryReport(recovered: recovered, discarded: discarded)
    }
}
