@testable import Capture
import Foundation
import Testing

struct MotionWarmupTests {
    func grid(_ v: UInt8) -> LumaGrid {
        guard let g = LumaGrid(columns: 4, rows: 4, values: Array(repeating: v, count: 16)) else { preconditionFailure("valid grid") }
        return g
    }

    @Test func noTriggerDuringWarmupButReferenceKeepsUpdating() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 0, warmupFrames: 10)
        var results: [Bool] = []
        for i in 0 ..< 10 {
            results.append(d.ingest(grid(i.isMultiple(of: 2) ? 0 : 200)))
        } // violent change every frame
        #expect(!results.contains(true))
        #expect(d.lastScore == 200) // still measured
    }

    @Test func triggersAfterWarmupEnds() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 0, warmupFrames: 10)
        for _ in 0 ..< 10 {
            _ = d.ingest(grid(0))
        }
        let first = d.ingest(grid(200)) // frame 11
        #expect(first)
    }

    @Test func warmupBoundaryIsExact() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 0, warmupFrames: 3)
        _ = d.ingest(grid(0)) // frame 1
        _ = d.ingest(grid(0)) // frame 2
        let atThree = d.ingest(grid(200)) // frame 3: still warming up
        #expect(!atThree)
        let atFour = d.ingest(grid(0)) // frame 4: allowed
        #expect(atFour)
    }
}

struct DropAttributionTests {
    @Test func withinFiltersByTimeInclusive() {
        var log = DroppedFrameLog()
        log.record(.frameWasLate, at: 1)
        log.record(.outOfBuffers, at: 2)
        log.record(.discontinuity, at: 3)
        log.record(.unknown) // untimed
        #expect(log.total == 4)
        let w = log.within(from: 2, to: 3)
        #expect(w.countsByReason == [.outOfBuffers: 1, .discontinuity: 1])
        #expect(log.within(from: 10, to: 20).total == 0)
    }

    @Test func eventsAreBounded() {
        var log = DroppedFrameLog()
        for i in 0 ..< (DroppedFrameLog.maxEvents + 50) {
            log.record(.frameWasLate, at: Double(i))
        }
        #expect(log.events.count == DroppedFrameLog.maxEvents)
        #expect(log.total == DroppedFrameLog.maxEvents + 50) // counts are never lost
    }

    @Test func pipelineStampsDropsWithTheNewestFrameTime() async {
        let p = CapturePipeline<Int>(nominalFrameRate: 240, maxFrames: 100, maxBytes: 1_000_000, preSeconds: 0.1, postSeconds: 0.1)
        for f in FakeFrames.make(count: 10) {
            await p.ingest(f)
        }
        await p.recordDrop(.frameWasLate)
        let s = await p.status()
        #expect(s.dropped.events.first?.time == 100 + 9.0 / 240)
    }
}

struct ExposurePlannerTests {
    let isoRange = 50.0 ... 3000.0
    let durationRange = 1.0 / 20000 ... 1.0 / 240

    @Test func holdsBrightnessByTradingDurationForISO() throws {
        // D1 scene: auto chose 1/253 s at ISO 746. Target 1/1000 s needs ISO 746 * 1000/253 ~ 2949: within range.
        let plan = try #require(ExposurePlanner.plan(
            autoDuration: 1.0 / 253, autoISO: 746, targetDuration: 1.0 / 1000, isoRange: isoRange, durationRange: durationRange
        ))
        #expect(abs(plan.iso - 746 * 1000 / 253) < 1e-6)
        #expect(!plan.isoClamped)
        #expect(plan.evShortfallStops == 0)
    }

    @Test func reportsTheLightShortfallInStopsWhenISORunsOut() throws {
        // 1/2000 s needs ISO ~5897 but the camera tops out at 3000: about one stop dark.
        let plan = try #require(ExposurePlanner.plan(
            autoDuration: 1.0 / 253, autoISO: 746, targetDuration: 1.0 / 2000, isoRange: isoRange, durationRange: durationRange
        ))
        #expect(plan.isoClamped)
        #expect(plan.iso == 3000)
        #expect(abs(plan.evShortfallStops - log2(746 * 2000 / 253.0 / 3000)) < 1e-9)
        #expect(plan.evShortfallStops > 0.9 && plan.evShortfallStops < 1.1)
    }

    @Test func brightSceneNeverBreaksTheLowerISOBound() throws {
        let plan = try #require(ExposurePlanner.plan(
            autoDuration: 1.0 / 5000, autoISO: 50, targetDuration: 1.0 / 1000, isoRange: isoRange, durationRange: durationRange
        ))
        #expect(plan.iso == 50) // wanted ISO 10, clamped up: brighter than auto, no shortfall
        #expect(plan.evShortfallStops == 0)
        #expect(!plan.isoClamped)
    }

    @Test func durationIsMovedIntoTheSupportedRange() throws {
        let plan = try #require(ExposurePlanner.plan(
            autoDuration: 1.0 / 253, autoISO: 746, targetDuration: 1.0 / 100, isoRange: isoRange, durationRange: durationRange
        ))
        #expect(plan.durationAdjusted)
        #expect(plan.durationSeconds == 1.0 / 240) // longest the 240 fps format allows
    }

    @Test func invalidInputsGiveNoPlan() {
        #expect(ExposurePlanner.plan(
            autoDuration: 0,
            autoISO: 100,
            targetDuration: 0.001,
            isoRange: isoRange,
            durationRange: durationRange
        ) == nil)
        #expect(ExposurePlanner.plan(
            autoDuration: .nan,
            autoISO: 100,
            targetDuration: 0.001,
            isoRange: isoRange,
            durationRange: durationRange
        ) == nil)
        #expect(ExposurePlanner.plan(
            autoDuration: 0.004,
            autoISO: -1,
            targetDuration: 0.001,
            isoRange: isoRange,
            durationRange: durationRange
        ) == nil)
    }
}

