import Domain

public struct ClubDistances: Equatable, Sendable {
    public let clubID: String
    public let distancesM: [Double?] // SI metres; nil = no value
    public init(clubID: String, distancesM: [Double?]) {
        self.clubID = clubID; self.distancesM = distancesM
    }
}

public struct GapRow: Equatable, Sendable {
    public let clubID: String
    public let meanM: Double? // nil = No data
    public let sampleCount: Int
    public let isProvisional: Bool // < 10 eligible samples
    /// mean(this) - mean(next), signed, from unrounded means. nil for the last row or when either side has no data.
    public let gapToNextM: Double?
}

/// Gap table per spec F10a: bag order preserved, never sorted, no bridging across No-data rows.
public enum Gapping {
    public static func table(_ clubs: [ClubDistances]) -> [GapRow] {
        let means = clubs.map { Statistics.mean(Statistics.clean($0.distancesM)) }
        return clubs.enumerated().map { i, c in
            let n = Statistics.clean(c.distancesM).count
            var gap: Double?
            if i + 1 < clubs.count, let a = means[i], let b = means[i + 1] {
                gap = a - b
            }
            return GapRow(clubID: c.clubID, meanM: means[i], sampleCount: n, isProvisional: n < 10, gapToNextM: gap)
        }
    }
}
