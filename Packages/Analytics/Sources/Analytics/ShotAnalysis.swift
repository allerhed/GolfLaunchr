import Domain
import Foundation

/// Which clubs an analysis covers. `all` means every eligible club in scope; choosing clubs replaces it (spec F10a).
public enum ClubSelection: Equatable, Sendable, Codable {
    case all
    case some(Set<UUID>)

    /// A visible empty selection: Apply is disabled until at least one club or All clubs is chosen.
    public var isEmpty: Bool {
        if case let .some(ids) = self {
            return ids.isEmpty
        }
        return false
    }

    public func contains(_ id: UUID) -> Bool {
        switch self {
        case .all: true
        case let .some(ids): ids.contains(id)
        }
    }

    private enum CodingKeys: String, CodingKey { case all, ids }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if try c.decodeIfPresent(Bool.self, forKey: .all) == true {
            self = .all
        } else {
            self = try .some(Set(c.decode([UUID].self, forKey: .ids)))
        }
    }

    /// Ids are written sorted so the stored text is stable.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all: try c.encode(true, forKey: .all)
        case let .some(ids): try c.encode(ids.map(\.uuidString).sorted().compactMap { UUID(uuidString: $0) }, forKey: .ids)
        }
    }

    /// Toggling a club while on All starts a specific selection with just that club; clearing the last club leaves it empty.
    public func toggling(_ id: UUID) -> ClubSelection {
        switch self {
        case .all: return ClubSelection.some([id])
        case var .some(ids):
            if !ids.insert(id).inserted {
                ids.remove(id)
            }
            return .some(ids)
        }
    }
}

public enum InclusionState: String, Sendable, CaseIterable, Codable {
    case included, excluded, all
}

public enum DistanceKind: String, Sendable, CaseIterable, Codable {
    case carry, total

    public var key: MetricKey {
        self == .carry ? .carry : .totalDistance
    }
}

public enum ConditionsView: String, Sendable, CaseIterable, Codable {
    case asRecorded, standardised
}

/// The one data selection shared by shot list, averages, gapping and dispersion (F10a). Clubs combine by OR, all other
/// categories by AND. Defaults: all clubs, all sessions in scope, included shots, carry, as recorded.
public struct AnalysisFilter: Equatable, Sendable, Codable {
    public var clubs = ClubSelection.all
    /// nil = every session; otherwise only these (the "current session" scope is one id).
    public var sessionIDs: Set<UUID>?
    public var range = TimeRange.allTime
    public var mode: ShotMode?
    public var inclusion = InclusionState.included
    public var distance = DistanceKind.carry
    public var conditions = ConditionsView.asRecorded

    public init() {}

    /// Apply needs a non-empty club selection.
    public var canApply: Bool {
        !clubs.isEmpty
    }
}

/// Draft/Apply/Cancel: edits go to `draft`; `apply` commits atomically only if valid, `cancel` restores the applied filter.
public struct AnalysisFilterEditor: Equatable, Sendable {
    public private(set) var applied: AnalysisFilter
    public var draft: AnalysisFilter

    public init(applied: AnalysisFilter = AnalysisFilter()) {
        self.applied = applied
        draft = applied
    }

    @discardableResult
    public mutating func apply() -> Bool {
        guard draft.canApply else { return false }
        applied = draft
        return true
    }

    public mutating func cancel() {
        draft = applied
    }

    /// Clear restores the defaults in the draft; the person still presses Apply.
    public mutating func clear() {
        draft = AnalysisFilter()
    }
}

/// A conditions-standardisation function: nil = this shot cannot be standardised. None exists yet (no validated flight model),
/// so the Standardised view reports zero coverage instead of showing recorded numbers under the wrong label.
public typealias Standardiser = @Sendable (Shot, MetricKey) -> Double?

/// Shots that pass a filter, plus how many were dropped only because standardisation was not possible.
public struct Selection: Sendable {
    public let shots: [Shot]
    public let notStandardisable: Int

    public var ids: [UUID] {
        shots.map(\.id)
    }
}

public enum ShotSelection {
    public static func select(_ shots: [Shot], filter: AnalysisFilter, now: Date, standardiser _: Standardiser? = nil) -> Selection {
        let cutoff = filter.range.cutoff(now: now)
        let passed = shots.filter { shot in
            guard filter.clubs.contains(shot.clubSnapshot.id) else { return false }
            if let sessions = filter.sessionIDs, !sessions.contains(shot.sessionID) {
                return false
            }
            if let cutoff, shot.impactTimeUTC < cutoff {
                return false
            }
            if let mode = filter.mode, shot.mode != mode {
                return false
            }
            switch filter.inclusion {
            case .included: return shot.included
            case .excluded: return !shot.included
            case .all: return true
            }
        }
        .sorted { ($0.impactTimeUTC, $0.sequence) < ($1.impactTimeUTC, $1.sequence) }
        return Selection(shots: passed, notStandardisable: 0)
    }

    /// The value of `key` a shot contributes under `view`, or nil. Never 0 for a missing value.
    public static func value(_ key: MetricKey, of shot: Shot, view: ConditionsView, standardiser: Standardiser?) -> Double? {
        switch view {
        case .asRecorded:
            return SessionSummaries.usable(key, in: [shot]).first
        case .standardised:
            guard let standardiser, let v = standardiser(shot, key), v.isFinite else { return nil }
            return v
        }
    }
}