struct TimingStatsTests {
    @Test func countsMeanMaxAndBudgetOverruns() {
        var t = TimingAccumulator(budget: 0.004)
        for ms in [1.0, 2.0, 3.0, 5.0, 6.0] {
            t.record(ms / 1000)
        }
        #expect(t.sampleCount == 5)
        #expect(abs((t.mean ?? 0) - 0.0034) < 1e-12)
        #expect(t.maximum == 0.006)
        #expect(t.overBudget == 2)
        #expect(t.overBudgetFraction == 0.4)
    }

    @Test func percentileResolvesToABucketEdge() {
        var t = TimingAccumulator(budget: 0.004)
        for _ in 0 ..< 99 {
            t.record(0.001)
        }
        t.record(0.0151) // one slow outlier
        let p50 = t.percentile(0.5) ?? 0
        let p99 = t.percentile(0.99) ?? 0
        let p100 = t.percentile(1.0) ?? 0
        #expect(p50 <= 0.00125 + 1e-12)
        #expect(p99 <= 0.00125 + 1e-12) // 99 of 100 samples are fast
        #expect(p100 >= 0.0151)
    }

    @Test func emptyAndInvalidSamplesAreUnknownNotZero() {
        var t = TimingAccumulator(budget: 0.004)
        #expect(t.mean == nil && t.percentile(0.99) == nil && t.overBudgetFraction == nil)
        t.record(-1)
        t.record(.nan)
        #expect(t.sampleCount == 0)
    }

    @Test func hugeSamplesGoToTheLastBucket() {
        var t = TimingAccumulator(budget: 0.004)
        t.record(5)
        #expect(t.sampleCount == 1)
        #expect(t.maximum == 5)
        #expect((t.percentile(1.0) ?? 0) >= 0.02 - 1e-9)
    }

    @Test func frameSizeStats() {
        #expect(FrameSizeStats(sizes: []) == nil)
        let s = FrameSizeStats(sizes: [45000, 470_000, 60000])
        #expect(s?.minBytes == 45000 && s?.maxBytes == 470_000)
        #expect(abs((s?.meanBytes ?? 0) - 191_666.6667) < 0.01)
    }
}

struct NewManifestFieldsTests {
    @Test func newFieldsRoundTripAndStayNilWhenUnknown() throws {
        var m = ManifestTests().manifest()
        #expect(m.deviceOrientation == nil && m.exposureSetting == nil && m.callbackTiming == nil)
        var setting = ExposureSetting(mode: "fixed")
        setting.requestedDurationSeconds = 1.0 / 2000
        setting.appliedISO = 3000
        setting.isoClamped = true
        setting.evShortfallStops = 0.98
        m.exposureSetting = setting
        m.deviceOrientation = "landscapeLeft"
        var timing = TimingAccumulator(budget: 1.0 / 240)
        timing.record(0.002)
        m.callbackTiming = timing.summary
        m.frameBytes = FrameSizeStats(sizes: [1, 2, 3])
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(CaptureManifest.self, from: enc.encode(m))
        #expect(back == m)
        #expect(back.exposureSetting?.evShortfallStops == 0.98)
    }
}
