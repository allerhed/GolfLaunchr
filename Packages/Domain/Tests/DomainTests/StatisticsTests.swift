import Testing
@testable import Domain

// Fixture from spec F10a: [120,130,140] m -> mean 130, sample SD 10, range 120-140, P10/P90 122/138.
@Suite struct StatisticsTests {
    let xs: [Double] = [120, 130, 140]

    @Test func meanAndSD() {
        #expect(Statistics.mean(xs) == 130)
        #expect(abs(Statistics.sampleStandardDeviation(xs)! - 10) < 1e-12)
    }

    @Test func linearInterpolatedPercentiles() {
        #expect(abs(Statistics.quantile(xs, 0.10)! - 122) < 1e-12)
        #expect(abs(Statistics.quantile(xs, 0.90)! - 138) < 1e-12)
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
