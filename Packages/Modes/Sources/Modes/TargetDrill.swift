import Domain
import Foundation

public enum DrillBasis: String, Sendable, Equatable {
    /// Scored on the distance tolerance only. Always shown as "Distance only".
    case distanceOnly
    /// Scored on distance and sideways tolerance together.
    case distanceAndLateral
}

/// One scored attempt. Errors are signed: long is positive, short negative, right positive, left negative.
public struct DrillAttempt: Sendable, Equatable {
    public let shotID: UUID
    /// 1-based position among scored attempts.
    public let number: Int
    public let carryM: Double
    public let longitudinalErrorM: Double
    /// Nil unless this attempt was scored with validated lateral data.
    public let lateralErrorM: Double?
    public let isHit: Bool
    public let basis: DrillBasis
    /// The measurement's own 95% half-width. Result accuracy, never mixed into the target tolerance.
    public let carryUncertainty95M: Double?
}

public struct TargetDrillResult: Sendable, Equatable {
    public let config: TargetDrillConfig
    public let attempts: [DrillAttempt]
    /// Accepted, included shots of the allowed clubs that carry no usable carry: they never advance the attempt count.
    public let unscoredShotCount: Int
    /// Shots with a club the drill does not count.
    public let otherClubShotCount: Int
    /// Usable shots taken after the drill was already complete.
    public let extraShotCount: Int

    public var scoredCount: Int {
        attempts.count
    }

    public var hits: Int {
        attempts.filter(\.isHit).count
    }

    public var misses: Int {
        scoredCount - hits
    }

    public var isComplete: Bool {
        scoredCount >= config.attempts
    }

    public var hitRate: Double? {
        scoredCount == 0 ? nil : Double(hits) / Double(scoredCount)
    }

    public var currentStreak: Int {
        var n = 0
        for a in attempts.reversed() {
            if a.isHit {
                n += 1
            } else {
                break
            }
        }
        return n
    }

    public var bestStreak: Int {
        var best = 0, run = 0
        for a in attempts {
            run = a.isHit ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    /// Attempts that missed short: the error is beyond the tolerance on the short side. A hit is never counted as short or long.
    public var shortCount: Int {
        attempts.filter { $0.longitudinalErrorM < -(config.longitudinalToleranceM + TargetDrill.epsilon) }.count
    }

    public var longCount: Int {
        attempts.filter { $0.longitudinalErrorM > config.longitudinalToleranceM + TargetDrill.epsilon }.count
    }

    public var leftCount: Int {
        attempts.filter { ($0.lateralErrorM ?? 0) < 0 }.count
    }

    public var rightCount: Int {
        attempts.filter { ($0.lateralErrorM ?? 0) > 0 }.count
    }

    public var meanSignedErrorM: Double? {
        attempts.isEmpty ? nil : attempts.map(\.longitudinalErrorM).reduce(0, +) / Double(scoredCount)
    }

    public var meanAbsoluteErrorM: Double? {
        attempts.isEmpty ? nil : attempts.map { abs($0.longitudinalErrorM) }.reduce(0, +) / Double(scoredCount)
    }

    /// True if any scored attempt used the distance tolerance alone: the summary then says "Distance only".
    public var isDistanceOnly: Bool {
        attempts.contains { $0.basis == .distanceOnly }
    }
}

/// F11 scoring: transparent and recomputed from the session's shots every time, so excluding a shot removes it from progress, streak
/// and result at once, and nothing is cached that could drift from the stored shots.
public enum TargetDrill {
    /// Comparison slack for unit-conversion noise only: an error exactly equal to the tolerance is a hit.
    static let epsilon = 1e-9

    public static func evaluate(config: TargetDrillConfig, shots: [Shot], lateralValidated: Bool) -> TargetDrillResult {
        var attempts: [DrillAttempt] = []
        var unscored = 0, otherClub = 0, extra = 0
        for shot in shots.sorted(by: { $0.sequence < $1.sequence }) where shot.included {
            if let allowed = config.clubIDs, !allowed.contains(shot.clubSnapshot.id) {
                otherClub += 1
                continue
            }
            guard let carry = usableValue(shot.metrics[.carry]) else {
                unscored += 1
                continue
            }
            if attempts.count >= config.attempts {
                extra += 1
                continue
            }
            let longitudinal = carry - config.targetCarryM
            let distanceOK = abs(longitudinal) <= config.longitudinalToleranceM + epsilon
            var lateral: Double?
            var basis = DrillBasis.distanceOnly
            var hit = distanceOK
            if lateralValidated, let tolerance = config.lateralToleranceM, let side = usableValue(shot.metrics[.lateralLanding]) {
                lateral = side
                basis = .distanceAndLateral
                hit = distanceOK && abs(side) <= tolerance + epsilon
            }
            attempts.append(DrillAttempt(
                shotID: shot.id, number: attempts.count + 1, carryM: carry, longitudinalErrorM: longitudinal, lateralErrorM: lateral,
                isHit: hit, basis: basis, carryUncertainty95M: shot.metrics[.carry]?.uncertainty95
            ))
        }
        return TargetDrillResult(
            config: config, attempts: attempts, unscoredShotCount: unscored, otherClubShotCount: otherClub, extraShotCount: extra
        )
    }

    /// A figure counts only if it exists and the pipeline did not mark it invalid or unsupported. Unknown is never zero.
    private static func usableValue(_ measurement: Domain.Measurement?) -> Double? {
        guard let measurement, measurement.provenance != .unavailable, measurement.quality != .invalid,
              measurement.quality != .unsupported, let value = measurement.value, value.isFinite else { return nil }
        return value
    }
}
