#if CAPTURE_HARNESS
    import Capture
    import CaptureAV
    import Foundation

    /// Ordered input to the harness engine. Everything is funnelled through one stream so ordering is preserved.
    enum HarnessEvent: Sendable {
        case frame(Frame<CompressedBox>)
        case exposure(ExposureSample)
        case trigger(Double)
        case drop(DroppedFrameReason)
        case thermal(ThermalLevel, Double)
    }

    struct FinishedClip {
        let window: CapturedWindow<CompressedBox>
        let dropped: DroppedFrameLog
        let telemetry: TelemetryLog
    }

    struct HarnessSnapshot {
        var status: PipelineStatus
        var telemetry: TelemetryLog
        var lastPTS: Double?
        var lastExposure: ExposureSample?
    }

    /// Owns the pipeline and telemetry for one run. DEBUG HARNESS ONLY: compiled out of Release.
    actor HarnessEngine {
        private let pipeline: CapturePipeline<CompressedBox>
        private var telemetry = TelemetryLog()
        private var dropped = DroppedFrameLog()
        private var lastPTS: Double?
        private var lastExposure: ExposureSample?

        init(frameRate: Double, preSeconds: Double, postSeconds: Double) {
            // 3 s of frames or 200 MB, whichever is smaller: bounded (F23).
            pipeline = CapturePipeline(
                nominalFrameRate: frameRate, maxFrames: Int(frameRate * 3), maxBytes: 200_000_000,
                preSeconds: preSeconds, postSeconds: postSeconds
            )
        }

        func handle(_ event: HarnessEvent) async -> FinishedClip? {
            switch event {
            case let .frame(frame):
                lastPTS = frame.pts
                guard let window = await pipeline.ingest(frame) else { return nil }
                return FinishedClip(window: window, dropped: dropped, telemetry: telemetry)
            case let .exposure(sample):
                telemetry.record(sample)
                lastExposure = sample
            case let .trigger(pts):
                await pipeline.trigger(at: pts)
            case let .drop(reason):
                dropped.record(reason)
                await pipeline.recordDrop(reason)
            case let .thermal(level, time):
                telemetry.record(thermal: level, at: time)
            }
            return nil
        }

        func triggerNow() async {
            await pipeline.trigger()
        }

        /// Stops the run. A window in progress comes back flagged incomplete.
        func stop(reason: PauseReason) async -> FinishedClip? {
            guard let window = await pipeline.pause(reason) else { return nil }
            return FinishedClip(window: window, dropped: dropped, telemetry: telemetry)
        }

        func snapshot() async -> HarnessSnapshot {
            await HarnessSnapshot(status: pipeline.status(), telemetry: telemetry, lastPTS: lastPTS, lastExposure: lastExposure)
        }
    }
#endif
