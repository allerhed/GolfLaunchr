@testable import Capture
import Foundation
import Testing

struct RingBufferTests {
    @Test func evictsOldestWhenCountExceeded() {
        var ring = FrameRingBuffer<Int>(maxFrames: 5, maxBytes: 1_000_000)
        for f in FakeFrames.make(count: 8) {
            ring.push(f)
        }
        #expect(ring.frames.map(\.payload) == [3, 4, 5, 6, 7])
        #expect(ring.evictedCount == 3)
    }

    @Test func evictsOldestWhenBytesExceeded() {
        var ring = FrameRingBuffer<Int>(maxFrames: 100, maxBytes: 3500)
        for f in FakeFrames.make(count: 6, bytes: 1000) {
            ring.push(f)
        }
        #expect(ring.frames.count == 3)
        #expect(ring.totalBytes == 3000)
    }

    @Test func oversizedSingleFrameIsRefusedAndBufferKept() {
        var ring = FrameRingBuffer<Int>(maxFrames: 10, maxBytes: 3000)
        for f in FakeFrames.make(count: 3) {
            ring.push(f)
        }
        let huge = Frame(index: 99, pts: 200, byteCost: 5000, payload: 99)
        #expect(ring.push(huge) == nil)
        #expect(ring.frames.count == 3)
    }

    @Test func rangeQueryReturnsFramesInPTSOrder() {
        var ring = FrameRingBuffer<Int>(maxFrames: 100, maxBytes: 1_000_000)
        for f in FakeFrames.make(count: 20) {
            ring.push(f)
        }
        let sel = ring.frames(from: 100 + 5.0 / 240, to: 100 + 8.0 / 240)
        #expect(sel.map(\.payload) == [5, 6, 7, 8])
    }

    @Test func concurrentProducersAndReadersKeepTheInvariants() async {
        let ring = SharedFrameRingBuffer<Int>(maxFrames: 200, maxBytes: 1_000_000)
        await withTaskGroup(of: Void.self) { group in
            for producer in 0 ..< 8 {
                group.addTask {
                    for i in 0 ..< 500 {
                        ring.push(Frame(index: producer * 1000 + i, pts: Double(i), byteCost: 100, payload: i))
                    }
                }
            }
            group.addTask {
                for _ in 0 ..< 200 {
                    let snap = ring.snapshot()
                    #expect(snap.frames.count <= 200)
                    #expect(snap.totalBytes == snap.frames.count * 100)
                }
            }
        }
        let final = ring.snapshot()
        #expect(final.frames.count == 200)
        #expect(final.evictedCount == 8 * 500 - 200)
    }
}
