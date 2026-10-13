@testable import Analytics
import Domain
import Foundation
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400)

private func club(_ name: String) -> ClubSnapshot {
    guard let c = try? ClubSnapshot(id: UUID(), name: name, loftRad: nil) else { preconditionFailure("club") }
    return c
}

private func shot(
    _ club: ClubSnapshot, carry: Double? = nil, total: Double? = nil, lateral: Double? = nil, session: UUID = UUID(),
    seq: Int = 1, included: Bool = true, mode: ShotMode = .practice, at: Date = t0, pressure: Double = 101_325,
    carryQuality: MetricQuality = .provisional
) throws -> Shot {
    var m: [MetricKey: Domain.Measurement] = [:]
    if let carry {
        m[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: carryQuality)
    }
    if let total {
        m[.totalDistance] = try Domain.Measurement(
            key: .totalDistance,
            value: total,
            provenance: .estimated,
            quality: .provisional
        )
    }
    if let lateral {
        m[.lateralLanding] = try Domain.Measurement(key: .lateralLanding, value: lateral, provenance: .estimated, quality: .provisional)
    }
    return try Shot(
        id: UUID(), sessionID: session, sequence: seq, mode: mode, swingHandedness: .right, clubSnapshot: club,
        calibrationID: UUID(), impactTimeUTC: at, metrics: m,
        environment: Environment(pressurePa: pressure, temperatureK: 288.15, source: .standard),
        versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), included: included, isSynthetic: true
    )
}

private func profiles(_ shots: [Shot], _ f: AnalysisFilter = AnalysisFilter(), order: [UUID] = []) -> [ClubProfile] {
    ClubAnalysis.profiles(ShotSelection.select(shots, filter: f, now: t0).shots, filter: f, bagOrder: order)
}

struct ClubProfileTests {
    /// Spec fixture: [120,130,140] -> mean 130, sample SD 10, range 120-140, linear P10/P90 122/138.
    @Test func specFixture() throws {
        let c = club("7i")
        let p = try #require(try profiles([120, 130, 140].map { try shot(c, carry: $0) }).first)
        #expect(p.mean == 130 && p.median == 130 && p.spread == 10 && p.shortest == 120 && p.longest == 140)
        let p10 = try #require(p.p10), p90 = try #require(p.p90)
        #expect(abs(p10 - 122) < 1e-9 && abs(p90 - 138) < 1e-9)
        #expect(p.isProvisional && p.distanceSamples == 3)
    }

    @Test func zeroOneAndTwoSamples() throws {
        let c = club("7i")
        let none = try #require(try profiles([shot(c)]).first) // shot without carry
        #expect(none.mean == nil && none.spread == nil && none.median == nil && none.distanceSamples == 0 && none.shotCount == 1)
        let one = try #require(try profiles([shot(c, carry: 100)]).first)
        #expect(one.mean == 100 && one.spread == nil && one.median == 100 && one.p10 == 100)
        let two = try #require(try profiles([100, 110].map { try shot(c, carry: $0) }).first)
        let sd = try #require(two.spread)
        #expect(abs(sd - 50.0.squareRoot()) < 1e-9) // n-1: sqrt(50)
    }

    @Test func tenSamplesAreNoLongerProvisional() throws {
        let c = club("7i")
        let nine = try #require(try profiles((0 ..< 9).map { try shot(c, carry: 100 + Double($0)) }).first)
        let ten = try #require(try profiles((0 ..< 10).map { try shot(c, carry: 100 + Double($0)) }).first)
        #expect(nine.isProvisional && !ten.isProvisional)
    }

    @Test func invalidUnavailableAndNonFiniteAreOmittedNeverZeroFilled() throws {
        let c = club("7i")
        let shots = try [
            shot(c, carry: 100), shot(c, carry: 999, carryQuality: .invalid), shot(c),
            shot(c, carry: 120)
        ]
        let p = try #require(profiles(shots).first)
        #expect(p.mean == 110 && p.distanceSamples == 2 && p.shotCount == 4)
    }

