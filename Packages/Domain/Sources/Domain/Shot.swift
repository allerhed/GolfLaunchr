import Foundation

public enum SwingHandedness: String, Codable, Sendable, CaseIterable {
    case right, left
}

public enum ShotMode: String, Codable, Sendable, CaseIterable {
    case practice, quickShot, bagMapping, target, ladder, round
}

public enum EnvironmentSource: String, Codable, Sendable {
    case standard, manual, sensor
}

/// Atmosphere inputs used by the flight model. SI units; absolute pressure only (never relative altitude).
public struct Environment: Codable, Sendable, Equatable {
    public let pressurePa: Double
    public let temperatureK: Double
    public let altitudeM: Double?
    public let source: EnvironmentSource

    public init(pressurePa: Double, temperatureK: Double, altitudeM: Double? = nil, source: EnvironmentSource) throws(ContractError) {
        guard pressurePa.isFinite, pressurePa > 0, temperatureK.isFinite, temperatureK > 0, altitudeM?.isFinite ?? true else {
            throw .invalidEnvironment
        }
        self.pressurePa = pressurePa
        self.temperatureK = temperatureK
        self.altitudeM = altitudeM
        self.source = source
    }

    private enum CodingKeys: String, CodingKey { case pressurePa, temperatureK, altitudeM, source }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                pressurePa: c.decode(Double.self, forKey: .pressurePa),
                temperatureK: c.decode(Double.self, forKey: .temperatureK),
                altitudeM: c.decodeIfPresent(Double.self, forKey: .altitudeM),
                source: c.decode(EnvironmentSource.self, forKey: .source)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }
}

public struct ShotVersions: Codable, Sendable, Equatable {
    public let pipeline: String
    public let flight: String
    public let deviceProfile: String

    public init(pipeline: String, flight: String, deviceProfile: String) {
        self.pipeline = pipeline
        self.flight = flight
        self.deviceProfile = deviceProfile
    }
}

/// An accepted shot (spec section 6 JSON shot contract v1.0). Raw SI values only; display rounding never enters here.
public struct Shot: Identifiable, Codable, Sendable, Equatable {
    public static let schemaVersion = "1.0"
    public static let coordinateConvention = "targetForward-rightPositive-upPositive"

    public let id: UUID
    public let sessionID: UUID
    /// 1-based position within the session.
    public let sequence: Int
    public let mode: ShotMode
    /// Handedness at capture time; later settings changes never rewrite it.
    public let swingHandedness: SwingHandedness
    public let clubSnapshot: ClubSnapshot
    public let calibrationID: UUID
    public let impactTimeUTC: Date
    /// Only metrics the pipeline reported. A metric that is absent or `.unavailable` has no value; it is never 0.
    public let metrics: [MetricKey: Measurement]
    public let environment: Environment
    public let versions: ShotVersions
    /// Exclusion status: excluded shots stay stored but leave aggregates.
    public var included: Bool
    public let mediaID: UUID?
    /// Synthetic shots are test/demo only and must never enter production trial, analytics or simulator streams (T13).
    public let isSynthetic: Bool

    public init(
        id: UUID,
        sessionID: UUID,
        sequence: Int,
        mode: ShotMode,
        swingHandedness: SwingHandedness,
        clubSnapshot: ClubSnapshot,
        calibrationID: UUID,
        impactTimeUTC: Date,
        metrics: [MetricKey: Measurement],
        environment: Environment,
        versions: ShotVersions,
        included: Bool = true,
        mediaID: UUID? = nil,
        isSynthetic: Bool = false
    ) throws(ContractError) {
        guard sequence >= 1 else { throw .invalidSequence(sequence) }
        self.id = id
        self.sessionID = sessionID
        self.sequence = sequence
        self.mode = mode
        self.swingHandedness = swingHandedness
        self.clubSnapshot = clubSnapshot
        self.calibrationID = calibrationID
        self.impactTimeUTC = impactTimeUTC
        self.metrics = metrics
        self.environment = environment
        self.versions = versions
        self.included = included
        self.mediaID = mediaID
        self.isSynthetic = isSynthetic
    }