/// Everything shown for one metric of one club: provenance is carried through, coverage is explicit.
public struct MetricProfile: Equatable, Sendable {
    public let key: MetricKey
    public let validSamples: Int
    public let mean: Double?
    /// True if the contributing measurements were estimated (carry), so the mean is labelled Estimated.
    public let isEstimated: Bool
}

public struct ClubProfile: Equatable, Sendable, Identifiable {
    public var id: UUID {
        clubID
    }

    public let clubID: UUID
    /// Name as last recorded by a shot of this club.
    public let name: String
    public let shotCount: Int
    public let distanceSamples: Int
    public let mean: Double?
    public let median: Double?
    public let p10: Double?
    public let p90: Double?
    /// Sample SD (n-1); nil below two valid samples.
    public let spread: Double?
    public let shortest: Double?
    public let longest: Double?
    /// Fewer than ten eligible distance samples: a product default, not a statistical guarantee.
    public var isProvisional: Bool {
        distanceSamples < ClubAnalysis.provisionalBelow
    }

    public let lateralMean: Double?
    public let lateralSpread: Double?
    public let lateralSamples: Int
    public let metrics: [MetricProfile]
    public let shotIDs: [UUID]
}

public enum ClubAnalysis {
    public static let provisionalBelow = 10
    static let averagedMetrics: [MetricKey] = [
        .ballSpeed,
        .clubSpeed,
        .verticalLaunch,
        .horizontalLaunch,
        .spinRate,
        .spinAxis,
        .apex,
        .smashFactor,
        .attackAngle,
        .dynamicLoft
    ]

    /// One profile per club in the selection, ordered by `bagOrder` (clubs outside it follow, by first use). Aggregates come from
    /// the eligible shots themselves, never from an average of session averages.
    public static func profiles(
        _ selection: [Shot],
        filter: AnalysisFilter,
        bagOrder: [UUID] = [],
        standardiser: Standardiser? = nil
    ) -> [ClubProfile] {
        var byClub: [UUID: [Shot]] = [:]
        var firstUse: [UUID] = []
        for shot in selection {
            if byClub[shot.clubSnapshot.id] == nil {
                firstUse.append(shot.clubSnapshot.id)
            }
            byClub[shot.clubSnapshot.id, default: []].append(shot)
        }
        let rank = Dictionary(uniqueKeysWithValues: bagOrder.enumerated().map { ($1, $0) })
        let order = firstUse.enumerated().sorted { a, b in
            switch (rank[a.element], rank[b.element]) {
            case let (x?, y?): x < y
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): a.offset < b.offset
            }
        }.map(\.element)
        return order.compactMap { id in
            byClub[id].map { profile(clubID: id, shots: $0, filter: filter, standardiser: standardiser) }
        }
    }

    static func profile(clubID: UUID, shots: [Shot], filter: AnalysisFilter, standardiser: Standardiser?) -> ClubProfile {
        let view = filter.conditions
        func values(_ key: MetricKey) -> [Double] {
            shots.compactMap { ShotSelection.value(key, of: $0, view: view, standardiser: standardiser) }
        }
        let distance = values(filter.distance.key)
        let lateral = values(.lateralLanding)
        let name = shots.max { $0.impactTimeUTC < $1.impactTimeUTC }?.clubSnapshot.name ?? ""
        let metrics = averagedMetrics.map { key -> MetricProfile in
            let v = values(key)
            let estimated = shots.contains { $0.metrics[key]?.provenance == .estimated }
            return MetricProfile(key: key, validSamples: v.count, mean: Statistics.mean(v), isEstimated: estimated)
        }
        return ClubProfile(
            clubID: clubID, name: name, shotCount: shots.count, distanceSamples: distance.count,
            mean: Statistics.mean(distance), median: Statistics.median(distance),
            p10: Statistics.quantile(distance, 0.1), p90: Statistics.quantile(distance, 0.9),
            spread: Statistics.sampleStandardDeviation(distance), shortest: distance.min(), longest: distance.max(),
            lateralMean: Statistics.mean(lateral), lateralSpread: Statistics.sampleStandardDeviation(lateral),
            lateralSamples: lateral.count, metrics: metrics, shotIDs: shots.map(\.id)
        )
    }
}

/// How one shot compares with its club's mean under the active filter (F10a shot detail).
public struct ShotComparison: Equatable, Sendable {
    public let shotValue: Double
    public let clubMean: Double
    public let sampleCount: Int
    public let shotIsIncluded: Bool
    public var delta: Double {
        shotValue - clubMean
    }
}

public enum ShotCompare {
    /// nil when the shot has no comparable value or the club has no baseline. The baseline is the profile's eligible shots,
    /// so it contains the shot itself if (and only if) the shot is included, and excluding it moves the baseline.
    public static func compare(
        _ shot: Shot,
        key: MetricKey,
        within profile: ClubProfile?,
        selection: [Shot],
        view: ConditionsView = .asRecorded,
        standardiser: Standardiser? = nil
    ) -> ShotComparison? {
        guard let profile, let value = ShotSelection.value(key, of: shot, view: view, standardiser: standardiser) else { return nil }
        let members = Set(profile.shotIDs)
        let pool = selection.filter { members.contains($0.id) }
            .compactMap { ShotSelection.value(key, of: $0, view: view, standardiser: standardiser) }
        guard let mean = Statistics.mean(pool) else { return nil }
        return ShotComparison(shotValue: value, clubMean: mean, sampleCount: pool.count, shotIsIncluded: shot.included)
    }
}