    @Test func pooledAcrossSessionsNotAverageOfAverages() throws {
        let c = club("7i")
        let a = UUID(), b = UUID()
        // session a: 1 shot at 100; session b: 3 shots at 200 -> pooled mean 175, not (100+200)/2
        let shots = try [shot(c, carry: 100, session: a)] + [200, 200, 200].map { try shot(c, carry: $0, session: b) }
        #expect(try #require(profiles(shots).first).mean == 175)
    }

    @Test func exclusionAndRestoreRecomputeWithoutTouchingTheShot() throws {
        let c = club("7i")
        var shots = try [100, 120, 200].map { try shot(c, carry: $0) }
        #expect(try #require(profiles(shots).first).mean == 140)
        shots[2].included = false
        let p = try #require(profiles(shots).first)
        #expect(p.mean == 110 && p.shotCount == 2)
        #expect(shots[2].metrics[.carry]?.value == 200) // the measurement itself is untouched
        shots[2].included = true
        #expect(try #require(profiles(shots).first).mean == 140)
    }

    @Test func carryAndTotalNeverMix() throws {
        let c = club("7i")
        let shots = try [shot(c, carry: 100, total: 110), shot(c, carry: 120, total: 140)]
        var f = AnalysisFilter()
        #expect(try #require(profiles(shots, f).first).mean == 110)
        f.distance = .total
        #expect(try #require(profiles(shots, f).first).mean == 125)
    }

    @Test func metricMeansCarryCoverageAndEstimatedLabel() throws {
        let c = club("7i")
        let shots = try [shot(c, carry: 100), shot(c, carry: 120)]
        let p = try #require(profiles(shots).first)
        let carryLike = try #require(p.metrics.first { $0.key == .ballSpeed })
        #expect(carryLike.validSamples == 0 && carryLike.mean == nil) // missing coverage is visible, not zero
    }
}

struct SelectionFilterTests {
    @Test func clubsCombineByOrOthersByAnd() throws {
        let a = club("7i"), b = club("PW"), d = club("Driver")
        let s1 = UUID()
        let shots = try [
            shot(a, carry: 130, session: s1, mode: .practice), shot(b, carry: 100, session: s1, mode: .practice),
            shot(d, carry: 220, session: s1, mode: .practice), shot(a, carry: 131, session: UUID(), mode: .target)
        ]
        var f = AnalysisFilter()
        f.clubs = .some([a.id, b.id])
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 3) // OR across clubs
        f.mode = .practice
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 2) // AND with mode
        f.sessionIDs = [s1]
        f.clubs = .some([a.id])
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 1)
    }

    @Test func sessionScopeRestrictsToThatSession() throws {
        let a = club("7i")
        let s1 = UUID(), s2 = UUID()
        let shots = try [shot(a, carry: 100, session: s1), shot(a, carry: 200, session: s2)]
        var f = AnalysisFilter()
        f.sessionIDs = [s1]
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 1)
        #expect(try #require(profiles(shots, f).first).mean == 100)
        f.sessionIDs = nil
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 2)
    }

    @Test func inclusionRangeAndAllClubs() throws {
        let a = club("7i")
        let shots = try [
            shot(a, carry: 1, included: false), shot(a, carry: 2),
            shot(a, carry: 3, at: t0.addingTimeInterval(-40 * 86400))
        ]
        var f = AnalysisFilter()
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 2) // default: included only
        f.inclusion = .all
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 3)
        f.inclusion = .excluded
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 1)
        f.inclusion = .all
        f.range = .last30Days
        #expect(ShotSelection.select(shots, filter: f, now: t0).shots.count == 2)
    }

    @Test func duplicateNamesStaySeparateAndArchivedClubsRemainSelectable() throws {
        let a = club("7 iron"), b = club("7 iron")
        let shots = try [shot(a, carry: 130), shot(b, carry: 150)]
        let ps = profiles(shots)
        #expect(ps.count == 2 && Set(ps.map(\.clubID)).count == 2) // same name, two IDs
        var f = AnalysisFilter()
        f.clubs = .some([b.id]) // an id with no current bag entry (archived) still selects its shots
        #expect(try #require(profiles(shots, f).first).mean == 150)
    }

    @Test func selectionToggleAndEmptySelection() {
        let id = UUID()
        var sel = ClubSelection.all
        sel = sel.toggling(id)
        #expect(sel == .some([id])) // choosing a club clears All clubs
        sel = sel.toggling(id)
        #expect(sel.isEmpty) // visible empty selection
        var f = AnalysisFilter()
        f.clubs = sel
        #expect(!f.canApply)
    }

    @Test func editorApplyCancelClear() {
        var e = AnalysisFilterEditor()
        e.draft.distance = .total
        e.draft.clubs = .some([UUID()])
        e.cancel()
        #expect(e.applied == AnalysisFilter() && e.draft == AnalysisFilter()) // cancelled draft leaves the applied filter
        e.draft.distance = .total
        #expect(e.apply() && e.applied.distance == .total)
        e.draft.clubs = .some([])
        #expect(!e.apply() && e.applied.clubs == .all) // empty selection cannot be applied; nothing half-applied
        e.clear()
        #expect(e.draft == AnalysisFilter() && e.applied.distance == .total) // clear is a draft until Apply
    }

    @Test func standardisedWithoutAModelHasZeroCoverageNotRecordedNumbers() throws {
        let a = club("7i")
        var f = AnalysisFilter()
        f.conditions = .standardised
        let p = try #require(try profiles([shot(a, carry: 130)], f).first)
        #expect(p.mean == nil && p.distanceSamples == 0 && p.shotCount == 1)
        let withModel = try ClubAnalysis.profiles(
            [shot(a, carry: 130)], filter: f, standardiser: { _, _ in 133 }
        )
        #expect(withModel.first?.mean == 133)
    }
}

