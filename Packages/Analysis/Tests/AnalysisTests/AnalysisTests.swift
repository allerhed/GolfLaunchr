@testable import Analysis
import Capture
import Foundation
import Testing

struct FlickerTests {
    func series(hz: Double, depth: Double, n: Int = 480, fps: Double = 240, mean: Double = 0.4) -> [Double] {
        (0 ..< n).map { mean * (1 + depth * sin(2 * .pi * hz * Double($0) / fps)) }
    }

    @Test func findsMainsFlickerFrequencyAndDepth() throws {
        let r = try #require(FlickerAnalyzer.analyze(series(hz: 100, depth: 0.1), sampleRate: 240))
        #expect(abs(r.peakFrequencyHz - 100) <= r.resolutionHz)
        #expect(abs(r.relativeAmplitude - 0.1) < 0.005)
        let r2 = try #require(FlickerAnalyzer.analyze(series(hz: 50, depth: 0.03), sampleRate: 240))
        #expect(abs(r2.peakFrequencyHz - 50) <= r2.resolutionHz)
        #expect(abs(r2.relativeAmplitude - 0.03) < 0.005)
    }

    @Test func slowSceneChangesDoNotHideRealFlicker() throws {
        // A big 1 Hz brightness swing (someone moving, auto exposure) plus small 100 Hz mains flicker.
        let mixed = (0 ..< 480).map { 0.4 * (1 + 0.5 * sin(2 * .pi * 1 * Double($0) / 240) + 0.02 * sin(2 * .pi * 100 * Double($0) / 240)) }
        let r = try #require(FlickerAnalyzer.analyze(mixed, sampleRate: 240))
        #expect(abs(r.peakFrequencyHz - 100) <= r.resolutionHz)
        let slow = try #require(FlickerAnalyzer.analyze(mixed, sampleRate: 240, minimumFrequencyHz: 0))
        #expect(slow.peakFrequencyHz < 5) // without the floor, the slow swing wins
    }

    @Test func steadyLightHasNegligibleModulation() throws {
        let r = try #require(FlickerAnalyzer.analyze(series(hz: 100, depth: 0), sampleRate: 240))
        #expect(r.relativeAmplitude < 1e-9)
    }

    @Test func tooShortOrDarkSeriesGivesNoResult() {
        #expect(FlickerAnalyzer.analyze([0.1, 0.2, 0.3], sampleRate: 240) == nil)
        #expect(FlickerAnalyzer.analyze(Array(repeating: 0, count: 100), sampleRate: 240) == nil)
        #expect(FlickerAnalyzer.analyze(series(hz: 100, depth: 0.1), sampleRate: 0) == nil)
    }
}

struct SharpnessTests {
    func checker(_ blur: Bool) -> LumaFrame {
        var p = [UInt8](repeating: 0, count: 64 * 64)
        for y in 0 ..< 64 {
            for x in 0 ..< 64 {
                p[y * 64 + x] = ((x / 4 + y / 4) % 2 == 0) ? 220 : 20
            }
        }
        if blur { // 5x5 box blur
            var q = p
            for y in 2 ..< 62 {
                for x in 2 ..< 62 {
                    var s = 0
                    for dy in -2 ... 2 {
                        for dx in -2 ... 2 {
                            s += Int(p[(y + dy) * 64 + x + dx])
                        }
                    }
                    q[y * 64 + x] = UInt8(s / 25)
                }
            }
            p = q
        }
        guard let f = LumaFrame(width: 64, height: 64, pixels: p) else { preconditionFailure("valid") }
        return f
    }

    @Test func sharpImagesScoreHigherThanBlurredOnes() {
        let sharp = Sharpness.laplacianVariance(checker(false), step: 1)
        let blurred = Sharpness.laplacianVariance(checker(true), step: 1)
        #expect(sharp > 10 * blurred)
        #expect(blurred > 0)
    }

    @Test func flatImageScoresZero() {
        #expect(Sharpness.laplacianVariance(Synthetic.frame(), step: 1) == 0)
    }

    @Test func invalidFramesAreRejected() {
        #expect(LumaFrame(width: 2, height: 2, pixels: [1, 2, 3]) == nil)
        #expect(LumaFrame(width: 0, height: 2, pixels: []) == nil)
    }
}

struct DiscTrackerTests {
    @Test func centroidIsAccurateToSubPixel() throws {
        let d = try #require(DiscTracker.detect(Synthetic.frame(disc: Disc(x: 60.3, y: 40.7, r: 6)), threshold: 128))
        #expect(abs(d.x - 60.3) < 0.5 && abs(d.y - 40.7) < 0.5)
        #expect(abs(d.radius - 6) < 0.6)
    }

