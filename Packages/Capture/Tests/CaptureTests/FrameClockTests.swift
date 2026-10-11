@testable import Capture
import Testing

struct FrameClockTests {
    @Test func perfectlyPacedStreamHasNoGaps() {
        var clock = FrameClock(nominalFrameRate: 240)
        for f in FakeFrames.make(count: 500) {
            clock.ingest(pts: f.pts)
        }
        #expect(clock.stats.framesSeen == 500)
        #expect(clock.stats.gapEvents == 0)
        #expect(clock.stats.missingFrames == 0)
        #expect(clock.stats.fractionWithinTolerance == 1)
    }

    @Test func oneMissingFrameIsOneGapWithTheRightCount() {
        var clock = FrameClock(nominalFrameRate: 240)
        var events: [FrameEvent] = []
        for f in FakeFrames.make(count: 10, skipping: [5]) {
            events.append(clock.ingest(pts: f.pts))
        }
        #expect(events.contains(.gap(missingFrames: 1)))
        #expect(clock.stats.gapEvents == 1)
        #expect(clock.stats.missingFrames == 1)
    }

    @Test func threeMissingFramesInARow() {
        var clock = FrameClock(nominalFrameRate: 240)
        for f in FakeFrames.make(count: 12, skipping: [4, 5, 6]) {
            clock.ingest(pts: f.pts)
        }
        #expect(clock.stats.missingFrames == 3)
        #expect(clock.stats.gapEvents == 1)
    }

    @Test func jitterWithinTenPercentIsNotAGapAndOutsideIsJitter() {
        var clock = FrameClock(nominalFrameRate: 100) // 10 ms nominal
        clock.ingest(pts: 0)
        #expect(clock.ingest(pts: 0.0109) == .ok) // +9%
        #expect(clock.ingest(pts: 0.0109 + 0.0125) == .jitter(ratio: 1.25))
        #expect(clock.stats.gapEvents == 0)
        #expect(clock.stats.jitterEvents == 1)
    }

    @Test func boundaryAtOnePointFiveIsAGap() {
        var clock = FrameClock(nominalFrameRate: 100)
        clock.ingest(pts: 0)
        #expect(clock.ingest(pts: 0.0149) != .gap(missingFrames: 1))
        var other = FrameClock(nominalFrameRate: 100)
        other.ingest(pts: 0)
        #expect(other.ingest(pts: 0.015) == .gap(missingFrames: 1))
    }

    @Test func backwardsOrRepeatedTimestampsAreFlaggedAndNotAccepted() {
        var clock = FrameClock(nominalFrameRate: 240)
        clock.ingest(pts: 10)
        #expect(clock.ingest(pts: 10) == .nonMonotonic)
        #expect(clock.ingest(pts: 9.9) == .nonMonotonic)
        #expect(clock.ingest(pts: 10 + 1.0 / 240) == .ok) // reference stayed at 10
        #expect(clock.stats.nonMonotonicEvents == 2)
    }

    @Test func noIntervalsMeansUnknownNotPerfect() {
        var clock = FrameClock(nominalFrameRate: 240)
        #expect(clock.stats.fractionWithinTolerance == nil)
        clock.ingest(pts: 1)
        #expect(clock.stats.fractionWithinTolerance == nil)
    }

    /// U4: drops are counted by reason and are not frames.
    @Test func droppedFramesAreCountedByReasonAndNeverAsFrames() {
        var log = DroppedFrameLog()
        log.record(.frameWasLate)
        log.record(.frameWasLate)
        log.record(.outOfBuffers)
        #expect(log.total == 3)
        #expect(log.countsByReason[.frameWasLate] == 2)
        var clock = FrameClock(nominalFrameRate: 240)
        clock.ingest(pts: 0)
        #expect(clock.stats.framesSeen == 1)
    }
}
