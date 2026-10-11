@testable import Capture
import Foundation
import Testing

struct PipelineTests {
    func pipeline() -> CapturePipeline<Int> {
        // 240 fps, buffer holds 1 s, window 0.5 s before and 0.25 s after the trigger
        CapturePipeline(nominalFrameRate: 240, maxFrames: 240, maxBytes: 10_000_000, preSeconds: 0.5, postSeconds: 0.25)
    }

    @Test func triggerWindowHasPreAndPostFramesInOrder() async throws {
        let p = pipeline()
        let frames = FakeFrames.make(count: 600)
        var window: CapturedWindow<Int>?
        for (i, f) in frames.enumerated() {
            if i == 300 {
                await p.trigger()
            }
            if let w = await p.ingest(f) {
                window = w
            }
        }
        let w = try #require(window)
        #expect(w.isComplete)
        let pts = w.frames.map(\.pts)
        #expect(pts == pts.sorted())
        let trigger = w.triggerPTS
        #expect(try #require(pts.first) >= trigger - 0.5 - 1e-9)
        #expect(try #require(pts.last) >= trigger + 0.25)
        #expect(w.frames.count > 170 && w.frames.count < 190) // 0.75 s at 240 fps = 180 +/- boundary frames
        #expect(w.clockStats.gapEvents == 0)
    }

    @Test func missingFramesInsideTheWindowAreVisibleInItsStats() async throws {
        let p = pipeline()
        var window: CapturedWindow<Int>?
        for (i, f) in FakeFrames.make(count: 600, skipping: [310, 311]).enumerated() {
            if i == 300 {
                await p.trigger()
            }
            if let w = await p.ingest(f) {
                window = w
            }
        }
        let w = try #require(window)
        #expect(w.clockStats.missingFrames == 2)
        #expect(w.clockStats.gapEvents == 1)
    }

    /// F04/F23: an interrupted candidate is marked incomplete, never promoted.
    @Test func pauseDuringCollectionYieldsAnIncompleteWindow() async throws {
        let p = pipeline()
        for (i, f) in FakeFrames.make(count: 400).enumerated() {
            if i == 300 {
                await p.trigger()
            }
            await p.ingest(f)
            if i == 310 {
                break
            }
        }
        let w = try #require(await p.pause(.backgrounded))
        #expect(w.isComplete == false)
        #expect(await p.status().state == .paused(.backgrounded))
    }

    @Test func framesWhilePausedAreIgnoredAndCounted() async {
        let p = pipeline()
        for f in FakeFrames.make(count: 10) {
            await p.ingest(f)
        }
        await p.pause(.thermal)
        for f in FakeFrames.make(count: 5, start: 200, firstIndex: 100) {
            await p.ingest(f)
        }
        let s = await p.status()
        #expect(s.framesIgnoredWhilePaused == 5)
        #expect(s.bufferedFrames == 10)
    }

    @Test func resumeStartsANewTimingReferenceSoThePauseIsNotAGap() async {
        let p = pipeline()
        for f in FakeFrames.make(count: 10) {
            await p.ingest(f)
        }
        await p.pause(.interruption)
        await p.resume()
        for f in FakeFrames.make(count: 10, start: 500, firstIndex: 100) {
            await p.ingest(f)
        }
        let s = await p.status()
        #expect(s.clock.gapEvents == 0)
        #expect(s.state == .running)
    }

    @Test func triggerWhilePausedOrEmptyDoesNothing() async {
        let p = pipeline()
        await p.trigger() // no frames yet
        for f in FakeFrames.make(count: 5) {
            await p.ingest(f)
        }
        await p.pause(.user)
        await p.trigger()
        #expect(await p.pause(.user) == nil)
    }

    @Test func bufferStaysBoundedOverALongRun() async {
        let p = pipeline()
        for f in FakeFrames.make(count: 5000) {
            await p.ingest(f)
        }
        let s = await p.status()
        #expect(s.bufferedFrames == 240)
        #expect(s.evictedFrames == 5000 - 240)
        #expect(s.bufferedBytes == 240 * 1000)
    }

    @Test func repeatedTimestampIsNotBufferedAsANewFrame() async {
        let p = pipeline()
        let f = FakeFrames.make(count: 1)[0]
        await p.ingest(f)
        await p.ingest(f)
        let s = await p.status()
        #expect(s.bufferedFrames == 1)
        #expect(s.clock.nonMonotonicEvents == 1)
    }

    @Test func dropsAreRecordedSeparatelyFromFrames() async {
        let p = pipeline()
        await p.recordDrop(.outOfBuffers)
        for f in FakeFrames.make(count: 3) {
            await p.ingest(f)
        }
        let s = await p.status()
        #expect(s.dropped.total == 1)
        #expect(s.clock.framesSeen == 3)
    }
}
