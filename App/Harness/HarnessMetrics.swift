#if CAPTURE_HARNESS
    import AVFoundation
    import Capture
    import CaptureAV
    import Foundation

    enum ExposurePreset: String, CaseIterable, Identifiable {
        case auto, ms1000 = "1/1000", ms2000 = "1/2000", ms4000 = "1/4000"
        var id: String {
            rawValue
        }

        /// Target exposure duration in seconds; nil keeps continuous auto exposure.
        var durationSeconds: Double? {
            switch self {
            case .auto: nil
            case .ms1000: 1.0 / 1000
            case .ms2000: 1.0 / 2000
            case .ms4000: 1.0 / 4000
            }
        }
    }

    struct MetricsSnapshot {
        let timing: CallbackTimingSummary
        let encodeTiming: CallbackTimingSummary
        let backlog: Int
        let maxBacklog: Int
    }

    /// Counters shared between the capture queue and the encoder thread. DEBUG HARNESS ONLY.
    final class HarnessMetrics: @unchecked Sendable {
        private let lock = NSLock()
        private var timing: TimingAccumulator
        private var encode: TimingAccumulator
        private var submitted = 0
        private var completed = 0
        private var maxBacklog = 0

        init(frameRate: Double) {
            timing = TimingAccumulator(budget: 1 / frameRate)
            encode = TimingAccumulator(budget: 1 / frameRate)
        }

        func recordCallback(seconds: Double) {
            lock.withLock { timing.record(seconds) }
        }

        func recordEncode(seconds: Double) {
            lock.withLock { encode.record(seconds) }
        }

        func noteSubmitted() {
            lock.withLock {
                submitted += 1
                maxBacklog = max(maxBacklog, submitted - completed)
            }
        }

        func noteCompleted() {
            lock.withLock { completed += 1 }
        }

        func snapshot() -> MetricsSnapshot {
            lock.withLock { MetricsSnapshot(
                timing: timing.summary,
                encodeTiming: encode.summary,
                backlog: submitted - completed,
                maxBacklog: maxBacklog
            ) }
        }
    }

    /// AVCaptureDevice property reads are thread-safe; the box lets the capture-queue closure use the device.
    struct DeviceBox: @unchecked Sendable {
        let device: AVCaptureDevice
    }

    /// Motion detector state, touched only from the serial capture queue.
    final class MotionBox: @unchecked Sendable {
        private var detector: MotionDetector
        private let enabled: Bool

        init(threshold: Double, cooldownFrames: Int, warmupFrames: Int, enabled: Bool) {
            detector = MotionDetector(threshold: threshold, cooldownFrames: cooldownFrames, warmupFrames: warmupFrames)
            self.enabled = enabled
        }

        func ingest(_ grid: LumaGrid) -> Bool {
            let hit = detector.ingest(grid)
            return enabled && hit
        }
    }

    /// Cached device exposure values, refreshed every few frames: reading device properties on every frame at 240 fps is a
    /// suspected cause of late-frame drops. Touched only from the capture queue.
    private final class ExposureCache: @unchecked Sendable {
        var last: ExposureSample?
        var consecutiveEncodeFailures = 0
    }

    enum HarnessFrameHandler {
        static let exposureReadInterval = 8
        static let maxConsecutiveEncodeFailures = 10

        /// Per-frame work on the capture queue. The encoder gets the frame first so its latency starts early; luma, exposure and
        /// motion follow. Total callback time is measured because the frame budget is 4.17 ms at 240 fps.
        static func make(
            device: AVCaptureDevice,
            encoder: RealtimeHEVCEncoder,
            continuation: AsyncStream<HarnessEvent>.Continuation,
            motion: MotionBox,
            metrics: HarnessMetrics
        ) -> @Sendable (CVPixelBuffer, Double, Int) -> Void {
            let deviceBox = DeviceBox(device: device)
            let cache = ExposureCache()
            return { [weak encoder] pixels, pts, index in
                let start = DispatchTime.now().uptimeNanoseconds
                metrics.noteSubmitted()
                let encodeStart = DispatchTime.now().uptimeNanoseconds
                do {
                    try encoder?.encode(pixels, pts: pts, index: index)
                    cache.consecutiveEncodeFailures = 0
                } catch {
                    cache.consecutiveEncodeFailures += 1
                    continuation.yield(.drop(.unknown))
                    if cache.consecutiveEncodeFailures == Self.maxConsecutiveEncodeFailures {
                        continuation.yield(.encoderFailed("Encoder failed \(Self.maxConsecutiveEncodeFailures) frames in a row: \(error)"))
                    }
                }
                metrics.recordEncode(seconds: Double(DispatchTime.now().uptimeNanoseconds - encodeStart) / 1e9)
                if index % exposureReadInterval == 0 || cache.last == nil {
                    cache.last = AVFormatCatalog.exposureSample(of: deviceBox.device, at: pts)
                }
                let grid = LumaSampler.grid(from: pixels)
                if let base = cache.last {
                    continuation.yield(.exposure(ExposureSample(
                        time: pts, durationSeconds: base.durationSeconds, iso: base.iso, lensPosition: base.lensPosition,
                        meanLuma: grid.map { Double($0.values.reduce(0) { $0 + Int($1) }) / Double($0.values.count) / 255 }
                    )))
                }
                if let grid, motion.ingest(grid) {
                    continuation.yield(.trigger(pts))
                }
                metrics.recordCallback(seconds: Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
            }
        }
    }
#endif