struct ClubGappingFilterTests {
    private func bagShots() throws -> ([ClubSnapshot], [Shot]) {
        let cs = [club("Driver"), club("5i"), club("7i"), club("PW")]
        let shots = try zip(cs, [224.0, 160, 130, 110]).map { try shot($0, carry: $1) }
        return (cs, shots)
    }

    @Test func specFixtureGapsAndSubset() throws {
        let (cs, shots) = try bagShots()
        let all = profiles(shots, order: cs.map(\.id))
        let table = ClubGapping.table(all, filter: AnalysisFilter(), eligibleClubCount: 4)
        #expect(table.rows.map(\.gapToNextM) == [64, 30, 20, nil] && !table.selectedClubsOnly)
        var f = AnalysisFilter()
        f.clubs = .some([cs[1].id, cs[2].id])
        let sub = ClubGapping.table(profiles(shots, f, order: cs.map(\.id)), filter: f, eligibleClubCount: 4)
        #expect(sub.rows.first?.gapToNextM == 30 && sub.selectedClubsOnly)
    }

    @Test func bagOrderIsKeptEvenWhenDistancesInvert() throws {
        let (cs, shots) = try bagShots()
        let ps = profiles(shots, order: [cs[3].id, cs[2].id, cs[1].id, cs[0].id]) // PW first
        let rows = ClubGapping.table(ps, filter: AnalysisFilter(), eligibleClubCount: 4).rows
        #expect(rows.map(\.name) == ["PW", "7i", "5i", "Driver"] && rows.map(\.gapToNextM) == [-20, -30, -64, nil])
    }

    @Test func noDataRowBreaksTheChainAndStaysVisible() throws {
        let a = club("a"), b = club("b"), c = club("c")
        let shots = try [shot(a, carry: 150), shot(b), shot(c, carry: 130)]
        let rows = ClubGapping.table(profiles(shots, order: [a.id, b.id, c.id]), filter: AnalysisFilter(), eligibleClubCount: 3).rows
        #expect(rows.count == 3 && rows[1].meanM == nil && rows[0].gapToNextM == nil && rows[1].gapToNextM == nil)
    }

    @Test func mixedConditionsAreDetected() throws {
        let a = club("a")
        #expect(try !ClubGapping.hasMixedConditions([shot(a, carry: 1), shot(a, carry: 2)]))
        #expect(try ClubGapping.hasMixedConditions([shot(a, carry: 1), shot(a, carry: 2, pressure: 95000)]))
    }

