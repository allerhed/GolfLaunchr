@testable import Domain
import Testing

struct MeasurementTests {
    @Test func nonFiniteValuesAreRejected() {
        for bad in [Double.nan, .infinity, -.infinity] {
            #expect(throws: ContractError.nonFiniteValue("ballSpeed")) {
                try Measurement(key: .ballSpeed, value: bad, provenance: .measured, quality: .valid)
            }
        }
    }

    @Test func negativeMagnitudesRejectedButSignedMetricsAllowed() throws {
        #expect(throws: ContractError.negativeValue("carry")) {
            try Measurement(key: .carry, value: -0.1, provenance: .estimated, quality: .provisional)
        }
        #expect(try Measurement(key: .carry, value: 0, provenance: .estimated, quality: .provisional).value == 0)
        #expect(try Measurement(key: .lateralLanding, value: -12, provenance: .estimated, quality: .provisional).value == -12)
        #expect(try Measurement(key: .attackAngle, value: -0.05, provenance: .estimated, quality: .provisional).value == -0.05)
    }

    @Test func valueAndProvenanceMustAgree() {
        #expect(throws: ContractError.valueProvenanceMismatch(metric: "spinAxis")) {
            try Measurement(key: .spinAxis, value: 0, provenance: .unavailable, quality: .unsupported)
        }
        #expect(throws: ContractError.valueProvenanceMismatch(metric: "spinAxis")) {
            try Measurement(key: .spinAxis, value: nil, provenance: .estimated, quality: .provisional)
        }
    }

    @Test func uncertaintyNeedsAValueAndMustBeNonNegative() {
        #expect(throws: ContractError.uncertaintyInvalid(metric: "ballSpeed")) {
            try Measurement(key: .ballSpeed, value: 40, provenance: .measured, quality: .valid, uncertainty95: -1)
        }
        #expect(throws: ContractError.uncertaintyInvalid(metric: "ballSpeed")) {
            try Measurement(key: .ballSpeed, value: 40, provenance: .measured, quality: .valid, uncertainty95: .nan)
        }
        #expect(throws: ContractError.uncertaintyInvalid(metric: "clubSpeed")) {
            try Measurement(key: .clubSpeed, value: nil, provenance: .unavailable, quality: .unsupported, uncertainty95: 1)
        }
    }

    @Test func unavailableCarriesATypedReasonNotZero() {
        let m = Measurement.unavailable(.clubSpeed, failure: .blur)
        #expect(m.value == nil)
        #expect(m.provenance == .unavailable)
        #expect(m.failure == .blur)
        #expect(m.unit == .metresPerSecond)
    }

    @Test func everyMetricHasSIUnit() {
        #expect(MetricKey.allCases.count == 13)
        #expect(MetricKey.spinRate.unit == .radiansPerSecond) // rad/s, never rpm
        #expect(MetricKey.verticalLaunch.unit == .radians)
        #expect(MetricKey.carry.unit == .metres)
    }
}
