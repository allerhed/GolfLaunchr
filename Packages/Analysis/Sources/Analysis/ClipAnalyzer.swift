import Capture
import Foundation

public struct TimingReport: Codable, Sendable, Equatable {
    public let frames: Int
    public let nominalFrameRate: Double
    /// Mean rate from the first to the last PTS.
    public let measuredFrameRate: Double?
    public let gapEvents: Int
    public let missingFrames: Int
    public let jitterEvents: Int
    public let nonMonotonicEvents: Int
    public let fractionWithinTolerance: Double?
    /// Frame indices (decoded order) after which frames are missing, with the number missing.
    public let gaps: [GapPosition]
    /// Container timescale the timestamps are quantised to (for example 600), when coarse: jitter figures from such a file
    /// reflect the container, not the camera. nil when timestamps are finer than every candidate timescale.
    public let quantizedTimescale: Int?
    /// Fraction of intervals within one container tick of nominal: the meaningful pacing figure for a quantised file.
    public let fractionWithinOneTick: Double?
}

public struct GapPosition: Codable, Sendable, Equatable {
    public let afterFrameIndex: Int
    public let missingFrames: Int
}

public struct LumaStats: Codable, Sendable, Equatable {
    public let mean: Double
    public let minimum: Double
    public let maximum: Double
}

public struct SharpnessStats: Codable, Sendable, Equatable {
    public let median: Double
    public let p10: Double
    public let minimum: Double
}

public struct ClipReport: Codable, Sendable, Equatable {
    public static let schema = "g1-report/1"
    public let schema: String
    public let timing: TimingReport
    public let luma: LumaStats?
    public let flicker: FlickerResult?
    public let sharpness: SharpnessStats?
    /// Frame indices where the baseline frame-difference detector fires (plan P8, informational).
    public let motionTriggerFrames: [Int]
    public let peakMotionFrame: Int?
    public let peakMotionScore: Double?
}

/// Streams decoded frames through the analyses without keeping the images (1080p240 clips are large).
public struct ClipAnalyzer: Sendable {
    public let nominalFrameRate: Double
    private var clock: FrameClock
    private var motion: MotionDetector
    private var ptsList: [Double] = []
    private var lumaSeries: [Double] = []
    private var sharpnessSeries: [Double] = []
    private var triggers: [Int] = []
    private var gaps: [GapPosition] = []
    private var peak: (index: Int, score: Double)?
    private var index = 0

    public init(nominalFrameRate: Double, motionThreshold: Double = 6, motionCooldownFrames: Int? = nil) {
        self.nominalFrameRate = nominalFrameRate
        clock = FrameClock(nominalFrameRate: nominalFrameRate)
        motion = MotionDetector(threshold: motionThreshold, cooldownFrames: motionCooldownFrames ?? Int(nominalFrameRate / 4))
    }

    /// Feeds the next decoded frame. `pts` is the presentation timestamp in seconds.
    public mutating func ingest(pts: Double, frame: LumaFrame, measureSharpness: Bool = true) {
        ptsList.append(pts)
        if case let .gap(missing) = clock.ingest(pts: pts) {
            gaps.append(GapPosition(afterFrameIndex: index - 1, missingFrames: missing))
        }
        lumaSeries.append(frame.meanLuma())
        if measureSharpness {
            sharpnessSeries.append(Sharpness.laplacianVariance(frame))
        }
        if let grid = frame.grid() {
            if motion.ingest(grid) {
                triggers.append(index)
            }
            if let score = motion.lastScore, score > (peak?.score ?? 0) {
                peak = (index, score)
            }
        }
        index += 1
    }

    private func withinOneTick(timescale: Int) -> Double? {
        guard ptsList.count > 1 else { return nil }
        let nominal = 1 / nominalFrameRate, tick = 1 / Double(timescale)
        let intervals = zip(ptsList, ptsList.dropFirst()).map { $1 - $0 }
        return Double(intervals.filter { abs($0 - nominal) <= tick + 1e-9 }.count) / Double(intervals.count)
    }

