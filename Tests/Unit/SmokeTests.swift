import Testing
import Domain
import Analytics
@testable import GolfLaunchr

@Suite struct SmokeTests {
    @Test func appLinksPackages() {
        #expect(Statistics.mean([1, 3]) == 2)
        #expect(Gapping.table([]).isEmpty)
    }
}