    @Test func nothingBrightMeansNoDetection() {
        #expect(DiscTracker.detect(Synthetic.frame(), threshold: 128) == nil)
    }

    @Test func knownMotionGivesTheKnownSpeed() {
        // 6 px per frame at 240 fps and 0.5 mm per pixel => 6 * 0.0005 * 240 = 0.72 m/s
        let clip = Synthetic.clip(count: 12, still: 0, dx: 6)
        let detections = clip.map { DiscTracker.detect($0.frame, threshold: 128) }
        let speed = DiscTracker.medianSpeed(detections: detections, pts: clip.map(\.pts), metresPerPixel: 0.0005)
        #expect(abs((speed ?? 0) - 0.72) < 0.02)
    }

    @Test func missingFramesDoNotInflateSpeedBecauseTimestampsAreUsed() {
        let clip = Synthetic.clip(count: 20, still: 0, dx: 6, skipping: [5, 6]) // two frames missing
        let detections = clip.map { DiscTracker.detect($0.frame, threshold: 128) }
        let speed = DiscTracker.medianSpeed(detections: detections, pts: clip.map(\.pts), metresPerPixel: 0.0005)
        #expect(abs((speed ?? 0) - 0.72) < 0.03) // the 18 px jump spans 3 frame intervals in PTS
    }

    @Test func tooFewDetectionsGiveNoSpeed() {
        #expect(DiscTracker.medianSpeed(detections: [nil, nil], pts: [0, 1], metresPerPixel: 1) == nil)
        #expect(DiscTracker.medianSpeed(detections: [], pts: [], metresPerPixel: 1) == nil)
    }
}

struct ClipAnalyzerTests {
    func run(_ clip: [(pts: Double, frame: LumaFrame)]) -> ClipReport {
        var analyzer = ClipAnalyzer(nominalFrameRate: 240)
        for item in clip {
            analyzer.ingest(pts: item.pts, frame: item.frame)
        }
        return analyzer.report()
    }

    @Test func cleanClipHasNoGapsAndTheMeasuredRate() {
        let r = run(Synthetic.clip(count: 300))
        #expect(r.timing.frames == 300)
        #expect(r.timing.gapEvents == 0 && r.timing.missingFrames == 0)
        #expect(abs((r.timing.measuredFrameRate ?? 0) - 240) < 0.01)
        #expect(r.timing.fractionWithinTolerance == 1)
    }

    @Test func injectedGapIsLocatedAndCounted() {
        let r = run(Synthetic.clip(count: 300, skipping: [100, 101, 102]))
        #expect(r.timing.gapEvents == 1)
        #expect(r.timing.missingFrames == 3)
        #expect(r.timing.gaps == [GapPosition(afterFrameIndex: 99, missingFrames: 3)])
    }

    @Test func motionStartIsDetectedAfterTheStillPeriod() {
        // A 5 px disc touches at most one grid sample, so use a sensitive threshold for this tiny target.
        var analyzer = ClipAnalyzer(nominalFrameRate: 240, motionThreshold: 0.2)
        for item in Synthetic.clip(count: 120, still: 40, dx: 8) {
            analyzer.ingest(pts: item.pts, frame: item.frame)
        }
        let r = analyzer.report()
        let first = r.motionTriggerFrames.first ?? -1
        #expect(first >= 41 && first <= 46) // the disc first moves at frame 41
        #expect(r.peakMotionFrame != nil)
    }

    @Test func aLargeMovingObjectTriggersTheDefaultThreshold() {
        // A big bright block sweeping across the view, like a hand or club head close to the camera.
        var analyzer = ClipAnalyzer(nominalFrameRate: 240)
        for i in 0 ..< 100 {
            let moving = i >= 50
            let frame = Synthetic.frame(disc: moving ? Disc(x: Double(i - 50) * 3, y: 45, r: 40) : nil)
            analyzer.ingest(pts: 100 + Double(i) / 240, frame: frame)
        }
        let r = analyzer.report()
        #expect((r.motionTriggerFrames.first ?? 0) >= 50)
        #expect(r.motionTriggerFrames.count >= 1)
    }

    @Test func staticSceneNeverTriggers() {
        #expect(run(Synthetic.clip(count: 200, still: 1000)).motionTriggerFrames.isEmpty)
    }

