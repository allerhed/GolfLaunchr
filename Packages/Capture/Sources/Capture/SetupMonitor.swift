import Foundation

/// What the setup screen knows about the scene right now. Every field is optional: nil means "not measured", never "fine".
public struct SetupObservation: Equatable, Sendable {
    /// Mean luma of the frame, 0...1.
    public var meanLuma: Double?
    /// Fraction of sampled pixels at or near white (>= 250 of 255).
    public var clippedFraction: Double?
    /// Mean absolute luma change between consecutive frames over the last second (0...255). Phone shake and scene motion both raise it.
    public var motionScore: Double?
    /// Standard deviation of frame brightness over the last second divided by its mean: periodic ripple in a still scene = flicker.
    public var flickerIndex: Double?
    public var exposureSeconds: Double?

    public init(
        meanLuma: Double? = nil,
        clippedFraction: Double? = nil,
        motionScore: Double? = nil,
        flickerIndex: Double? = nil,
        exposureSeconds: Double? = nil
    ) {
        self.meanLuma = meanLuma
        self.clippedFraction = clippedFraction
        self.motionScore = motionScore
        self.flickerIndex = flickerIndex
        self.exposureSeconds = exposureSeconds
    }
}

/// Rolling one-second analysis of coarse luma grids (the same cheap grids the motion trigger uses). Pure and deterministic.
public struct SetupMonitor: Sendable {
    public static let window = 1.0
    /// Flicker needs a frame rate well above the mains ripple (100/120 Hz) and at least half a second of frames.
    public static let minimumFlickerRate = 100.0
    static let clipLevel: UInt8 = 250

    private struct Sample {
        let time: Double
        let values: [UInt8]
    }

    private var samples: [Sample] = []

    public init() {}

    public mutating func add(_ grid: LumaGrid, at time: Double) {
        samples.append(Sample(time: time, values: grid.values))
        let cutoff = time - Self.window
        if let firstKept = samples.firstIndex(where: { $0.time >= cutoff }), firstKept > 0 {
            samples.removeFirst(firstKept)
        }
    }

    private func mean(_ values: [UInt8]) -> Double {
        Double(values.reduce(0) { $0 + Int($1) }) / Double(max(values.count, 1))
    }

    public func observation(exposureSeconds: Double?) -> SetupObservation {
        guard let last = samples.last else { return SetupObservation(exposureSeconds: exposureSeconds) }
        var o = SetupObservation(exposureSeconds: exposureSeconds)
        o.meanLuma = mean(last.values) / 255
        o.clippedFraction = Double(last.values.filter { $0 >= Self.clipLevel }.count) / Double(max(last.values.count, 1))
        guard samples.count >= 2 else { return o }
        var total = 0.0, pairs = 0
        for (a, b) in zip(samples, samples.dropFirst()) where a.values.count == b.values.count {
            let diff = zip(a.values, b.values).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            total += Double(diff) / Double(max(a.values.count, 1))
            pairs += 1
        }
        if pairs > 0 {
            o.motionScore = total / Double(pairs)
        }
        let span = last.time - samples[0].time
        if span >= 0.5, Double(samples.count - 1) / span >= Self.minimumFlickerRate {
            let means = samples.map { mean($0.values) }
            let avg = means.reduce(0, +) / Double(means.count)
            let variance = means.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(means.count)
            o.flickerIndex = avg > 0 ? variance.squareRoot() / avg : nil
        }
        return o
    }
}
