import Domain
import Foundation

/// A session reduced to what the history list shows. Derived from stored shots on every call: never stored, so it cannot go stale.
public struct SessionSummary: Equatable, Sendable, Identifiable {
    public var id: UUID {
        sessionID
    }

    public let sessionID: UUID
    public let mode: ShotMode
    public let startedAt: Date
    /// nil while the session is open or has no end time.
    public let duration: TimeInterval?
    public let shotCount: Int
    public let includedCount: Int
    public var excludedCount: Int {
        shotCount - includedCount
    }

    /// Clubs used, in the order of their first shot (names as recorded then).
    public let clubs: [ClubSnapshot]
    /// Mean of finite, non-invalid carry values of **included** shots. nil when there are none: never 0.
    public let meanCarryMetres: Double?
    public let carrySamples: Int
    public let meanBallSpeedMetresPerSecond: Double?
    /// True if any shot is synthetic (fixture/demo data): the UI must label it.
    public let containsDemoData: Bool
    /// The target drill this session ran, as configured then. History never recomputes it from today's settings.
    public let drill: TargetDrillConfig?
}

public enum SessionSummaries {
    public static func make(session: Session, shots: [Shot]) -> SessionSummary {
        let ordered = shots.sorted { $0.sequence < $1.sequence }
        let included = ordered.filter(\.included)
        var seen = Set<UUID>()
        let clubs = ordered.compactMap { shot in seen.insert(shot.clubSnapshot.id).inserted ? shot.clubSnapshot : nil }
        let carry = usable(.carry, in: included)
        let speed = usable(.ballSpeed, in: included)
        return SessionSummary(
            sessionID: session.id, mode: session.mode, startedAt: session.createdAt,
            duration: session.endedAt.map { $0.timeIntervalSince(session.createdAt) },
            shotCount: ordered.count, includedCount: included.count, clubs: clubs,
            meanCarryMetres: Statistics.mean(carry), carrySamples: carry.count,
            meanBallSpeedMetresPerSecond: Statistics.mean(speed), containsDemoData: ordered.contains(where: \.isSynthetic),
            drill: session.drill
        )
    }

    /// Values that may enter an average: present, finite, and not marked invalid or unavailable. A failed or unknown
    /// measurement never contaminates a mean (F10).
    static func usable(_ key: MetricKey, in shots: [Shot]) -> [Double] {
        shots.compactMap { shot -> Double? in
            guard let metric = shot.metrics[key], metric.provenance != .unavailable, metric.quality != .invalid, let v = metric.value,
                  v.isFinite
            else { return nil }
            return v
        }
    }
}

public enum TimeRange: String, CaseIterable, Sendable, Codable {
    case allTime, last7Days, last30Days

    /// The earliest start time allowed, or nil for all time.
    public func cutoff(now: Date) -> Date? {
        switch self {
        case .allTime: nil
        case .last7Days: now.addingTimeInterval(-7 * 86400)
        case .last30Days: now.addingTimeInterval(-30 * 86400)
        }
    }
}

/// Date, mode and club filters (F10). Dates compare absolute instants (UTC); display is local time elsewhere.
public struct HistoryFilter: Equatable, Sendable {
    public var range = TimeRange.allTime
    public var mode: ShotMode?
    /// Keep sessions in which this club was used.
    public var clubID: UUID?

    public init(range: TimeRange = .allTime, mode: ShotMode? = nil, clubID: UUID? = nil) {
        self.range = range
        self.mode = mode
        self.clubID = clubID
    }

    public var isActive: Bool {
        range != .allTime || mode != nil || clubID != nil
    }

    public func apply(to summaries: [SessionSummary], now: Date) -> [SessionSummary] {
        let cutoff = range.cutoff(now: now)
        return summaries.filter { summary in
            if let cutoff, summary.startedAt < cutoff {
                return false
            }
            if let mode, summary.mode != mode {
                return false
            }
            if let clubID, !summary.clubs.contains(where: { $0.id == clubID }) {
                return false
            }
            return true
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    /// Distinct clubs across summaries for the club menu, most recently used first, names as last recorded.
    public static func clubOptions(from summaries: [SessionSummary]) -> [ClubSnapshot] {
        var seen = Set<UUID>()
        return summaries.sorted { $0.startedAt > $1.startedAt }.flatMap(\.clubs).filter { seen.insert($0.id).inserted }
    }
}
