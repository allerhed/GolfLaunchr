import Analytics
import Domain
@testable import GolfLaunchr
import Testing

struct SmokeTests {
    @Test func appLinksPackages() {
        #expect(Statistics.mean([1, 3]) == 2)
        #expect(Gapping.table([]).isEmpty)
    }
}
