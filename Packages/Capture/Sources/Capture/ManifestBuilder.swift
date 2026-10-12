import Foundation

/// Builds the sidecar for a finished or interrupted window. Pure, so the harness logic is testable without a camera.
public struct ManifestBuilder: Sendable {
    public let device: DeviceInfo
    public let format: CaptureFormatDescriptor
    public let requestedFrameRate: Double
    public let orientation: String
    public let stabilizationApplied: String?
    public let hdrApplied: Bool?
    public let exposureSetting: ExposureSetting?

    public init(
        device: DeviceInfo,
        format: CaptureFormatDescriptor,
        requestedFrameRate: Double,
        orientation: String,
        stabilizationApplied: String? = nil,
        hdrApplied: Bool? = nil,
        exposureSetting: ExposureSetting? = nil
    ) {
        self.device = device
        self.format = format
        self.requestedFrameRate = requestedFrameRate
        self.orientation = orientation
        self.stabilizationApplied = stabilizationApplied
        self.hdrApplied = hdrApplied
        self.exposureSetting = exposureSetting
    }

    public func build(
        window: CapturedWindow<some Sendable>,
        dropped: DroppedFrameLog,
        telemetry: TelemetryLog,
        createdUTC: Date,
        clipID: UUID = UUID(),
        deviceOrientation: String? = nil,
        callbackTiming: CallbackTimingSummary? = nil,
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
                dropped: Self.windowDrops(dropped, first: first, last: last),
                runDropped: dropped,
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
        manifest.exposureSetting = exposureSetting
        manifest.deviceOrientation = deviceOrientation
        manifest.callbackTiming = callbackTiming
        manifest.frameBytes = FrameSizeStats(sizes: window.frames.map(\.byteCost))
        manifest.setup = setup
        manifest.shot = shot
        manifest.reference = reference
        return manifest
    }

    /// Only drops reported while this window's frames were being captured; a run total would mislead.
    static func windowDrops(_ run: DroppedFrameLog, first: Double?, last: Double?) -> DroppedFrameLog {
        guard let first, let last else { return DroppedFrameLog() }
        return run.within(from: first, to: last)
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
