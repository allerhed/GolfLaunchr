@testable import Capture
import Foundation
import Testing

struct ManifestTests {
    func manifest() -> CaptureManifest {
        var clock = FrameClock(nominalFrameRate: 240)
        for f in FakeFrames.make(count: 10, skipping: [4]) {
            clock.ingest(pts: f.pts)
        }
        var dropped = DroppedFrameLog()
        dropped.record(.frameWasLate)
        return CaptureManifest(
            createdUTC: Date(timeIntervalSince1970: 1_791_716_400),
            device: DeviceInfo(machine: "iPhone16,1", osVersion: "18.0", appBuild: "1"),
            format: format("240-wide", fps: 240),
            requestedFrameRate: 240,
            orientation: "landscapeRight",
            timing: TimingSummary(stats: clock.stats, dropped: dropped, firstPTS: 100, lastPTS: 100.04, triggerPTS: 100.02),
            exposure: [ExposureSample(time: 100, durationSeconds: 1.0 / 2000, iso: 400)],
            thermal: [ThermalSample(time: 100, level: .fair)],
            isComplete: true
        )
    }

    private func roundTrip(_ m: CaptureManifest) throws -> CaptureManifest {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(CaptureManifest.self, from: enc.encode(m))
    }

    @Test func roundTripIsLossless() throws {
        var m = manifest()
        m.setup = SetupInfo(handedness: "right", distanceToBallM: 0.75, cameraHeightM: 0.2)
        m.shot = ShotInfo(club: "7 iron", lighting: "indoor bright", location: "bay", trigger: "manual")
        var ref = ReferenceInfo(instrument: "reference-monitor")
        ref.ballSpeedMetresPerSecond = 45.2
        m.reference = ref
        #expect(try roundTrip(m) == m)
    }

    @Test func unknownValuesStayNilNeverZero() throws {
        var m = manifest()
        m.reference = ReferenceInfo(instrument: "reference-monitor")
        let back = try roundTrip(m)
        #expect(back.reference?.ballSpeedMetresPerSecond == nil)
        #expect(back.reference?.carryMetres == nil)
        #expect(back.stabilizationApplied == nil)
        #expect(back.hdrApplied == nil)
        #expect(back.setup == nil)
    }

    @Test func timingSummaryReflectsGapsAndDrops() {
        let t = manifest().timing
        #expect(t.missingFrames == 1)
        #expect(t.gapEvents == 1)
        #expect(t.droppedByReason == ["frameWasLate": 1])
        #expect(t.frameCount == 9)
    }

    /// Real D1 manifests were written before `runDroppedByReason`, `deviceOrientation`, `exposureSetting`, `callbackTiming` and
    /// `frameBytes` existed. They must stay readable.
    @Test func manifestsFromBeforeTheNewFieldsStillDecode() throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(manifest())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["deviceOrientation", "exposureSetting", "callbackTiming", "frameBytes"] {
            object[key] = nil
        }
        var timing = try #require(object["timing"] as? [String: Any])
        timing["runDroppedByReason"] = nil
        object["timing"] = timing
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let old = try dec.decode(CaptureManifest.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.timing.runDroppedByReason == nil)
        #expect(old.deviceOrientation == nil && old.exposureSetting == nil && old.callbackTiming == nil && old.frameBytes == nil)
        #expect(old.timing.droppedByReason == ["frameWasLate": 1])
    }

    @Test func schemaIsVersioned() throws {
        #expect(manifest().schema == "g1-manifest/1")
        let enc = JSONEncoder()
        enc.outputFormatting = .withoutEscapingSlashes
        let json = try String(data: enc.encode(manifest()), encoding: .utf8) ?? ""
        #expect(json.contains("g1-manifest/1"))
    }
}

struct TelemetryTests {
    @Test func thermalLogStoresOnlyChanges() {
        var log = TelemetryLog()
        let results = [
            log.record(thermal: .nominal, at: 0), log.record(thermal: .nominal, at: 1), log.record(thermal: .fair, at: 2),
            log.record(thermal: .serious, at: 3), log.record(thermal: .fair, at: 4),
        ]
        #expect(results == [true, false, true, true, true])
        #expect(log.thermal.count == 4)
        #expect(log.worstThermalLevel == .serious)
    }

    @Test func exposureLogIsBounded() {
        var log = TelemetryLog(maxExposureSamples: 100)
        for i in 0 ..< 250 {
            log.record(ExposureSample(time: Double(i), durationSeconds: 0.001, iso: 100))
        }
        #expect(log.exposure.count == 100)
        #expect(log.exposure.first?.time == 150)
        #expect(log.droppedExposureSamples > 0)
    }

    @Test func platformThermalStatesMap() {
        #expect(ThermalLevel(.nominal) == .nominal)
        #expect(ThermalLevel(.fair) == .fair)
        #expect(ThermalLevel(.serious) == .serious)
        #expect(ThermalLevel(.critical) == .critical)
        #expect(ThermalLevel.critical > ThermalLevel.nominal)
    }
}
