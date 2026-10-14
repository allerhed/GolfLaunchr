import Foundation

/// Target drill settings (F11), stored with the session so history keeps the original configuration. SI units. Defaults are the
/// spec defaults (100 m, +-5 m, ten attempts); a golfer's own choices are never replaced by them.
public struct TargetDrillConfig: Codable, Sendable, Equatable {
    public static let defaultTargetM = 100.0
    public static let defaultLongitudinalToleranceM = 5.0
    public static let defaultAttempts = 10
    public static let targetRangeM = 5.0 ... 400.0
    public static let attemptRange = 1 ... 100

    public let targetCarryM: Double
    /// Allowed distance error either side of the target.
    public let longitudinalToleranceM: Double
    /// Allowed sideways error either side of the line. Used only when lateral data is validated; nil = not asked for.
    public let lateralToleranceM: Double?
    /// Attempts that count. Unscored shots do not advance this.
    public let attempts: Int
    /// Only these clubs count; nil = every club.
    public let clubIDs: Set<UUID>?

    public init(
        targetCarryM: Double = defaultTargetM,
        longitudinalToleranceM: Double = defaultLongitudinalToleranceM,
        lateralToleranceM: Double? = nil,
        attempts: Int = defaultAttempts,
        clubIDs: Set<UUID>? = nil
    ) throws(ContractError) {
        guard targetCarryM.isFinite, Self.targetRangeM.contains(targetCarryM) else { throw .invalidDrillConfig("target") }
        guard longitudinalToleranceM.isFinite, longitudinalToleranceM > 0, longitudinalToleranceM <= targetCarryM else {
            throw .invalidDrillConfig("longitudinalTolerance")
        }
        if let lateralToleranceM {
            guard lateralToleranceM.isFinite, lateralToleranceM > 0, lateralToleranceM <= 100 else {
                throw .invalidDrillConfig("lateralTolerance")
            }
        }
        guard Self.attemptRange.contains(attempts) else { throw .invalidDrillConfig("attempts") }
        if let clubIDs, clubIDs.isEmpty {
            throw .invalidDrillConfig("clubs")
        }
        self.targetCarryM = targetCarryM
        self.longitudinalToleranceM = longitudinalToleranceM
        self.lateralToleranceM = lateralToleranceM
        self.attempts = attempts
        self.clubIDs = clubIDs
    }

    private enum CodingKeys: String, CodingKey {
        case targetCarryM, longitudinalToleranceM, lateralToleranceM, attempts, clubIDs
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                targetCarryM: c.decode(Double.self, forKey: .targetCarryM),
                longitudinalToleranceM: c.decode(Double.self, forKey: .longitudinalToleranceM),
                lateralToleranceM: c.decodeIfPresent(Double.self, forKey: .lateralToleranceM),
                attempts: c.decode(Int.self, forKey: .attempts),
                clubIDs: c.decodeIfPresent(Set<UUID>.self, forKey: .clubIDs)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }
}
