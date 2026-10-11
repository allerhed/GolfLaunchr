@testable import Capture
import Foundation
import Testing

struct MotionDetectorTests {
    func grid(_ v: UInt8, cols: Int = 8, rows: Int = 4) -> LumaGrid {
        guard let g = LumaGrid(columns: cols, rows: rows, values: Array(repeating: v, count: cols * rows)) else {
            preconditionFailure("test grid sizes are valid")
        }
        return g
    }

    @Test func invalidGridIsRejected() {
        #expect(LumaGrid(columns: 2, rows: 2, values: [1, 2, 3]) == nil)
        #expect(LumaGrid(columns: 0, rows: 2, values: []) == nil)
    }

    @Test func staticSceneNeverTriggersAndFirstFrameOnlySetsReference() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 10)
        let results = (0 ..< 100).map { _ in d.ingest(grid(100)) }
        #expect(!results.contains(true))
        #expect(d.lastScore == 0)
    }

    @Test func largeChangeTriggersOnceThenCooldownSuppresses() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 10)
        _ = d.ingest(grid(100))
        let first = d.ingest(grid(150)) // diff 50
        #expect(first)
        var values: [UInt8] = [100, 150, 100, 150, 100]
        values += values
        let again = values.map { d.ingest(grid($0)) }
        #expect(!again.contains(true)) // within the 10-frame cooldown
    }

    @Test func triggersAgainAfterCooldown() {
        var d = MotionDetector(threshold: 5, cooldownFrames: 3)
        _ = d.ingest(grid(0))
        let first = d.ingest(grid(100))
        #expect(first)
        for _ in 0 ..< 3 {
            _ = d.ingest(grid(100))
        }
        let second = d.ingest(grid(0))
        #expect(second)
    }

    @Test func thresholdBoundaryIsInclusive() {
        var below = MotionDetector(threshold: 5, cooldownFrames: 0)
        _ = below.ingest(grid(100))
        let belowResult = below.ingest(grid(104)) // score 4
        #expect(!belowResult)
        var at = MotionDetector(threshold: 5, cooldownFrames: 0)
        _ = at.ingest(grid(100))
        let atResult = at.ingest(grid(105)) // score 5
        #expect(atResult)
    }

    @Test func gridSizeChangeResetsReference() {
        var d = MotionDetector(threshold: 1, cooldownFrames: 0)
        _ = d.ingest(grid(0))
        let result = d.ingest(grid(255, cols: 4, rows: 4))
        #expect(!result)
        #expect(d.lastScore == nil)
    }

    @Test func scoreIsMeanAbsoluteDifference() throws {
        var d = MotionDetector(threshold: 1000, cooldownFrames: 0)
        let a = LumaGrid(columns: 2, rows: 1, values: [0, 100])
        let b = LumaGrid(columns: 2, rows: 1, values: [50, 100])
        _ = try d.ingest(#require(a))
        _ = try d.ingest(#require(b))
        #expect(d.lastScore == 25)
    }
}

struct ManifestBuilderTests {
    func builder() -> ManifestBuilder {
        ManifestBuilder(
            device: DeviceInfo(machine: "iPhone18,2", osVersion: "27.0.1", appBuild: "1"),
            format: format("240-wide", fps: 240), requestedFrameRate: 240, orientation: "landscapeRight",
            stabilizationApplied: "off", hdrApplied: false
        )
    }

    func window(complete: Bool, skipping: Set<Int> = []) async -> CapturedWindow<Int>? {
        let p = CapturePipeline<Int>(nominalFrameRate: 240, maxFrames: 400, maxBytes: 10_000_000, preSeconds: 0.25, postSeconds: 0.25)
        var done: CapturedWindow<Int>?
        for (i, f) in FakeFrames.make(count: 300, skipping: skipping).enumerated() {
            if i == 100 {
                await p.trigger()
            }
            if i == 130, !complete {
                return await p.pause(.interruption)
            }
            if let w = await p.ingest(f) {
                done = w
            }
        }
        return done
    }

    @Test func buildsFromACompleteWindowAndFiltersExposureToIt() async throws {
        let w = try #require(await window(complete: true, skipping: [110]))
        var tel = TelemetryLog()
        tel.record(ExposureSample(time: 50, durationSeconds: 0.001, iso: 100)) // before window
        tel.record(ExposureSample(time: 100 + 120.0 / 240, durationSeconds: 0.0005, iso: 200)) // inside
        tel.record(ExposureSample(time: 5000, durationSeconds: 0.001, iso: 100)) // after
        tel.record(thermal: .fair, at: 100)
        var drops = DroppedFrameLog()
        drops.record(.frameWasLate)
        let m = builder().build(window: w, dropped: drops, telemetry: tel, createdUTC: Date(timeIntervalSince1970: 1_791_716_400))
        #expect(m.isComplete)
        #expect(m.exposure.count == 1)
        #expect(m.exposure.first?.iso == 200)
        #expect(m.timing.missingFrames == 1)
        #expect(m.timing.droppedByReason == ["frameWasLate": 1])
        #expect(m.timing.triggerPTS == w.triggerPTS)
        #expect(m.stabilizationApplied == "off")
        #expect(m.thermal.count == 1)
        #expect(m.setup == nil && m.reference == nil)
    }

    @Test func interruptedWindowIsMarkedIncomplete() async throws {
        let w = try #require(await window(complete: false))
        let m = builder().build(window: w, dropped: DroppedFrameLog(), telemetry: TelemetryLog(), createdUTC: Date())
        #expect(m.isComplete == false)
    }

    @Test func clipStemIsSortableAndSafe() throws {
        let id = try #require(UUID(uuidString: "1A2B3C4D-0000-4000-8000-000000000000"))
        let stem = ClipNaming.stem(createdUTC: Date(timeIntervalSince1970: 1_791_716_400), id: id)
        #expect(stem == "20261011T110000Z-1a2b3c4d")
        let later = ClipNaming.stem(createdUTC: Date(timeIntervalSince1970: 1_791_716_401), id: id)
        #expect(stem < later)
    }
}
