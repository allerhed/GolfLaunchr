@testable import Capture
import Foundation
import Testing

/// Garage/bay session log: one CSV row per saved clip, so clips can be paired with the reference launch monitor's export.
struct SessionLogTests {
    func manifest(kind: String = "strike", block: String = "B3", seq: Int? = 12, notes: String? = nil) -> CaptureManifest {
        var m = ManifestTests().manifest()
        var shot = ShotInfo(club: "7 iron", lighting: "garage LED", location: "garage", trigger: "motion")
        shot.block = block
        shot.recordingKind = kind
        shot.sequenceInBlock = seq
        shot.ball = "white"
        shot.golferID = "g1"
        shot.outcomeNotes = notes
        m.shot = shot
        var setup = SetupInfo(handedness: "right")
        setup.distanceToBallM = 1.0
        setup.cameraHeightM = 0.2
        m.setup = setup
        var exposure = ExposureSetting(mode: "custom")
        exposure.requestedDurationSeconds = 0.0005
        exposure.appliedDurationSeconds = 0.0005
        exposure.appliedISO = 800
        m.exposureSetting = exposure
        var reference = ReferenceInfo(instrument: "Garmin Approach R10")
        reference.sessionID = block
        m.reference = reference
        return m
    }

    @Test func headerNamesEveryColumnOnce() {
        let columns = SessionLog.header.split(separator: ",").map(String.init)
        #expect(Set(columns).count == columns.count)
        #expect(columns.first == "createdUTC" && columns.contains("block") && columns.contains("seq") && columns.contains("clip"))
    }

    @Test func aRowHasOneValuePerColumnInTheSameOrder() {
        let row = SessionLog.row(manifest(), clipStem: "20261017T101500Z-abcd1234", exposurePreset: "1/2000")
        let header = SessionLog.header.split(separator: ",").map(String.init)
        let values = SessionLog.split(row)
        #expect(values.count == header.count)
        let dict = Dictionary(uniqueKeysWithValues: zip(header, values))
        #expect(dict["block"] == "B3" && dict["seq"] == "12" && dict["kind"] == "strike")
        #expect(dict["club"] == "7 iron" && dict["ball"] == "white" && dict["preset"] == "1/2000")
        #expect(dict["exposureS"] == "0.0005" && dict["iso"] == "800")
        #expect(dict["distanceM"] == "1" && dict["reference"] == "Garmin Approach R10")
        #expect(dict["clip"] == "20261017T101500Z-abcd1234")
    }

    @Test func missingValuesAreEmptyNeverZero() {
        var m = manifest(seq: nil)
        m.exposureSetting = nil
        m.setup = nil
        let dict = Dictionary(uniqueKeysWithValues: zip(
            SessionLog.header.split(separator: ",").map(String.init), SessionLog.split(SessionLog.row(
                m,
                clipStem: "x",
                exposurePreset: "auto"
            ))
        ))
        #expect(dict["seq"] == "" && dict["exposureS"] == "" && dict["iso"] == "" && dict["distanceM"] == "")
    }

    @Test func textWithCommasQuotesAndNewlinesIsQuoted() {
        let row = SessionLog.row(manifest(notes: "topped, \"thin\"\nre-tee"), clipStem: "x", exposurePreset: "auto")
        let values = SessionLog.split(row)
        let notes = values[SessionLog.header.split(separator: ",").firstIndex(of: "notes") ?? 0]
        #expect(notes == "topped, \"thin\"\nre-tee")
    }
}