    /// Same eligible IDs feed list, averages and gapping, and a shot's delta matches the average it is compared with.
    @Test func everyViewSharesOneEligibleSetAndTheDeltaMatches() throws {
        let a = club("7i")
        let shots = try [shot(a, carry: 100), shot(a, carry: 120, included: false), shot(a, carry: 140)]
        let f = AnalysisFilter()
        let sel = ShotSelection.select(shots, filter: f, now: t0)
        let ps = ClubAnalysis.profiles(sel.shots, filter: f)
        #expect(Set(ps.flatMap(\.shotIDs)) == Set(sel.ids))
        #expect(Set(Dispersion.points(sel.shots, filter: f).map(\.shotID)) == Set(sel.ids))
        let cmp = try #require(ShotCompare.compare(shots[0], key: .carry, within: ps.first, selection: sel.shots))
        #expect(cmp.clubMean == ps.first?.mean && cmp.delta == -20 && cmp.sampleCount == 2 && cmp.shotIsIncluded)
        // An excluded shot is compared with the included baseline and says it is not part of it.
        let ex = try #require(ShotCompare.compare(shots[1], key: .carry, within: ps.first, selection: sel.shots))
        #expect(ex.clubMean == 120 && !ex.shotIsIncluded)
        #expect(try ShotCompare.compare(shot(a), key: .carry, within: ps.first, selection: sel.shots) == nil) // no value -> no comparison
    }
}

struct DispersionTests {
    @Test func ellipseNeedsThreeNonCollinearPoints() throws {
        let c = club("7i")
        func pts(_ xy: [(Double, Double)]) throws -> [DispersionPoint] {
            let shots = try xy.map { try shot(c, carry: $0.0, lateral: $0.1) }
            return Dispersion.points(shots, filter: AnalysisFilter())
        }
        #expect(try Dispersion.ellipse(pts([(100, 0), (110, 5)])) == nil) // two points
        #expect(try Dispersion.ellipse(pts([(100, 0), (110, 5), (120, 10)])) == nil) // collinear
        let e = try #require(try Dispersion.ellipse(pts([(100, -4), (120, 4), (110, 0), (112, 6), (108, -6)])))
        #expect(e.semiMajorM >= e.semiMinorM && e.semiMinorM > 0)
        #expect(abs(e.centreLongitudinalM - 110) < 1e-9)
    }

    /// Three points that are not exactly in line but nearly so would draw a meaningless sliver: no shape is drawn.
    @Test func aNearlyCollinearScatterGetsNoEllipse() throws {
        let c = club("7i")
        let shots = try [(100.0, -4.0), (110, 0.2), (120, 4.0), (130, 8.1)].map { try shot(c, carry: $0.0, lateral: $0.1) }
        let pts = Dispersion.points(shots, filter: AnalysisFilter())
        #expect(Dispersion.ellipse(pts) == nil)
    }

    @Test func missingLateralKeepsDistanceOnlyPointsAndNoEllipse() throws {
        let c = club("7i")
        let pts = try Dispersion.points([100, 110, 120].map { try shot(c, carry: $0) }, filter: AnalysisFilter())
        #expect(pts.count == 3 && pts.allSatisfy { $0.lateralM == nil } && Dispersion.ellipse(pts) == nil)
    }

    @Test func knownCovarianceGivesKnownAxes() throws {
        // x spread SD 10 (longitudinal), y spread SD 5, uncorrelated: semi axes sqrt of variances.
        let c = club("7i")
        let data: [(Double, Double)] = [(90, 5), (110, 5), (90, -5), (110, -5)]
        let shots = try data.map { try shot(c, carry: $0.0, lateral: $0.1) }
        let e = try #require(Dispersion.ellipse(Dispersion.points(shots, filter: AnalysisFilter())))
        let sx = (4 * 100.0 / 3).squareRoot(), sy = (4 * 25.0 / 3).squareRoot()
        #expect(abs(e.semiMajorM - sx) < 1e-9 && abs(e.semiMinorM - sy) < 1e-9)
    }
}

