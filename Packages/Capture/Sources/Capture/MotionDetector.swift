import Foundation

/// A coarse grid of luma samples (0...255) taken from a frame; cheap enough to compute at 240 fps.
public struct LumaGrid: Sendable, Equatable {
    public let columns: Int
    public let rows: Int
    public let values: [UInt8]

    public init?(columns: Int, rows: Int, values: [UInt8]) {
        guard columns > 0, rows > 0, values.count == columns * rows else { return nil }
        self.columns = columns
        self.rows = rows
        self.values = values
    }
}

/// Simple frame-difference trigger for the G1 harness (plan 6, P8 baseline). Not a shot detector: it only reports motion.
/// Score is the mean absolute luma difference to the previous grid, on a 0...255 scale.
public struct MotionDetector: Sendable {
    public let threshold: Double
    public let cooldownFrames: Int
    public private(set) var lastScore: Double?
    private var previous: LumaGrid?
    private var framesSinceTrigger: Int

    public init(threshold: Double, cooldownFrames: Int) {
        self.threshold = threshold
        self.cooldownFrames = cooldownFrames
        framesSinceTrigger = cooldownFrames
    }

    /// Returns true when this frame starts a new motion event: score at or above the threshold and the cooldown elapsed.
    /// The first frame, or a grid of a different size, only sets the reference and never triggers.
    public mutating func ingest(_ grid: LumaGrid) -> Bool {
        defer { previous = grid }
        framesSinceTrigger += 1
        guard let previous, previous.columns == grid.columns, previous.rows == grid.rows else {
            lastScore = nil
            return false
        }
        var total = 0
        for (a, b) in zip(previous.values, grid.values) {
            total += abs(Int(a) - Int(b))
        }
        let score = Double(total) / Double(grid.values.count)
        lastScore = score
        guard score >= threshold, framesSinceTrigger > cooldownFrames else { return false }
        framesSinceTrigger = 0
        return true
    }
}
