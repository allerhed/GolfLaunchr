import Domain
import Foundation

public struct ClubGapRow: Equatable, Sendable, Identifiable {
    public var id: UUID {
        clubID
    }

    public let clubID: UUID
    public let name: String
    public let meanM: Double?
    public let sampleCount: Int
    public let isProvisional: Bool
    /// mean(this) - mean(next) from unrounded means; signed (negative = the next club is longer). nil for the last row,
    /// or when either side has no data (never bridged).
    public let gapToNextM: Double?
}

public struct ClubGapTable: Equatable, Sendable {
    public let rows: [ClubGapRow]
    public let distance: DistanceKind
    /// True when fewer clubs than the bag's eligible clubs are compared: missing clubs can make gaps look larger.
    public let selectedClubsOnly: Bool
    /// Shots of different recorded conditions are mixed (As recorded view).
    public let mixedConditions: Bool
}

public enum ClubGapping {
    /// Gap table over the profiles in the order given (bag order). Never sorts, never merges clubs, never mixes carry and total.
    public static func table(_ profiles: [ClubProfile], filter: AnalysisFilter, eligibleClubCount: Int, mixedConditions: Bool = false)
        -> ClubGapTable {
        let rows = profiles.enumerated().map { index, profile -> ClubGapRow in
            var gap: Double?
            if index + 1 < profiles.count, let a = profile.mean, let b = profiles[index + 1].mean {
                gap = a - b
            }
            return ClubGapRow(
                clubID: profile.clubID, name: profile.name, meanM: profile.mean, sampleCount: profile.distanceSamples,
                isProvisional: profile.isProvisional, gapToNextM: gap
            )
        }
        return ClubGapTable(
            rows: rows, distance: filter.distance, selectedClubsOnly: profiles.count < eligibleClubCount,
            mixedConditions: mixedConditions
        )
    }

    /// True if the shots were recorded under more than one environment source/pressure/temperature.
    public static func hasMixedConditions(_ shots: [Shot]) -> Bool {
        Set(shots.map { "\($0.environment.pressurePa)|\($0.environment.temperatureK)|\($0.environment.source.rawValue)" }).count > 1
    }
}