/// Cross-check against an independent implementation (Python `statistics`, quantiles method "inclusive" = type 7).
struct IndependentReferenceTests {
    @Test func matchesPythonStatisticsOn23Values() throws {
        let xs: [Double] = [
            147.697, 154.603, 147.965, 147.164, 141.63, 148.08, 160.007, 153.817, 159.332, 152.24, 153.553, 151.668, 135.005, 157.697,
            154.557, 154.489, 134.778, 134.305, 141.993, 145.786, 152.749, 149.587, 154.689
        ]
        let c = club("7i")
        let p = try #require(try profiles(xs.map { try shot(c, carry: $0) }).first)
        func close(_ a: Double?, _ b: Double) -> Bool {
            a.map { abs($0 - b) < 1e-9 } ?? false
        }
        #expect(close(p.mean, 149.2778695652174) && close(p.median, 151.668) && close(p.spread, 7.499339421238428))
        #expect(close(p.p10, 136.33) && close(p.p90, 157.0954) && p.shortest == 134.305 && p.longest == 160.007)
        #expect(!p.isProvisional)
    }

    @Test func tenThousandShotsAnalyseQuickly() throws {
        let clubs = (0 ..< 14).map { club("c\($0)") }
        let shots = try (0 ..< 10000).map { try shot(
            clubs[$0 % 14],
            carry: 80 + Double($0 % 150),
            lateral: Double($0 % 21) - 10,
            seq: $0 + 1
        ) }
        let start = Date()
        let f = AnalysisFilter()
        let sel = ShotSelection.select(shots, filter: f, now: t0)
        let ps = ClubAnalysis.profiles(sel.shots, filter: f)
        let table = ClubGapping.table(ps, filter: f, eligibleClubCount: 14)
        #expect(ps.count == 14 && table.rows.count == 14)
        #expect(Date().timeIntervalSince(start) < 2, "analysis of 10,000 shots must stay interactive")
    }
}

struct FilterPersistenceTests {
    @Test func aFilterRoundTripsThroughJSON() throws {
        var f = AnalysisFilter()
        let ids: Set<UUID> = [UUID(), UUID(), UUID()]
        f.clubs = .some(ids)
        f.sessionIDs = [UUID()]
        f.range = .last30Days
        f.mode = .target
        f.inclusion = .all
        f.distance = .total
        f.conditions = .standardised
        let data = try JSONEncoder().encode(f)
        #expect(try JSONDecoder().decode(AnalysisFilter.self, from: data) == f)
        #expect(try JSONDecoder().decode(AnalysisFilter.self, from: JSONEncoder().encode(AnalysisFilter())) == AnalysisFilter())
    }

    @Test func encodingIsStableForTheSameSelection() throws {
        let ids = (0 ..< 5).map { _ in UUID() }
        var a = AnalysisFilter(), b = AnalysisFilter()
        a.clubs = .some(Set(ids))
        b.clubs = .some(Set(ids.reversed()))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(a) == encoder.encode(b))
    }

    @Test func emptySelectionSurvivesAsEmptyNotAll() throws {
        var f = AnalysisFilter()
        f.clubs = .some([])
        let back = try JSONDecoder().decode(AnalysisFilter.self, from: JSONEncoder().encode(f))
        #expect(back.clubs == .some([]) && !back.canApply)
    }
}

struct ClubStyleTests {
    @Test func stylesAreDistinctForTheFirstTwentyFourClubsAndDeterministic() {
        let styles = (0 ..< 24).map(ClubStyle.forPosition)
        #expect(Set(styles.map { "\($0.colourSlot)-\($0.symbolIndex)" }).count == 24)
        #expect(ClubStyle.forPosition(3) == ClubStyle.forPosition(3))
        #expect(ClubStyle.forPosition(-1) == ClubStyle.forPosition(0))
    }

    @Test func eachClubDiffersByColourOrSymbolFromItsNeighbours() {
        for i in 0 ..< 23 {
            #expect(ClubStyle.forPosition(i) != ClubStyle.forPosition(i + 1))
        }
    }

    @Test func badgesAreShortAndUppercase() {
        #expect(ClubBadge.text(for: "7 iron") == "7I" && ClubBadge.text(for: "Driver") == "DR" && ClubBadge.text(for: "PW") == "PW")
        #expect(ClubBadge.text(for: "") == "" && ClubBadge.text(for: "  Sand wedge ") == "SW")
    }
}
