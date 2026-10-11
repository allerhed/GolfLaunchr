import Foundation

public enum CalibrationQuality: String, Codable, Sendable {
    case good, marginal, invalid
}

public enum ScaleMethod: String, Codable, Sendable {
    case knownBallDiameter, referenceMarker, manual
}

/// Capture format the calibration is bound to; a format/lens change invalidates it.
public struct CaptureFormatRecord: Codable, Sendable, Equatable {
    public let widthPx: Int
    public let heightPx: Int
    public let framesPerSecond: Double
    public let lens: String

    public init(widthPx: Int, heightPx: Int, framesPerSecond: Double, lens: String) {
        self.widthPx = widthPx
        self.heightPx = heightPx
        self.framesPerSecond = framesPerSecond
        self.lens = lens
    }
}

/// Geometry/exposure calibration linked to each shot by `Shot.calibrationID` (F03).
/// Field set is provisional until the G1 capture spike fixes what calibration must carry; extend via `calibrationVersion`.
public struct CalibrationRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let deviceProfileID: String
    public let format: CaptureFormatRecord
    public let scaleMethod: ScaleMethod
    /// Image-to-ground scale in metres per pixel at the ball plane.
    public let metresPerPixel: Double
    /// 3x3 row-major image-to-target-plane transform.
    public let transform: [Double]
    /// Camera pose relative to the ball: distance, height, heading (rad, target line = 0).
    public let cameraDistanceM: Double
    public let cameraHeightM: Double
    public let cameraHeadingRad: Double
    public let quality: CalibrationQuality
    public let createdAt: Date
    public let calibrationVersion: Int

    public init(
        id: UUID = UUID(),
        deviceProfileID: String,
        format: CaptureFormatRecord,
        scaleMethod: ScaleMethod,
        metresPerPixel: Double,
        transform: [Double],
        cameraDistanceM: Double,
        cameraHeightM: Double,
        cameraHeadingRad: Double,
        quality: CalibrationQuality,
        createdAt: Date,
        calibrationVersion: Int
    ) throws(ContractError) {
        guard !deviceProfileID.isEmpty else { throw .invalidCalibration("deviceProfileID") }
        guard metresPerPixel.isFinite, metresPerPixel > 0 else { throw .invalidCalibration("metresPerPixel") }
        guard transform.count == 9, transform.allSatisfy(\.isFinite) else { throw .invalidCalibration("transform") }
        guard cameraDistanceM.isFinite, cameraDistanceM > 0, cameraHeightM.isFinite, cameraHeadingRad.isFinite else {
            throw .invalidCalibration("pose")
        }
        guard format.widthPx > 0, format.heightPx > 0, format.framesPerSecond.isFinite, format.framesPerSecond > 0 else {
            throw .invalidCalibration("format")
        }
        self.id = id
        self.deviceProfileID = deviceProfileID
        self.format = format
        self.scaleMethod = scaleMethod
        self.metresPerPixel = metresPerPixel
        self.transform = transform
        self.cameraDistanceM = cameraDistanceM
        self.cameraHeightM = cameraHeightM
        self.cameraHeadingRad = cameraHeadingRad
        self.quality = quality
        self.createdAt = createdAt
        self.calibrationVersion = calibrationVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id, deviceProfileID, format, scaleMethod, metresPerPixel, transform
        case cameraDistanceM, cameraHeightM, cameraHeadingRad, quality, createdAt, calibrationVersion
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                id: c.decode(UUID.self, forKey: .id),
                deviceProfileID: c.decode(String.self, forKey: .deviceProfileID),
                format: c.decode(CaptureFormatRecord.self, forKey: .format),
                scaleMethod: c.decode(ScaleMethod.self, forKey: .scaleMethod),
                metresPerPixel: c.decode(Double.self, forKey: .metresPerPixel),
                transform: c.decode([Double].self, forKey: .transform),
                cameraDistanceM: c.decode(Double.self, forKey: .cameraDistanceM),
                cameraHeightM: c.decode(Double.self, forKey: .cameraHeightM),
                cameraHeadingRad: c.decode(Double.self, forKey: .cameraHeadingRad),
                quality: c.decode(CalibrationQuality.self, forKey: .quality),
                createdAt: c.decode(Date.self, forKey: .createdAt),
                calibrationVersion: c.decode(Int.self, forKey: .calibrationVersion)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }
}
