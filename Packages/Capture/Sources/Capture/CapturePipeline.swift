import Foundation

public enum PipelineState: Equatable, Sendable {
    case running
    case paused(PauseReason)
}

/// Why capture stopped (F23/F04): explicit, never silent.
public enum PauseReason: String, Codable, Sendable {
    case backgrounded, interruption, thermal, storage, deviceMoved, formatChanged, user
}

public struct PipelineStatus: Equatable, Sendable {
    public let state: PipelineState
    public let clock: FrameClockStats
    public let dropped: DroppedFrameLog
    public let bufferedFrames: Int
    public let bufferedBytes: Int
    public let evictedFrames: Int
    public let framesIgnoredWhilePaused: Int
    public let refusedOversizedFrames: Int
}

/// Frame intake for capture: pacing, bounded buffering, trigger windows. Platform-free so it runs against a fake source.
/// A frame is only ever a captured frame here; drops are counted separately and never fabricated into frames.
public actor CapturePipeline<Payload: Sendable> {
    private var ring: FrameRingBuffer<Payload>
    private var assembler: ClipAssembler<Payload>
    private var clock: FrameClock
    private var dropped = DroppedFrameLog()
    private var state = PipelineState.running
    private var ignoredWhilePaused = 0
    private var refusedOversized = 0
    private var lastPTS: Double?

    public init(nominalFrameRate: Double, maxFrames: Int, maxBytes: Int, preSeconds: Double, postSeconds: Double) {
        ring = FrameRingBuffer(maxFrames: maxFrames, maxBytes: maxBytes)
        assembler = ClipAssembler(preSeconds: preSeconds, postSeconds: postSeconds, nominalFrameRate: nominalFrameRate)
        clock = FrameClock(nominalFrameRate: nominalFrameRate)
    }

    /// Feeds one captured frame. Returns a finished trigger window when the post-trigger time has been gathered.
    @discardableResult
    public func ingest(_ frame: Frame<Payload>) -> CapturedWindow<Payload>? {
        guard state == .running else {
            ignoredWhilePaused += 1
            return nil
        }
        lastPTS = frame.pts
        let event = clock.ingest(pts: frame.pts)
        if event == .nonMonotonic {
            return nil
        } // a repeated/backwards timestamp is not a new frame
        if ring.push(frame) == nil {
            refusedOversized += 1
        }
        return assembler.ingest(frame)
    }

    public func recordDrop(_ reason: DroppedFrameReason) {
        dropped.record(reason)
    }

    /// Starts a trigger window at `pts` (defaults to the newest frame). No-op while paused or with no frames.
    public func trigger(at pts: Double? = nil) {
        guard state == .running, let at = pts ?? lastPTS else { return }
        assembler.begin(triggerPTS: at, buffer: ring)
    }

    /// Pauses capture. A window in progress is returned flagged incomplete and must not become a measurement.
    @discardableResult
    public func pause(_ reason: PauseReason) -> CapturedWindow<Payload>? {
        state = .paused(reason)
        return assembler.abort()
    }

    /// Resuming clears pacing state: the first frame after a pause is a new reference, not a gap.
    public func resume() {
        state = .running
        clock = FrameClock(nominalFrameRate: clock.nominalFrameRate)
    }

    public func status() -> PipelineStatus {
        PipelineStatus(
            state: state, clock: clock.stats, dropped: dropped, bufferedFrames: ring.frames.count, bufferedBytes: ring.totalBytes,
            evictedFrames: ring.evictedCount, framesIgnoredWhilePaused: ignoredWhilePaused, refusedOversizedFrames: refusedOversized
        )
    }
}
