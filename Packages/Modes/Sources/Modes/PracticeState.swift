import Domain
import Foundation

public enum PracticeMode: String, Sendable {
    case standard, quickShot, target
}

public enum PracticeStatus: String, Sendable {
    case active, paused, ended
}

public enum ArmBlock: String, Sendable {
    case notActive, noClub, setupNotReady, noAllowance
}

public enum ArmResult: Equatable, Sendable {
    case armed
    case blocked(ArmBlock)
}

public enum AcceptRejection: String, Sendable {
    case notArmed, wrongSession, badSequence, clubMismatch
}

public enum AcceptResult: Equatable, Sendable {
    case accepted
    case rejected(AcceptRejection)
}

public enum EndOutcome: Equatable, Sendable {
    case ended(shotCount: Int)
    /// A second End (double tap) does nothing: the session is already closed.
    case alreadyEnded
}

/// One practice session (Standard Practice or QuickShot, F05). Pure state: no camera, no storage. The app feeds it accepted shots.
/// Safeguards are identical for both modes: QuickShot only starts from the last-used club, it never skips the setup checks.
public struct PracticeState: Equatable, Sendable {
    public let sessionID: UUID
    public let mode: PracticeMode
    public private(set) var status = PracticeStatus.active
    /// What the golfer has selected; applies to the NEXT armed shot.
    public private(set) var selectedClub: ClubSnapshot?
    /// The club frozen when the current shot was armed.
    public private(set) var armedClub: ClubSnapshot?
    public private(set) var targetCarryM: Double?
    public var shotGoal: Int?
    public private(set) var shots: [Shot] = []
    /// The target each accepted shot was armed against (nil = no target). Later target changes never rewrite these.
    public private(set) var targetSnapshots: [Double?] = []
    private var armedTarget: Double?

    public init(sessionID: UUID, mode: PracticeMode, selectedClub: ClubSnapshot?) {
        self.sessionID = sessionID
        self.mode = mode
        self.selectedClub = selectedClub
    }

    public var isArmed: Bool {
        armedClub != nil
    }

    public var goalReached: Bool {
        shotGoal.map { shots.count >= $0 } ?? false
    }

    public mutating func selectClub(_ club: ClubSnapshot) {
        guard status != .ended else { return }
        selectedClub = club // an armed shot keeps its own club
    }

    public mutating func setTargetCarry(_ metres: Double?) {
        guard status != .ended else { return }
        targetCarryM = metres.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    /// `allowanceAvailable` is the F19 reservation made for this shot; with none left nothing arms (the golfer is offered
    /// history/settings).
    public mutating func arm(setupReady: Bool, allowanceAvailable: Bool = true) -> ArmResult {
        guard status == .active else { return .blocked(.notActive) }
        guard let club = selectedClub else { return .blocked(.noClub) }
        guard setupReady else { return .blocked(.setupNotReady) }
        guard allowanceAvailable else { return .blocked(.noAllowance) }
        armedClub = club
        armedTarget = targetCarryM
        return .armed
    }

    public mutating func accept(_ shot: Shot) -> AcceptResult {
        guard let club = armedClub, status == .active else { return .rejected(.notArmed) }
        guard shot.sessionID == sessionID else { return .rejected(.wrongSession) }
        guard shot.sequence == shots.count + 1 else { return .rejected(.badSequence) }
        guard shot.clubSnapshot == club else { return .rejected(.clubMismatch) }
        shots.append(shot)
        targetSnapshots.append(armedTarget)
        armedClub = nil
        armedTarget = nil
        return .accepted
    }

    public mutating func pause() {
        guard status == .active else { return }
        status = .paused
        armedClub = nil // pausing disarms: nothing is captured while paused
        armedTarget = nil
    }

    public mutating func resume() {
        if status == .paused {
            status = .active
        }
    }

    public mutating func end() -> EndOutcome {
        guard status != .ended else { return .alreadyEnded }
        status = .ended
        armedClub = nil
        armedTarget = nil
        return .ended(shotCount: shots.count)
    }
}
