import Foundation

/// Accumulates per-frame callback durations without storing every sample: fixed 0.25 ms buckets up to 20 ms.
/// Used to see whether the capture callback exceeds the frame budget (4.17 ms at 240 fps), the suspected cause of late-frame drops.
public struct TimingAccumulator: Sendable, Equatable {
    public static let bucketWidth = 0.00025
    public static let bucketCount = 80
    public private(set) var sampleCount = 0
    public private(set) var total = 0.0
    public private(set) var maximum = 0.0
    public let budget: Double
    public private(set) var overBudget = 0
    private var buckets = [Int](repeating: 0, count: bucketCount + 1)

    public init(budget: Double) {
        self.budget = budget
    }

    public mutating func record(_ seconds: Double) {
        guard seconds >= 0, seconds.isFinite else { return }
        sampleCount += 1
        total += seconds
        maximum = max(maximum, seconds)
        if seconds > budget {
            overBudget += 1
        }
        buckets[min(Int(seconds / Self.bucketWidth), Self.bucketCount)] += 1
    }

    public var mean: Double? {
        sampleCount == 0 ? nil : total / Double(sampleCount)
    }

    public var overBudgetFraction: Double? {
        sampleCount == 0 ? nil : Double(overBudget) / Double(sampleCount)
    }

    /// Upper edge of the bucket that holds the p-th quantile (p in 0...1). Resolution is one bucket.
    public func percentile(_ p: Double) -> Double? {
        guard sampleCount > 0, (0 ... 1).contains(p) else { return nil }
        let target = max(1, Int((Double(sampleCount) * p).rounded(.up)))
        var seen = 0
        for (index, n) in buckets.enumerated() {
            seen += n
            if seen >= target {
                return Double(index + 1) * Self.bucketWidth
            }
        }
        return maximum
    }

    public var summary: CallbackTimingSummary {
        CallbackTimingSummary(
            frames: sampleCount, meanMilliseconds: mean.map { $0 * 1000 }, p99Milliseconds: percentile(0.99).map { $0 * 1000 },
            maxMilliseconds: maximum * 1000, budgetMilliseconds: budget * 1000, overBudgetFraction: overBudgetFraction
        )
    }
}

public struct CallbackTimingSummary: Codable, Sendable, Equatable {
    public let frames: Int
    public let meanMilliseconds: Double?
    public let p99Milliseconds: Double?
    public let maxMilliseconds: Double
    public let budgetMilliseconds: Double
    public let overBudgetFraction: Double?
}

public struct FrameSizeStats: Codable, Sendable, Equatable {
    public let minBytes: Int
    public let meanBytes: Double
    public let maxBytes: Int

    public init?(sizes: [Int]) {
        guard let minimum = sizes.min(), let maximum = sizes.max() else { return nil }
        minBytes = minimum
        maxBytes = maximum
        meanBytes = Double(sizes.reduce(0, +)) / Double(sizes.count)
    }
}
