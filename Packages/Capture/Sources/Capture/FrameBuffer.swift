import Foundation

/// One captured frame. `payload` is the platform sample (opaque here); `byteCost` bounds memory.
public struct Frame<Payload: Sendable>: Sendable {
    public let index: Int
    /// Presentation timestamp in seconds on the capture clock.
    public let pts: Double
    public let byteCost: Int
    public let payload: Payload

    public init(index: Int, pts: Double, byteCost: Int, payload: Payload) {
        self.index = index
        self.pts = pts
        self.byteCost = byteCost
        self.payload = payload
    }
}

/// Bounded FIFO of frames, limited by count and by bytes; the oldest frames are evicted first (F23: bounded buffers).
public struct FrameRingBuffer<Payload: Sendable>: Sendable {
    public let maxFrames: Int
    public let maxBytes: Int
    public private(set) var frames: [Frame<Payload>] = []
    public private(set) var totalBytes = 0
    public private(set) var evictedCount = 0

    public init(maxFrames: Int, maxBytes: Int) {
        precondition(maxFrames > 0 && maxBytes > 0, "invalid buffer limits")
        self.maxFrames = maxFrames
        self.maxBytes = maxBytes
    }

    /// Appends a frame and returns how many older frames were evicted to stay within limits.
    /// A single frame larger than `maxBytes` is refused (returns nil) rather than silently emptying the buffer.
    @discardableResult
    public mutating func push(_ frame: Frame<Payload>) -> Int? {
        guard frame.byteCost <= maxBytes else { return nil }
        frames.append(frame)
        totalBytes += frame.byteCost
        var evicted = 0
        while frames.count > maxFrames || totalBytes > maxBytes {
            totalBytes -= frames.removeFirst().byteCost
            evicted += 1
        }
        evictedCount += evicted
        return evicted
    }

    /// Frames with pts in [from, to], in PTS order.
    public func frames(from: Double, to: Double) -> [Frame<Payload>] {
        frames.filter { $0.pts >= from && $0.pts <= to }
    }
}

/// Lock-protected buffer for the capture callback (producer) and the pipeline (consumer).
public final class SharedFrameRingBuffer<Payload: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: FrameRingBuffer<Payload>

    public init(maxFrames: Int, maxBytes: Int) {
        buffer = FrameRingBuffer(maxFrames: maxFrames, maxBytes: maxBytes)
    }

    @discardableResult
    public func push(_ frame: Frame<Payload>) -> Int? {
        lock.withLock { buffer.push(frame) }
    }

    public func snapshot() -> FrameRingBuffer<Payload> {
        lock.withLock { buffer }
    }
}

/// A trigger window: frames before and after the trigger.
public struct CapturedWindow<Payload: Sendable>: Sendable {
    public let triggerPTS: Double
    public let frames: [Frame<Payload>]
    /// False if the source ended (or was interrupted) before the post-trigger time was gathered. Incomplete windows are never promoted to
    /// measurements.
    public let isComplete: Bool
    public let clockStats: FrameClockStats
}

/// Gathers `preSeconds` before and `postSeconds` after a trigger.
public struct ClipAssembler<Payload: Sendable>: Sendable {
    public let preSeconds: Double
    public let postSeconds: Double
    private var triggerPTS: Double?
    private var collected: [Frame<Payload>] = []
    private var clock: FrameClock
    private var seenIndexes = Set<Int>()

    public init(preSeconds: Double, postSeconds: Double, nominalFrameRate: Double) {
        self.preSeconds = preSeconds
        self.postSeconds = postSeconds
        clock = FrameClock(nominalFrameRate: nominalFrameRate)
    }

    public var isCollecting: Bool {
        triggerPTS != nil
    }

    /// Starts a window from the current buffer contents. Frames already in the buffer at or before the trigger are included.
    public mutating func begin(triggerPTS: Double, buffer: FrameRingBuffer<Payload>) {
        self.triggerPTS = triggerPTS
        collected = []
        seenIndexes = []
        clock = FrameClock(nominalFrameRate: clock.nominalFrameRate)
        for frame in buffer.frames(from: triggerPTS - preSeconds, to: .infinity) {
            add(frame)
        }
    }

    /// Feeds a new frame; returns the finished window when the post-trigger time has been gathered.
    public mutating func ingest(_ frame: Frame<Payload>) -> CapturedWindow<Payload>? {
        guard let trigger = triggerPTS else { return nil }
        add(frame)
        guard frame.pts >= trigger + postSeconds else { return nil }
        return finish(complete: true)
    }

    /// Ends the window early (interruption, pause). The result is flagged incomplete.
    public mutating func abort() -> CapturedWindow<Payload>? {
        triggerPTS == nil ? nil : finish(complete: false)
    }

    private mutating func add(_ frame: Frame<Payload>) {
        guard seenIndexes.insert(frame.index).inserted else { return }
        collected.append(frame)
        clock.ingest(pts: frame.pts)
    }

    private mutating func finish(complete: Bool) -> CapturedWindow<Payload>? {
        guard let trigger = triggerPTS else { return nil }
        triggerPTS = nil
        let window = CapturedWindow(triggerPTS: trigger, frames: collected, isComplete: complete, clockStats: clock.stats)
        collected = []
        return window
    }
}