    @Test func flickerInTheClipIsReported() {
        let r = run(Synthetic.clip(count: 480, still: 1000, flickerHz: 100, flickerDepth: 0.2))
        let f = r.flicker
        #expect(abs((f?.peakFrequencyHz ?? 0) - 100) <= (f?.resolutionHz ?? 0))
        #expect((f?.relativeAmplitude ?? 0) > 0.15)
    }

    @Test func reportRoundTripsAsJSON() throws {
        let r = run(Synthetic.clip(count: 100, skipping: [50]))
        let back = try JSONDecoder().decode(ClipReport.self, from: JSONEncoder().encode(r))
        #expect(back == r)
        #expect(back.schema == "g1-report/1")
    }
}

struct ConsistencyTests {
    /// A manifest as the phone would have written it for frames with these timestamps (stats from the real FrameClock).
    func manifest(pts: [Double]) -> CaptureManifest {
        var clock = FrameClock(nominalFrameRate: 240)
        for p in pts {
            clock.ingest(pts: p)
        }
        let stats = clock.stats
        let format = CaptureFormatDescriptor(
            id: "x", lens: .wide, width: 160, height: 90, maxFrameRate: 240, fieldOfViewDegrees: 75
        )
        return CaptureManifest(
            createdUTC: Date(), device: DeviceInfo(machine: "m", osVersion: "1", appBuild: "1"), format: format, requestedFrameRate: 240,
            orientation: "o", timing: TimingSummary(stats: stats, dropped: DroppedFrameLog(), firstPTS: 0, lastPTS: 1, triggerPTS: 0.5),
            isComplete: true
        )
    }

    @Test func matchingManifestHasNoProblemsAndMismatchesAreNamed() {
        var analyzer = ClipAnalyzer(nominalFrameRate: 240)
        let clip = Synthetic.clip(count: 100, skipping: [50])
        for item in clip {
            analyzer.ingest(pts: item.pts, frame: item.frame)
        }
        let report = analyzer.report()
        #expect(ManifestConsistency.compare(report: report, manifest: manifest(pts: clip.map(\.pts))).isEmpty)
        let lying = manifest(pts: Synthetic.clip(count: 100).map(\.pts)) // manifest claims a clean clip
        let problems = ManifestConsistency.compare(report: report, manifest: lying)
        #expect(problems.count == 3)
        #expect(problems.contains { $0.contains("missing frames") })
    }
}

struct TimestampQuantizationTests {
    func analyze(_ pts: [Double]) -> TimingReport {
        var analyzer = ClipAnalyzer(nominalFrameRate: 240)
        let frame = Synthetic.frame()
        for p in pts {
            analyzer.ingest(pts: p, frame: frame, measureSharpness: false)
        }
        return analyzer.report().timing
    }

    @Test func aCoarseContainerTimescaleIsDetectedAndExplained() {
        // What a real D1 file contains: perfect 240 fps stored at 1/600 s => intervals alternate 3 and 2 ticks.
        let pts = (0 ..< 480).map { (Double($0) / 240 * 600).rounded() / 600 + 100 }
        let t = analyze(pts)
        #expect(t.quantizedTimescale == 600)
        #expect(t.jitterEvents > 400) // the container makes every interval look uneven
        #expect(t.fractionWithinOneTick == 1) // but within one tick of nominal, which is the meaningful figure
        #expect(t.gapEvents == 0)
    }

    @Test func realisticFineTimestampsAreNotFlagged() {
        // Camera PTS carry microsecond-level variation: not a whole number of ticks in any candidate timescale.
        let pts = (0 ..< 480).map { 100.123456789 + Double($0) / 240 + 1e-5 * sin(Double($0)) }
        let t = analyze(pts)
        #expect(t.quantizedTimescale == nil && t.fractionWithinOneTick == nil)
        #expect(PTSResolution.detect(pts) == nil)
    }

    @Test func aPerfectlyPacedStreamIsNotFlaggedEvenThoughItFitsSomeTimescales() {
        let pts = (0 ..< 480).map { 100 + Double($0) / 240 }
        #expect(analyze(pts).quantizedTimescale == nil)
        #expect(analyze(pts).jitterEvents == 0)
    }

    @Test func aRealGapIsStillAGapInAQuantizedFile() {
        var pts = (0 ..< 480).map { (Double($0) / 240 * 600).rounded() / 600 + 100 }
        pts.removeSubrange(100 ..< 103)
        let t = analyze(pts)
        #expect(t.gapEvents == 1 && t.missingFrames == 3)
    }
}
