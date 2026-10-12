import Foundation

/// Sidecar written next to every recorded clip (G1 plan section 4, schema `g1-manifest/1`).
/// Unknown values are nil and stay nil; they are never written as 0.
public struct CaptureManifest: Codable, Sendable, Equatable {
    public static let schema = "g1-manifest/1"

    public var schema: String = CaptureManifest.schema
    public var clipID: UUID
    public var createdUTC: Date
    public var device: DeviceInfo
    public var format: CaptureFormatDescriptor
    public var requestedFrameRate: Double
    public var stabilizationApplied: String?
    public var hdrApplied: Bool?
    public var orientation: String
    /// Physical device orientation when recorded (for example "landscapeLeft"). Capture must be landscape (spec F22).
    public var deviceOrientation: String?
    public var exposureSetting: ExposureSetting?
    public var callbackTiming: CallbackTimingSummary?
    public var frameBytes: FrameSizeStats?
    public var timing: TimingSummary
    public var exposure: [ExposureSample]
    public var thermal: [ThermalSample]
    public var setup: SetupInfo?
    public var shot: ShotInfo?
    public var reference: ReferenceInfo?
    public var isComplete: Bool

    public init(
        clipID: UUID = UUID(),
        createdUTC: Date,
        device: DeviceInfo,
        format: CaptureFormatDescriptor,
        requestedFrameRate: Double,
        orientation: String,
        timing: TimingSummary,
        exposure: [ExposureSample] = [],
        thermal: [ThermalSample] = [],
        isComplete: Bool
    ) {
        self.clipID = clipID
        self.createdUTC = createdUTC
        self.device = device
        self.format = format
        self.requestedFrameRate = requestedFrameRate
        self.orientation = orientation
        self.timing = timing
        self.exposure = exposure
        self.thermal = thermal
        self.isComplete = isComplete
    }
}

/// What exposure the harness asked for and what the camera actually applied.
public struct ExposureSetting: Codable, Sendable, Equatable {
    public var mode: String
    public var requestedDurationSeconds: Double?
    public var appliedDurationSeconds: Double?
    public var appliedISO: Double?
    public var isoClamped: Bool?
    /// Stops darker than auto when the camera could not reach the needed ISO; nil in auto mode.
    public var evShortfallStops: Double?

    public init(mode: String) {
        self.mode = mode
    }
}

public struct DeviceInfo: Codable, Sendable, Equatable {
    /// Hardware identifier, for example "iPhone16,1".
    public let machine: String
    public let osVersion: String
    public let appBuild: String

    public init(machine: String, osVersion: String, appBuild: String) {
        self.machine = machine
        self.osVersion = osVersion
        self.appBuild = appBuild
    }
}

public struct TimingSummary: Codable, Sendable, Equatable {
    public let frameCount: Int
    public let firstPTS: Double?
    public let lastPTS: Double?
    public let gapEvents: Int
    public let missingFrames: Int
    public let jitterEvents: Int
    public let fractionWithinTolerance: Double?
    /// Drops reported while this clip's frames were being captured.
    public let droppedByReason: [String: Int]
    /// Drops for the whole recording run, for context.
    public let runDroppedByReason: [String: Int]
    public let triggerPTS: Double?

    public init(
        stats: FrameClockStats,
        dropped: DroppedFrameLog,
        runDropped: DroppedFrameLog? = nil,
        firstPTS: Double?,
        lastPTS: Double?,
        triggerPTS: Double?
    ) {
        frameCount = stats.framesSeen
        self.firstPTS = firstPTS
        self.lastPTS = lastPTS
        gapEvents = stats.gapEvents
        missingFrames = stats.missingFrames
        jitterEvents = stats.jitterEvents
        fractionWithinTolerance = stats.fractionWithinTolerance
        droppedByReason = Dictionary(uniqueKeysWithValues: dropped.countsByReason.map { ($0.key.rawValue, $0.value) })
        runDroppedByReason = Dictionary(uniqueKeysWithValues: (runDropped ?? dropped).countsByReason.map { ($0.key.rawValue, $0.value) })
        self.triggerPTS = triggerPTS
    }
}

public struct SetupInfo: Codable, Sendable, Equatable {
    public var handedness: String
    public var distanceToBallM: Double?
    public var cameraHeightM: Double?
    public var pitchDegrees: Double?
    public var rollDegrees: Double?
    public var notes: String?

    public init(handedness: String, distanceToBallM: Double? = nil, cameraHeightM: Double? = nil) {
        self.handedness = handedness
        self.distanceToBallM = distanceToBallM
        self.cameraHeightM = cameraHeightM
    }
}

public struct ShotInfo: Codable, Sendable, Equatable {
    public var club: String
    public var ball: String?
    public var lighting: String
    public var location: String
    /// Pseudonymous id, never a name.
    public var golferID: String?
    public var outcomeNotes: String?
    public var trigger: String

    public init(club: String, lighting: String, location: String, trigger: String) {
        self.club = club
        self.lighting = lighting
        self.location = location
        self.trigger = trigger
    }
}

/// Independent reference launch monitor values for the same strike, when available (G1 plan section 12). Optional and never zero-filled.
public struct ReferenceInfo: Codable, Sendable, Equatable {
    public var instrument: String
    public var firmware: String?
    public var mode: String?
    public var sessionID: String?
    public var shotNumber: Int?
    public var ballSpeedMetresPerSecond: Double?
    public var launchAngleDegrees: Double?
    public var launchDirectionDegrees: Double?
    public var clubSpeedMetresPerSecond: Double?
    public var spinRPM: Double?
    public var carryMetres: Double?

    public init(instrument: String) {
        self.instrument = instrument
    }
}
