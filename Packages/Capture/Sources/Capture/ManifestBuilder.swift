import Foundation

/// Builds the sidecar for a finished or interrupted window. Pure, so the harness logic is testable without a camera.
public struct ManifestBuilder: Sendable {
    public let device: DeviceInfo
    public let format: CaptureFormatDescriptor
    public let requestedFrameRate: Double
    public let orientation: String
    public let stabilizationApplied: String?
    public let hdrApplied: Bool?

    public init(
        device: DeviceInfo,
        format: CaptureFormatDescriptor,
        requestedFrameRate: Double,
        orientation: String,
        stabilizationApplied: String? = nil,
        hdrApplied: Bool? = nil
    ) {
        self.device = device
        self.format = format
        self.requestedFrameRate = requestedFrameRate
        self.orientation = orientation
        self.stabilizationApplied = stabilizationApplied
        self.hdrApplied = hdrApplied
    }

    public func build(
        window: CapturedWindow<some Sendable>,
        dropped: DroppedFrameLog,
        telemetry: TelemetryLog,
        createdUTC: Date,
        clipID: UUID = UUID(),
        setup: SetupInfo? = nil,
        shot: ShotInfo? = nil,
        reference: ReferenceInfo? = nil
    ) -> CaptureManifest {
        let first = window.frames.first?.pts
        let last = window.frames.last?.pts
        var manifest = CaptureManifest(
            clipID: clipID,
            createdUTC: createdUTC,
            device: device,
            format: format,
            requestedFrameRate: requestedFrameRate,
            orientation: orientation,
            timing: TimingSummary(
                stats: window.clockStats,
                dropped: dropped,
                firstPTS: first,
                lastPTS: last,
                triggerPTS: window.triggerPTS
            ),
            exposure: Self.samples(telemetry.exposure, from: first, to: last),
            thermal: telemetry.thermal,
            isComplete: window.isComplete
        )
        manifest.stabilizationApplied = stabilizationApplied
        manifest.hdrApplied = hdrApplied
        manifest.setup = setup
        manifest.shot = shot
        manifest.reference = reference
        return manifest
    }

    static func samples(_ all: [ExposureSample], from first: Double?, to last: Double?) -> [ExposureSample] {
        guard let first, let last else { return [] }
        return all.filter { $0.time >= first && $0.time <= last }
    }
}

public enum ClipNaming {
    /// Sortable, filesystem-safe stem: `20261011T110000Z-1a2b3c4d`.
    public static func stem(createdUTC: Date, id: UUID) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return "\(f.string(from: createdUTC))-\(id.uuidString.prefix(8).lowercased())"
    }
}
