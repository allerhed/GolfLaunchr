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
        /// Seconds after Start during which motion is ignored: stream start-up and exposure settling look like motion.
        static let motionWarmupSeconds = 2.0
        static let bitRate = 100_000_000

        var phase = Phase.idle
        var formats: [FormatChoice] = []
        var selectedFormatID: String?
        var trigger = TriggerMode.manual
        var motionThreshold = 6.0
        var exposurePreset = ExposurePreset.auto
        var maxMbit: Int?
        var discardLateFrames = false
        var callbackText = "-"
        var orientationText = "-"
        var exposurePlanText: String?
        var handedness = "right"
        var club = "7 iron"
        var lighting = "garage LED"
        var location = "garage"
        var distanceText = "0.75"
        var heightText = "0.2"
        var golferID = "g1"
        var message: String?
        /// Garage/bay session fields: one block = one session on the reference monitor.
        var block = "B1"
        var recordingKind = RecordingKind.strike
        var ball = "white"
        var referenceInstrument = "Garmin Approach R10"
        var sequenceCounters: [String: Int] = [:]
        var lastSavedLabel: String?

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
        var engine: HarnessEngine?
        private var builder: ManifestBuilder?
        var metrics: HarnessMetrics?
        var autorunConfig: HarnessAutorunConfig?
        var autorunStarted: Date?
        var abortedSummary: AutorunSummary?
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
                bitRate: Self.bitRate,
                maxBitRate: maxMbit.map { $0 * 1_000_000 }
            )
            let metrics = HarnessMetrics(frameRate: rate)
            encoder.onSample = { box, index, pts in
                let bytes = CMSampleBufferGetTotalSampleSize(box.sample)
                metrics.noteCompleted(bytes: bytes)
                let frame = Frame(index: index, pts: pts, byteCost: bytes, payload: box)
                continuation.yield(.frame(frame))
            }
            source.onFrame = HarnessFrameHandler.make(
                device: device, encoder: encoder, continuation: continuation,
                motion: MotionBox(
                    threshold: motionThreshold, cooldownFrames: Int(rate), warmupFrames: Int(rate * Self.motionWarmupSeconds),
                    enabled: trigger == .motion
                ),
                metrics: metrics
            )
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            let applied = try source.start(format: format, frameRate: rate, discardLateFrames: discardLateFrames)
            if abs(applied.activeFrameRate - rate) > 1 {
                message = "Requested \(Int(rate)) fps but the device runs \(Int(applied.activeFrameRate)) fps."
            }
            let exposureSetting = try await configureExposure(source: source)
            builder = ManifestBuilder(
                device: Self.deviceInfo(), format: descriptor, requestedFrameRate: rate, orientation: "sensor-landscapeRight",
                stabilizationApplied: applied.stabilization, hdrApplied: nil, exposureSetting: exposureSetting
            )
            self.metrics = metrics
            self.engine = engine
            self.source = source
            self.encoder = encoder
            self.continuation = continuation
            previewSession = source.session
            UIApplication.shared.isIdleTimerDisabled = true
            tasks = makeTasks(stream: stream, engine: engine, source: source, continuation: continuation)
            recordThermal()
            let orientation = Self.orientationName()
            if orientation != "landscapeLeft", orientation != "landscapeRight" {
                message = "Phone is not in landscape (\(orientation)): capture must be landscape."
            }
            phase = .running
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
            metrics = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            UIApplication.shared.isIdleTimerDisabled = false
            updateFreeSpace()
        }

        /// Stops the run because capture can no longer be trusted (backgrounded, encoder failure). A window in progress is saved
        /// flagged incomplete. The run is not resumed automatically: the owner must start again (spec F04/F23: requalify).
        func abortRun(_ text: String, reason: PauseReason) async {
            guard phase == .running else { return }
            phase = .failed(text) // first, so a second abort or a stop cannot re-enter
            if let config = autorunConfig, let started = autorunStarted {
                var summary = await autorunSummary(config, started: started)
                summary.error = text
                abortedSummary = summary
            }
            if let engine, let clip = await engine.stop(reason: reason) {
                await save(clip)
            }
            await teardown()
            message = text
        }

        func saveNow() async {
            await engine?.triggerNow()
        }

        func recordThermal() {
            guard let continuation else { return }
            let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
            continuation.yield(.thermal(ThermalLevel(ProcessInfo.processInfo.thermalState), now))
        }

        func poll() async {
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
            if let metrics {
                let m = metrics.snapshot()
                let t = m.timing
                callbackText = String(
                    format: "mean %.2f ms, p99 %.2f ms, max %.1f ms, over budget %.1f%%, encoder backlog %d (max %d)",
                    t.meanMilliseconds ?? 0, t.p99Milliseconds ?? 0, t.maxMilliseconds, (t.overBudgetFraction ?? 0) * 100, m.backlog,
                    m.maxBacklog
                )
            }
            orientationText = Self.orientationName()
        }

        // MARK: saving

        func save(_ clip: FinishedClip) async {
            guard let builder else { return }
            let created = Date()
            let id = UUID()
            let stem = ClipNaming.stem(createdUTC: created, id: id)
            var setup = SetupInfo(handedness: handedness)
            setup.distanceToBallM = NumberInput.parse(distanceText, locale: .current)
            setup.cameraHeightM = NumberInput.parse(heightText, locale: .current)
            var shot = ShotInfo(club: club, lighting: lighting, location: location, trigger: trigger.rawValue)
            shot.golferID = golferID
            shot.block = block
            shot.recordingKind = recordingKind.rawValue
            shot.ball = ball
            let sequence = nextSequence(block: block, kind: recordingKind)
            shot.sequenceInBlock = sequence
            var manifest = builder.build(
                window: clip.window, dropped: clip.dropped, telemetry: clip.telemetry, createdUTC: created, clipID: id,
                deviceOrientation: Self.orientationName(), callbackTiming: metrics?.snapshot().timing, setup: setup, shot: shot
            )
            if !referenceInstrument.isEmpty {
                var reference = ReferenceInfo(instrument: referenceInstrument)
                reference.sessionID = block
                manifest.reference = reference
            }
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
                logRow(manifest, stem: stem)
                confirmSaved()
                lastSavedLabel = "\(block) \(recordingKind.rawValue) #\(sequence)"
                message = "Saved \(block) \(recordingKind.rawValue) #\(sequence): \(stem) (\(clip.window.frames.count) frames, "
                    + "\(clip.window.clockStats.missingFrames) missing)"
            } catch {
                message = "Save failed: \(error)"
            }
            updateFreeSpace()
        }
    }
#endif