    /// The measured/derived/estimated value, or nil if unavailable or never reported.
    public func value(_ key: MetricKey) -> Double? {
        metrics[key]?.value
    }
}

extension Shot {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, sessionId, sequence, mode, swingHandedness, clubSnapshot, calibrationId, impactTimeUTC
        case coordinateConvention, metrics, environment, versions, included, mediaId, isSynthetic
    }

    private struct DynamicKey: CodingKey {
        let stringValue: String
        var intValue: Int? {
            nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decode(String.self, forKey: .schemaVersion)
        guard version == Self.schemaVersion else {
            throw ContractError.unknownValue(field: "schemaVersion", value: version).asDecodingError(c.codingPath)
        }
        let convention = try c.decode(String.self, forKey: .coordinateConvention)
        guard convention == Self.coordinateConvention else {
            throw ContractError.invalidCoordinateConvention(convention).asDecodingError(c.codingPath)
        }
        let metricsContainer = try c.nestedContainer(keyedBy: DynamicKey.self, forKey: .metrics)
        var metrics: [MetricKey: Measurement] = [:]
        for key in metricsContainer.allKeys {
            guard let metric = MetricKey(rawValue: key.stringValue) else {
                throw ContractError.unknownValue(field: "metrics", value: key.stringValue).asDecodingError(metricsContainer.codingPath)
            }
            metrics[metric] = try Measurement.decode(from: metricsContainer.superDecoder(forKey: key), key: metric)
        }
        do {
            try self.init(
                id: c.decode(UUID.self, forKey: .id),
                sessionID: c.decode(UUID.self, forKey: .sessionId),
                sequence: c.decode(Int.self, forKey: .sequence),
                mode: c.decode(ShotMode.self, forKey: .mode),
                swingHandedness: c.decode(SwingHandedness.self, forKey: .swingHandedness),
                clubSnapshot: c.decode(ClubSnapshot.self, forKey: .clubSnapshot),
                calibrationID: c.decode(UUID.self, forKey: .calibrationId),
                impactTimeUTC: c.decode(Date.self, forKey: .impactTimeUTC),
                metrics: metrics,
                environment: c.decode(Environment.self, forKey: .environment),
                versions: c.decode(ShotVersions.self, forKey: .versions),
                included: c.decode(Bool.self, forKey: .included),
                mediaID: c.decodeIfPresent(UUID.self, forKey: .mediaId),
                isSynthetic: c.decode(Bool.self, forKey: .isSynthetic)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schemaVersion)
        try c.encode(id, forKey: .id)
        try c.encode(sessionID, forKey: .sessionId)
        try c.encode(sequence, forKey: .sequence)
        try c.encode(mode, forKey: .mode)
        try c.encode(swingHandedness, forKey: .swingHandedness)
        try c.encode(clubSnapshot, forKey: .clubSnapshot)
        try c.encode(calibrationID, forKey: .calibrationId)
        try c.encode(impactTimeUTC, forKey: .impactTimeUTC)
        try c.encode(Self.coordinateConvention, forKey: .coordinateConvention)
        var metricsContainer = c.nestedContainer(keyedBy: DynamicKey.self, forKey: .metrics)
        for (key, metric) in metrics.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            guard let dynamicKey = DynamicKey(stringValue: key.rawValue) else { continue }
            try metricsContainer.encode(metric, forKey: dynamicKey)
        }
        try c.encode(environment, forKey: .environment)
        try c.encode(versions, forKey: .versions)
        try c.encode(included, forKey: .included)
        try c.encode(mediaID, forKey: .mediaId)
        try c.encode(isSynthetic, forKey: .isSynthetic)
    }
}