    public func report() -> ClipReport {
        let stats = clock.stats
        let quantized = PTSResolution.coarseQuantization(ptsList)
        let span = (ptsList.last ?? 0) - (ptsList.first ?? 0)
        let timing = TimingReport(
            frames: stats.framesSeen, nominalFrameRate: nominalFrameRate,
            measuredFrameRate: span > 0 ? Double(ptsList.count - 1) / span : nil,
            gapEvents: stats.gapEvents, missingFrames: stats.missingFrames, jitterEvents: stats.jitterEvents,
            nonMonotonicEvents: stats.nonMonotonicEvents, fractionWithinTolerance: stats.fractionWithinTolerance, gaps: gaps,
            quantizedTimescale: quantized, fractionWithinOneTick: quantized.flatMap { withinOneTick(timescale: $0) }
        )
        let luma = lumaSeries.isEmpty ? nil : LumaStats(
            mean: lumaSeries.reduce(0, +) / Double(lumaSeries.count), minimum: lumaSeries.min() ?? 0, maximum: lumaSeries.max() ?? 0
        )
        let sorted = sharpnessSeries.sorted()
        let sharpness = sorted.isEmpty ? nil : SharpnessStats(
            median: sorted[sorted.count / 2], p10: sorted[Int(Double(sorted.count - 1) * 0.1)], minimum: sorted[0]
        )
        return ClipReport(
            schema: ClipReport.schema, timing: timing, luma: luma, flicker: FlickerAnalyzer.analyze(
                lumaSeries,
                sampleRate: nominalFrameRate
            ),
            sharpness: sharpness, motionTriggerFrames: triggers, peakMotionFrame: peak?.index, peakMotionScore: peak?.score
        )
    }
}

/// Cross-checks a manifest written by the phone against what the decoded file really contains.
public enum ManifestConsistency {
    public static func compare(report: ClipReport, manifest: CaptureManifest) -> [String] {
        var problems: [String] = []
        let t = manifest.timing
        if report.timing.frames != t.frameCount {
            problems.append("frame count: file \(report.timing.frames), manifest \(t.frameCount)")
        }
        if report.timing.gapEvents != t
            .gapEvents {
            problems.append("gap events: file \(report.timing.gapEvents), manifest \(t.gapEvents)")
        }
        if report.timing.missingFrames != t.missingFrames {
            problems.append("missing frames: file \(report.timing.missingFrames), manifest \(t.missingFrames)")
        }
        return problems
    }
}

/// Detects coarse container timestamp quantisation (a file whose PTS are whole multiples of 1/600 s, for example).
public enum PTSResolution {
    public static let candidateTimescales = [600, 1000, 1200, 2400, 3000, 6000, 12000, 24000, 48000, 90000, 240_000]
    /// Timescales at or below this are coarse compared with a 240 fps frame period (about 25 ticks per frame or fewer).
    public static let coarseLimit = 6000

    /// The timescale to report when timestamps are coarsely quantised *and* that makes the intervals uneven. A perfectly paced
    /// stream is a whole number of ticks in several timescales without being distorted, so it is not flagged.
    public static func coarseQuantization(_ pts: [Double]) -> Int? {
        guard let scale = detect(pts), scale <= coarseLimit else { return nil }
        let distinct = Set(zip(pts, pts.dropFirst()).map { (($1 - $0) * 1e9).rounded() })
        return distinct.count > 1 ? scale : nil
    }

    /// Smallest candidate timescale in which every timestamp (relative to the first) is a whole number of ticks.
    public static func detect(_ pts: [Double]) -> Int? {
        guard pts.count >= 8, let first = pts.first else { return nil }
        for scale in candidateTimescales {
            let s = Double(scale)
            if pts.allSatisfy({ abs(($0 - first) * s - (($0 - first) * s).rounded()) < 1e-3 }) {
                return scale
            }
        }
        return nil
    }
}
