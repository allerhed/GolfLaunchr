import Foundation

/// What happened when a frame timestamp was ingested. Timing is judged from presentation timestamps, never assumed from nominal fps (F04).
public enum FrameEvent: Equatable, Sendable {
    case first
    case ok
    /// Interval differs from nominal by more than the tolerance but is not a missing frame.
    case jitter(ratio: Double)
    /// One or more frames are missing: interval is at least 1.5x nominal.
    case gap(missingFrames: Int)
    /// Timestamp did not advance. The frame is not accepted as the new reference.
    case nonMonotonic
}

public struct FrameClockStats: Equatable, Sendable {
    public var framesSeen = 0
    public var intervals = 0
    public var intervalsWithinTolerance = 0
    public var gapEvents = 0
    public var missingFrames = 0
    public var jitterEvents = 0
    public var nonMonotonicEvents = 0
    public var maxIntervalRatio = 0.0

    /// Fraction of intervals within tolerance (criterion P1). nil with no intervals: unknown, not 100%.
    public var fractionWithinTolerance: Double? {
        intervals == 0 ? nil : Double(intervalsWithinTolerance) / Double(intervals)
    }
}

/// Tracks frame pacing from PTS values.
public struct FrameClock: Sendable {
    public let nominalFrameRate: Double
    /// Allowed deviation from the nominal interval (0.10 = +/-10%).
    public let tolerance: Double
    public private(set) var stats = FrameClockStats()
    private var lastPTS: Double?

    public init(nominalFrameRate: Double, tolerance: Double = 0.10) {
        precondition(nominalFrameRate > 0 && tolerance > 0, "invalid clock configuration")
        self.nominalFrameRate = nominalFrameRate
        self.tolerance = tolerance
    }

    public var nominalInterval: Double {
        1 / nominalFrameRate
    }

    @discardableResult
    public mutating func ingest(pts: Double) -> FrameEvent {
        stats.framesSeen += 1
        guard let last = lastPTS else {
            lastPTS = pts
            return .first
        }
        let interval = pts - last
        guard interval > 0, interval.isFinite else {
            stats.nonMonotonicEvents += 1
            return .nonMonotonic
        }
        lastPTS = pts
        stats.intervals += 1
        let ratio = interval / nominalInterval
        stats.maxIntervalRatio = max(stats.maxIntervalRatio, ratio)
        if ratio >= 1.5 {
            let missing = Int(ratio.rounded()) - 1
            stats.gapEvents += 1
            stats.missingFrames += missing
            return .gap(missingFrames: missing)
        }
        if abs(ratio - 1) > tolerance {
            stats.jitterEvents += 1
            return .jitter(ratio: ratio)
        }
        stats.intervalsWithinTolerance += 1
        return .ok
    }
}

public enum DroppedFrameReason: String, Codable, Sendable, CaseIterable {
    case frameWasLate, outOfBuffers, discontinuity, unknown
}

public struct DropEvent: Codable, Sendable, Equatable {
    /// Capture-clock time of the newest frame when the drop was reported. Drops carry no timestamp of their own.
    public let time: Double
    public let reason: DroppedFrameReason
}

/// Dropped frames are counted by reason and are never counted as captured frames.
/// Events keep a time so a clip can report only the drops inside its own window (a run total would mislead).
public struct DroppedFrameLog: Equatable, Sendable {
    public static let maxEvents = 20000
    public private(set) var countsByReason: [DroppedFrameReason: Int] = [:]
    public private(set) var events: [DropEvent] = []

    public init() {}

    public mutating func record(_ reason: DroppedFrameReason, at time: Double? = nil) {
        countsByReason[reason, default: 0] += 1
        if let time {
            events.append(DropEvent(time: time, reason: reason))
            if events.count > Self.maxEvents {
                events.removeFirst(events.count - Self.maxEvents)
            }
        }
    }

    public var total: Int {
        countsByReason.values.reduce(0, +)
    }

    /// Only the drops reported while the capture clock was within [from, to].
    public func within(from: Double, to: Double) -> DroppedFrameLog {
        var log = DroppedFrameLog()
        for event in events where event.time >= from && event.time <= to {
            log.record(event.reason, at: event.time)
        }
        return log
    }
}
