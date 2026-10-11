#if CAPTURE_HARNESS
    import AVFoundation
    import Capture
    import CaptureAV
    import Formatting
    import Observation
    import SwiftUI
    import UIKit

    enum TriggerMode: String, CaseIterable, Identifiable {
        case manual, motion
        var id: String {
            rawValue
        }
    }

    struct FormatChoice: Identifiable {
        let descriptor: CaptureFormatDescriptor
        var id: String {
            descriptor.id
        }

        var label: String {
            let fov = descriptor.fieldOfViewDegrees.map { String(format: "%.0f°", $0) } ?? "?°"
            return "\(descriptor.lens.rawValue) \(descriptor.width)x\(descriptor.height) @\(Int(descriptor.maxFrameRate)) FOV \(fov)"
        }
    }

    struct SavedClip: Identifiable {
        let id = UUID()
        let movie: URL
        let manifest: URL
        let isComplete: Bool
        let frames: Int
        let missingFrames: Int
    }

    /// State and control for the G1 capture harness. DEBUG HARNESS ONLY: compiled out of Release.
    /// It records raw impact windows for offline analysis. It never creates a Shot, spends a credit or reports a measurement.
    @MainActor @Observable
    final class HarnessModel {
        enum Phase: Equatable {
            case idle, running, noCamera, denied, failed(String)
        }

        static let preSeconds = 0.75
        static let postSeconds = 1.25
        static let bitRate = 100_000_000

        var phase = Phase.idle
        var formats: [FormatChoice] = []
        var selectedFormatID: String?
        var trigger = TriggerMode.manual
        var motionThreshold = 6.0
        var handedness = "right"
        var club = "7 iron"
        var lighting = "indoor bright"
        var location = "bay"
        var distanceText = "0.75"
        var heightText = "0.2"
        var golferID = "g1"
        var message: String?

        var measuredFPS: Double?
        var droppedTotal = 0
        var gapEvents = 0
        var missingFrames = 0
        var exposureText = "-"
        var thermalText = "-"
        var bufferText = "-"
        var motionScoreText = "-"
        var clips: [SavedClip] = []
        var freeSpaceText = "-"
        private(set) var previewSession: AVCaptureSession?

        private var devices: [String: (AVCaptureDevice, AVCaptureDevice.Format)] = [:]
        private var source: AVCaptureFrameSource?
        private var encoder: RealtimeHEVCEncoder?
        private var engine: HarnessEngine?
        private var builder: ManifestBuilder?
        private var continuation: AsyncStream<HarnessEvent>.Continuation?
        private var tasks: [Task<Void, Never>] = []
        private var lastPoll: (frames: Int, pts: Double)?

        // MARK: setup

        func loadFormats() {
            devices = [:]
            var all: [CaptureFormatDescriptor] = []
            for device in AVFormatCatalog.backCameras() {
                for entry in AVFormatCatalog.formats(of: device) {
                    devices[entry.descriptor.id] = (device, entry.format)
                    all.append(entry.descriptor)
                }
            }
            guard !all.isEmpty else {
                phase = .noCamera
                return
            }
            do {
                formats = try FormatCatalog.candidates(from: all).map(FormatChoice.init)
                selectedFormatID = selectedFormatID ?? formats.first?.id
            } catch {
                formats = []
                phase = .failed("No format reaches \(Int(FormatCatalog.minimumFrameRate)) fps on this device: \(error)")
            }
            updateFreeSpace()
        }

        func updateFreeSpace() {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let bytes = (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
                .volumeAvailableCapacityForImportantUsage
            freeSpaceText = bytes.map { String(format: "%.1f GB free", Double($0) / 1e9) } ?? "?"
        }

        // MARK: run

        func start() async {
            guard phase == .idle || phase == .denied || isFailed, let id = selectedFormatID, let (device, format) = devices[id],
                  let choice = formats.first(where: { $0.id == id }) else { return }
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                phase = .denied
                return
            }
            updateFreeSpace()
            if let free = try? URL(fileURLWithPath: NSHomeDirectory())
                .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage, free < 2_000_000_000 {
                phase = .failed("Less than 2 GB free: refusing to record.")
                return
            }
            let rate = choice.descriptor.maxFrameRate.rounded()
            do {
                try await launch(device: device, format: format, descriptor: choice.descriptor, rate: rate)
            } catch {
                await teardown()
                phase = .failed("Start failed: \(error)")
            }
        }

        private var isFailed: Bool {
            if case .failed = phase {
                return true
            }
            return false
        }

        private func launch(
            device: AVCaptureDevice,
            format: AVCaptureDevice.Format,
            descriptor: CaptureFormatDescriptor,
            rate: Double
        ) async throws {
            let engine = HarnessEngine(frameRate: rate, preSeconds: Self.preSeconds, postSeconds: Self.postSeconds)
            let (stream, continuation) = AsyncStream<HarnessEvent>.makeStream(bufferingPolicy: .unbounded)
            let source = AVCaptureFrameSource(device: device)
            let encoder = try RealtimeHEVCEncoder(
                width: descriptor.width,
                height: descriptor.height,
                frameRate: rate,
                bitRate: Self.bitRate
            )
            encoder.onSample = { box, index, pts in
                let frame = Frame(index: index, pts: pts, byteCost: CMSampleBufferGetTotalSampleSize(box.sample), payload: box)
                continuation.yield(.frame(frame))
            }
            source.onFrame = Self.makeFrameHandler(
                device: device, encoder: encoder, continuation: continuation, rate: rate,
                motion: MotionBox(threshold: motionThreshold, cooldownFrames: Int(rate), enabled: trigger == .motion)
            )
            let applied = try source.start(format: format, frameRate: rate)
            if abs(applied.activeFrameRate - rate) > 1 {
                message = "Requested \(Int(rate)) fps but the device runs \(Int(applied.activeFrameRate)) fps."
            }
            builder = ManifestBuilder(
                device: Self.deviceInfo(), format: descriptor, requestedFrameRate: rate, orientation: "sensor-landscapeRight",
                stabilizationApplied: applied.stabilization, hdrApplied: nil
            )
            self.engine = engine
            self.source = source
            self.encoder = encoder
            self.continuation = continuation
            previewSession = source.session
            UIApplication.shared.isIdleTimerDisabled = true
            tasks = [
                Task.detached { [weak self] in
                    for await event in stream {
                        if let clip = await engine.handle(event) {
                            await self?.save(clip)
                        }
                    }
                },
                Task.detached {
                    for await reason in source.drops {
                        continuation.yield(.drop(reason))
                    }
                },
                Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                        self?.recordThermal()
                    }
                },
                Task { [weak self] in
                    while !Task.isCancelled {
                        await self?.poll()
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                },
            ]
            recordThermal()
            phase = .running
        }

        /// Per-frame work on the capture queue: luma grid, exposure sample, motion trigger, then the encoder.
        private static func makeFrameHandler(
            device: AVCaptureDevice,
            encoder: RealtimeHEVCEncoder,
            continuation: AsyncStream<HarnessEvent>.Continuation,
            rate _: Double,
            motion: MotionBox
        ) -> @Sendable (CVPixelBuffer, Double, Int) -> Void {
            let deviceBox = DeviceBox(device: device)
            return { [weak encoder] pixels, pts, index in
                let grid = LumaSampler.grid(from: pixels)
                var sample = AVFormatCatalog.exposureSample(of: deviceBox.device, at: pts)
                if let grid {
                    sample = ExposureSample(
                        time: sample.time, durationSeconds: sample.durationSeconds, iso: sample.iso, lensPosition: sample.lensPosition,
                        meanLuma: Double(grid.values.reduce(0) { $0 + Int($1) }) / Double(grid.values.count) / 255
                    )
                    if motion.ingest(grid) {
                        continuation.yield(.trigger(pts))
                    }
                }
                continuation.yield(.exposure(sample))
                do { try encoder?.encode(pixels, pts: pts, index: index) } catch { continuation.yield(.drop(.unknown)) }
            }
        }

        func stop() async {
            if let engine, let clip = await engine.stop(reason: .user) {
                await save(clip)
            }
            await teardown()
            phase = .idle
        }

        private func teardown() async {
            tasks.forEach { $0.cancel() }
            tasks = []
            source?.stop()
            encoder?.finish()
            continuation?.finish()
            source = nil
            encoder = nil
            engine = nil
            continuation = nil
            previewSession = nil
            lastPoll = nil
            UIApplication.shared.isIdleTimerDisabled = false
            updateFreeSpace()
        }

        func saveNow() async {
            await engine?.triggerNow()
        }

        private func recordThermal() {
            guard let continuation else { return }
            let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
            continuation.yield(.thermal(ThermalLevel(ProcessInfo.processInfo.thermalState), now))
        }

        private func poll() async {
            guard let engine else { return }
            let snap = await engine.snapshot()
            let s = snap.status
            if let last = lastPoll, let pts = snap.lastPTS, pts > last.pts {
                measuredFPS = Double(s.clock.framesSeen - last.frames) / (pts - last.pts)
            }
            if let pts = snap.lastPTS {
                lastPoll = (s.clock.framesSeen, pts)
            }
            droppedTotal = s.dropped.total
            gapEvents = s.clock.gapEvents
            missingFrames = s.clock.missingFrames
            bufferText = String(format: "%d frames, %.0f MB, evicted %d", s.bufferedFrames, Double(s.bufferedBytes) / 1e6, s.evictedFrames)
            if let e = snap.lastExposure {
                exposureText = String(format: "1/%.0f s  ISO %.0f  luma %.2f", 1 / max(e.durationSeconds, 1e-9), e.iso, e.meanLuma ?? .nan)
            }
            thermalText = snap.telemetry.thermal.last?.level.rawValue ?? "-"
        }

        // MARK: saving

        private func save(_ clip: FinishedClip) async {
            guard let builder else { return }
            let created = Date()
            let id = UUID()
            let stem = ClipNaming.stem(createdUTC: created, id: id)
            var setup = SetupInfo(handedness: handedness)
            setup.distanceToBallM = NumberInput.parse(distanceText, locale: .current)
            setup.cameraHeightM = NumberInput.parse(heightText, locale: .current)
            var shot = ShotInfo(club: club, lighting: lighting, location: location, trigger: trigger.rawValue)
            shot.golferID = golferID
            let manifest = builder.build(
                window: clip.window, dropped: clip.dropped, telemetry: clip.telemetry, createdUTC: created, clipID: id,
                setup: setup, shot: shot
            )
            do {
                let dir = try Self.clipDirectory()
                let movie = dir.appendingPathComponent("\(stem).mov")
                let manifestURL = dir.appendingPathComponent("\(stem).json")
                try await ClipWriter.write(clip.window.frames, to: movie)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
                clips.insert(
                    SavedClip(
                        movie: movie, manifest: manifestURL, isComplete: clip.window.isComplete, frames: clip.window.frames.count,
                        missingFrames: clip.window.clockStats.missingFrames
                    ),
                    at: 0
                )
                message = "Saved \(stem) (\(clip.window.frames.count) frames, \(clip.window.clockStats.missingFrames) missing)"
            } catch {
                message = "Save failed: \(error)"
            }
            updateFreeSpace()
        }

        static func clipDirectory() throws -> URL {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = docs.appendingPathComponent("G1", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        static func deviceInfo() -> DeviceInfo {
            var size = 0
            sysctlbyname("hw.machine", nil, &size, nil, 0)
            var bytes = [CChar](repeating: 0, count: max(size, 1))
            sysctlbyname("hw.machine", &bytes, &size, nil, 0)
            let machine = String(cString: bytes)
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
            return DeviceInfo(machine: machine, osVersion: ProcessInfo.processInfo.operatingSystemVersionString, appBuild: build)
        }
    }

    /// AVCaptureDevice property reads are thread-safe; the box lets the capture-queue closure read exposure.
    private struct DeviceBox: @unchecked Sendable {
        let device: AVCaptureDevice
    }

    /// Motion detector state, touched only from the serial capture queue.
    private final class MotionBox: @unchecked Sendable {
        private var detector: MotionDetector
        private let enabled: Bool

        init(threshold: Double, cooldownFrames: Int, enabled: Bool) {
            detector = MotionDetector(threshold: threshold, cooldownFrames: cooldownFrames)
            self.enabled = enabled
        }

        func ingest(_ grid: LumaGrid) -> Bool {
            let hit = detector.ingest(grid)
            return enabled && hit
        }
    }
#endif
