import Foundation

public enum ThermalLevel: String, Codable, Sendable, Comparable {
    case nominal, fair, serious, critical

    private var rank: Int {
        switch self {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical: 3
        }
    }

    public static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public extension ThermalLevel {
    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .critical // unknown future state: assume the worst, never hide it
        }
    }
}

public struct ThermalSample: Codable, Sendable, Equatable {
    /// Seconds on the capture clock.
    public let time: Double
    public let level: ThermalLevel
}

public struct ExposureSample: Codable, Sendable, Equatable {
    public let time: Double
    public let durationSeconds: Double
    public let iso: Double
    public let lensPosition: Double?
    /// Mean luma of the frame, 0...1, for flicker analysis. nil if not computed.
    public let meanLuma: Double?

    public init(time: Double, durationSeconds: Double, iso: Double, lensPosition: Double? = nil, meanLuma: Double? = nil) {
        self.time = time
        self.durationSeconds = durationSeconds
        self.iso = iso
        self.lensPosition = lensPosition
        self.meanLuma = meanLuma
    }
}

/// Timestamped exposure and thermal samples (F23). Bounded, so a long run cannot grow without limit.
public struct TelemetryLog: Sendable, Equatable {
    public let maxExposureSamples: Int
    public private(set) var exposure: [ExposureSample] = []
    public private(set) var thermal: [ThermalSample] = []
    public private(set) var droppedExposureSamples = 0

    public init(maxExposureSamples: Int = 20000) {
        self.maxExposureSamples = maxExposureSamples
    }

    public mutating func record(_ sample: ExposureSample) {
        exposure.append(sample)
        if exposure.count > maxExposureSamples {
            exposure.removeFirst(exposure.count - maxExposureSamples)
            droppedExposureSamples += 1
        }
    }

    /// Only changes are stored, so the timeline stays small. Returns true if the level changed.
    @discardableResult
    public mutating func record(thermal level: ThermalLevel, at time: Double) -> Bool {
        guard thermal.last?.level != level else { return false }
        thermal.append(ThermalSample(time: time, level: level))
        return true
    }

    public var worstThermalLevel: ThermalLevel? {
        thermal.map(\.level).max()
    }
}
