import Testing
@testable import Analytics

// Fixture from spec F10a: means 224/160/130/110 m -> gaps 64/30/20; 5 iron + 7 iron selected -> 30.
@Suite struct GappingTests {
    func bag() -> [ClubDistances] {
        [("Driver", 224.0), ("5i", 160), ("7i", 130), ("PW", 110)].map { ClubDistances(clubID: $0.0, distancesM: [$0.1]) }
    }

    @Test func signedGaps() {
        let rows = Gapping.table(bag())
        #expect(rows.map(\.gapToNextM) == [64, 30, 20, nil])
    }

    @Test func subsetGap() {
        let rows = Gapping.table(bag().filter { ["5i", "7i"].contains($0.clubID) })
        #expect(rows[0].gapToNextM == 30)
    }

    @Test func inversionKeptNegative() {
        let rows = Gapping.table([ClubDistances(clubID: "a", distancesM: [100]), ClubDistances(clubID: "b", distancesM: [110])])
        #expect(rows[0].gapToNextM == -10)
    }

    @Test func noDataRowBreaksComparison() {
        let rows = Gapping.table([ClubDistances(clubID: "a", distancesM: [150]),
                                  ClubDistances(clubID: "b", distancesM: [nil, .nan]),
                                  ClubDistances(clubID: "c", distancesM: [130])])
        #expect(rows[0].gapToNextM == nil)
        #expect(rows[1].meanM == nil && rows[1].gapToNextM == nil)
    }

    @Test func provisionalBelowTenSamples() {
        #expect(Gapping.table(bag())[0].isProvisional)
        let ten = ClubDistances(clubID: "x", distancesM: Array(repeating: 100, count: 10))
        #expect(!Gapping.table([ten])[0].isProvisional)
    }
}
