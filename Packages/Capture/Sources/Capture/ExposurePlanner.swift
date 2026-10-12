import Foundation

/// A fixed exposure chosen to match the scene brightness the camera measured in auto mode.
public struct ExposurePlan: Equatable, Sendable {
    public let durationSeconds: Double
    public let iso: Double
    /// True when the duration had to move to fit the format's supported range.
    public let durationAdjusted: Bool
    /// True when the ISO needed for the same brightness exceeds the camera's maximum.
    public let isoClamped: Bool
    /// How many stops darker than auto the result is (0 when the full brightness could be matched).
    public let evShortfallStops: Double
}

/// Plans a fixed short exposure (G1 plan section 3, exposure factor): keep scene brightness by trading duration for ISO,
/// and say honestly how much light is missing when ISO runs out.
public enum ExposurePlanner {
    public static func plan(
        autoDuration: Double,
        autoISO: Double,
        targetDuration: Double,
        isoRange: ClosedRange<Double>,
        durationRange: ClosedRange<Double>
    ) -> ExposurePlan? {
        guard autoDuration > 0, autoISO > 0, targetDuration > 0, autoDuration.isFinite, autoISO.isFinite else { return nil }
        let duration = min(max(targetDuration, durationRange.lowerBound), durationRange.upperBound)
        let wantedISO = autoISO * autoDuration / duration
        let iso = min(max(wantedISO, isoRange.lowerBound), isoRange.upperBound)
        let shortfall = wantedISO > iso ? log2(wantedISO / iso) : 0
        // Brightness is duration x ISO: if ISO is clamped low (very bright scene) brightness is higher than auto, not lower.
        return ExposurePlan(
            durationSeconds: duration, iso: iso, durationAdjusted: duration != targetDuration,
            isoClamped: wantedISO > isoRange.upperBound, evShortfallStops: shortfall
        )
    }
}
