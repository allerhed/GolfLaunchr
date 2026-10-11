@testable import Domain
import Testing

/// Fixture from spec F10a: [120,130,140] m -> mean 130, sample SD 10, range 120-140, P10/P90 122/138.
struct StatisticsTests {
    let xs: [Double] = [120, 130, 140]

    @Test func meanAndSD() throws {
        #expect(Statistics.mean(xs) == 130)
        #expect(try abs(#require(Statistics.sampleStandardDeviation(xs)) - 10) < 1e-12)
    }

    @Test func linearInterpolatedPercentiles() throws {
        #expect(try abs(#require(Statistics.quantile(xs, 0.10)) - 122) < 1e-12)
        #expect(try abs(#require(Statistics.quantile(xs, 0.90)) - 138) < 1e-12)
        #expect(Statistics.median(xs) == 130)
    }

    @Test func sdUnavailableForZeroOrOneSample() {
        #expect(Statistics.sampleStandardDeviation([]) == nil)
        #expect(Statistics.sampleStandardDeviation([5]) == nil)
        #expect(Statistics.mean([]) == nil)
    }

    @Test func nullsAndNonFiniteAreOmittedNotZeroFilled() {
        let c = Statistics.clean([120, nil, .nan, .infinity, 140])
        #expect(c == [120, 140])
        #expect(Statistics.mean(c) == 130)
    }
}
