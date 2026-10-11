import Foundation

public enum SessionRecoveryState: String, Codable, Sendable {
    case active, endedCleanly, interrupted, recovered
}

/// A practice session. Club snapshots are frozen copies so later bag edits never rewrite history.
public struct Session: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let mode: ShotMode
    public let createdAt: Date
    public var endedAt: Date?
    public var clubSnapshots: [ClubSnapshot]
    /// Version of the mode configuration (drill targets, ladder steps) in force; lets drills be reconstructed.
    public let modeConfigVersion: Int
    public var recoveryState: SessionRecoveryState

    public init(
        id: UUID = UUID(),
        mode: ShotMode,
        createdAt: Date,
        endedAt: Date? = nil,
        clubSnapshots: [ClubSnapshot] = [],
        modeConfigVersion: Int = 1,
        recoveryState: SessionRecoveryState = .active
    ) throws(ContractError) {
        if let endedAt, endedAt < createdAt {
            throw .invalidDateOrder
        }
        self.id = id
        self.mode = mode
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.clubSnapshots = clubSnapshots
        self.modeConfigVersion = modeConfigVersion
        self.recoveryState = recoveryState
    }

    private enum CodingKeys: String, CodingKey { case id, mode, createdAt, endedAt, clubSnapshots, modeConfigVersion, recoveryState }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                id: c.decode(UUID.self, forKey: .id),
                mode: c.decode(ShotMode.self, forKey: .mode),
                createdAt: c.decode(Date.self, forKey: .createdAt),
                endedAt: c.decodeIfPresent(Date.self, forKey: .endedAt),
                clubSnapshots: c.decode([ClubSnapshot].self, forKey: .clubSnapshots),
                modeConfigVersion: c.decode(Int.self, forKey: .modeConfigVersion),
                recoveryState: c.decode(SessionRecoveryState.self, forKey: .recoveryState)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }
}
