@testable import Capture
import Testing

private func format(_ id: String, fps: Double, height: Int = 1080, lens: LensKind = .wide) -> CaptureFormatDescriptor {
    CaptureFormatDescriptor(id: id, lens: lens, width: height * 16 / 9, height: height, maxFrameRate: fps, fieldOfViewDegrees: 70)
}

private let gb: Int64 = 1_000_000_000

struct CapabilityTests {
    func facts(
        model: String = "iPhone18,2",
        os: Int = 26,
        free: Int64 = 40 * gb,
        formats: [CaptureFormatDescriptor]? = nil
    ) -> DeviceFacts {
        DeviceFacts(modelIdentifier: model, osMajorVersion: os, freeStorageBytes: free, formats: formats ?? [format("a", fps: 240)])
    }

    /// An unvalidated device can never be Supported, however good its camera is (F01 acceptance).
    @Test func capableButUnvalidatedDeviceIsExperimentalNeverSupported() {
        let report = CapabilityQualifier.qualify(facts())
        #expect(report.status == .experimental && report.reasons == [.noValidatedProfile] && report.bestFormatID == "a")
    }

    @Test func onlyAnExplicitlyValidatedProfileWithADualCapableFormatIsSupported() {
        let supported = CapabilityQualifier.qualify(facts(), validatedModels: ["iPhone18,2"])
        #expect(supported.status == .supported && supported.reasons.isEmpty)
        // Validated model, but its camera no longer offers 240 fps -> not Supported.
        let slow = CapabilityQualifier.qualify(facts(formats: [format("b", fps: 120)]), validatedModels: ["iPhone18,2"])
        #expect(slow.status == .experimental && slow.reasons.contains(.belowValidatedFrameRate))
        // Another model is not covered by the list.
        #expect(CapabilityQualifier.qualify(facts(model: "iPhone99,9"), validatedModels: ["iPhone18,2"]).status == .experimental)
    }

    @Test func blockingProblemsMakeTheDeviceUnsupportedWithEachReason() {
        #expect(CapabilityQualifier.qualify(facts(os: 17)).reasons.contains(.osTooOld))
        #expect(CapabilityQualifier.qualify(facts(formats: [])).reasons == [.noCamera])
        #expect(CapabilityQualifier.qualify(facts(formats: [format("s", fps: 60)])).reasons.contains(.noHighFrameRate))
        #expect(CapabilityQualifier.qualify(facts(free: 1 * gb)).reasons.contains(.storageCritical))
        let blocked = [facts(os: 17), facts(formats: []), facts(formats: [format("s", fps: 60)]), facts(free: 1 * gb)]
        for report in blocked.map({ CapabilityQualifier.qualify($0) }) {
            #expect(report.status == .unsupported && report.bestFormatID == nil)
        }
    }

    @Test func lowButUsableStorageIsAWarningNotABlock() {
        let report = CapabilityQualifier.qualify(facts(free: 6 * gb))
        #expect(report.status == .experimental && report.reasons == [.noValidatedProfile, .storageLow])
    }

    @Test func allReasonsAreReportedTogetherInAStableOrder() {
        let report = CapabilityQualifier.qualify(facts(os: 16, free: 1 * gb, formats: [format("s", fps: 30)]))
        #expect(report.reasons == [.osTooOld, .noHighFrameRate, .storageCritical])
    }

    @Test func bestFormatIsTheFastestUsableOne() {
        let formats = [format("slow", fps: 120), format("fast", fps: 240), format("tiny", fps: 240, height: 360)]
        #expect(CapabilityQualifier.qualify(facts(formats: formats)).bestFormatID == "fast")
    }
}
