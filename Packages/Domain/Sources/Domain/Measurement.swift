import Foundation

/// Metric catalogue keys (spec section 5).
public enum MetricKey: String, Codable, Sendable, CaseIterable {
    case ballSpeed, clubSpeed, verticalLaunch, horizontalLaunch, spinRate, spinAxis
    case carry, totalDistance, smashFactor, attackAngle, dynamicLoft, apex, lateralLanding

    /// Every stored value is SI; display conversion happens only in the UI layer.
    public var unit: MetricUnit {
        switch self {
        case .ballSpeed, .clubSpeed: .metresPerSecond
        case .verticalLaunch, .horizontalLaunch, .spinAxis, .attackAngle, .dynamicLoft: .radians
        case .spinRate: .radiansPerSecond
        case .carry, .totalDistance, .apex, .lateralLanding: .metres
        case .smashFactor: .dimensionless
        }
    }

    /// Magnitudes (speeds, distances, spin rate, ratios) cannot be negative. Angles and lateral landing are signed.
    var mustBeNonNegative: Bool {
        switch self {
        case .ballSpeed, .clubSpeed, .spinRate, .carry, .totalDistance, .apex, .smashFactor: true
        case .verticalLaunch, .horizontalLaunch, .spinAxis, .attackAngle, .dynamicLoft, .lateralLanding: false
        }
    }
}

public enum MetricUnit: String, Codable, Sendable {
    case metresPerSecond = "m/s"
    case radians = "rad"
    case radiansPerSecond = "rad/s"
    case metres = "m"
    case dimensionless = "1"
}

/// How a value was obtained. Estimates are never relabelled as measurements (spec F06).
public enum Provenance: String, Codable, Sendable {
    case measured, derived, estimated, unavailable
}

public enum MetricQuality: String, Codable, Sendable {
    case valid, provisional, unsupported, invalid
}

/// Typed measurement failures (spec section 6). Unknown is a reason, never a zero measurement.
public enum MeasurementFailure: String, Codable, Sendable, CaseIterable {
    case unsupportedProfile, calibrationInvalid, insufficientLight, blur, frameGap, occlusion
    case ambiguousBall, incompleteTrack, unsupportedMetric, thermalPause, storageFailure, unknown
}

/// One metric value with its provenance. `value == nil` exactly when `provenance == .unavailable`.
public struct Measurement: Encodable, Sendable, Equatable {
    public let value: Double?
    public let unit: MetricUnit
    public let provenance: Provenance
    public let quality: MetricQuality
    /// Absolute half-width of the 95% interval in `unit`; only with calibration evidence.
    public let uncertainty95: Double?
    public let failure: MeasurementFailure?

    public init(
        key: MetricKey,
        value: Double?,
        provenance: Provenance,
        quality: MetricQuality,
        uncertainty95: Double? = nil,
        failure: MeasurementFailure? = nil
    ) throws(ContractError) {
        try self.init(
            key: key, unit: key.unit, value: value, provenance: provenance, quality: quality,
            uncertainty95: uncertainty95, failure: failure
        )
    }

    init(
        key: MetricKey,
        unit: MetricUnit,
        value: Double?,
        provenance: Provenance,
        quality: MetricQuality,
        uncertainty95: Double?,
        failure: MeasurementFailure?
    ) throws(ContractError) {
        let name = key.rawValue
        guard unit == key.unit else { throw .unitMismatch(metric: name, unit: unit.rawValue) }
        guard (value == nil) == (provenance == .unavailable) else { throw .valueProvenanceMismatch(metric: name) }
        if let value {
            guard value.isFinite else { throw .nonFiniteValue(name) }
            if key.mustBeNonNegative, value < 0 {
                throw .negativeValue(name)
            }
        }
        if let uncertainty95 {
            guard value != nil, uncertainty95.isFinite, uncertainty95 >= 0 else { throw .uncertaintyInvalid(metric: name) }
        }
        self.value = value
        self.unit = unit
        self.provenance = provenance
        self.quality = quality
        self.uncertainty95 = uncertainty95
        self.failure = failure
    }

    private init(unavailableWith failure: MeasurementFailure?, key: MetricKey) {
        value = nil
        unit = key.unit
        provenance = .unavailable
        quality = .unsupported
        uncertainty95 = nil
        self.failure = failure
    }

    /// An unavailable metric with an optional typed reason. Always consistent, so it cannot fail.
    public static func unavailable(_ key: MetricKey, failure: MeasurementFailure? = nil) -> Measurement {
        Measurement(unavailableWith: failure, key: key)
    }

    private enum CodingKeys: String, CodingKey { case value, unit, provenance, quality, uncertainty95, failure }

    /// Decoding needs the metric key to validate the unit, so `Shot` decodes metrics through this.
    static func decode(from decoder: any Decoder, key: MetricKey) throws -> Measurement {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            return try Measurement(
                key: key,
                unit: c.decode(MetricUnit.self, forKey: .unit),
                value: c.decode(Double?.self, forKey: .value),
                provenance: c.decode(Provenance.self, forKey: .provenance),
                quality: c.decode(MetricQuality.self, forKey: .quality),
                uncertainty95: c.decodeIfPresent(Double.self, forKey: .uncertainty95),
                failure: c.decodeIfPresent(MeasurementFailure.self, forKey: .failure)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }

    /// Missing values are explicit nulls (contract); `failure` is omitted when nil.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(value, forKey: .value)
        try c.encode(unit, forKey: .unit)
        try c.encode(provenance, forKey: .provenance)
        try c.encode(quality, forKey: .quality)
        try c.encode(uncertainty95, forKey: .uncertainty95)
        try c.encodeIfPresent(failure, forKey: .failure)
    }
}
