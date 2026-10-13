import Analytics
import Domain
import Foundation
@testable import GolfLaunchr
import Persistence
import PersistenceTestSupport
import Testing

@MainActor
struct AnalysisStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_791_716_400)

    private struct Fixture {
        let store: AnalysisStore
        let history: HistoryStore
        let defaults: UserDefaults
        let clubs: [Club]
        let sessions: [Session]
    }

    /// 4 clubs with the spec fixture means 224/160/130/110 over two sessions (unequal sample sizes), plus one excluded shot.
    private func fixture(defaults existing: UserDefaults? = nil) async throws -> Fixture {
        guard let defaults = existing ?? UserDefaults(suiteName: "analysis-tests-\(UUID().uuidString)")
        else { preconditionFailure("suite") }
        let memory = InMemoryStore(allowsSynthetic: true)
        let calibration = try CalibrationRecord(
            deviceProfileID: "x", format: CaptureFormatRecord(widthPx: 1, heightPx: 1, framesPerSecond: 240, lens: "w"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
        await memory.save(calibration)
        let a = try Session(mode: .practice, createdAt: t0, endedAt: t0.addingTimeInterval(600))
        let b = try Session(mode: .practice, createdAt: t0.addingTimeInterval(86400), endedAt: t0.addingTimeInterval(86400 + 600))
        await memory.save(a)
        await memory.save(b)
        let clubs = try ["Driver", "5 iron", "7 iron", "PW"].enumerated().map { try Club(
            name: $1,
            category: .iron,
            loftRad: nil,
            sortOrder: $0
        ) }
        let means = [224.0, 160, 130, 110]
        for (index, club) in clubs.enumerated() {
            let snapshot = try club.snapshot()
            // two shots in session a, one in session b, so the pooled mean must come from all three
            let carries = [means[index] - 6, means[index] + 6, means[index]]
            for (n, carry) in carries.enumerated() {
                let session = n < 2 ? a : b
                let seq = index * 10 + n + 1
                let shot = try Shot(
                    id: UUID(), sessionID: session.id, sequence: seq, mode: .practice, swingHandedness: .right, clubSnapshot: snapshot,
                    calibrationID: calibration.id, impactTimeUTC: session.createdAt.addingTimeInterval(Double(seq)),
                    metrics: [
                        .carry: Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional),
                        .lateralLanding: Domain.Measurement(
                            key: .lateralLanding,
                            value: Double(n) * 3 - 3,
                            provenance: .estimated,
                            quality: .provisional
                        ),
                    ],
                    environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
                    versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
                )
                let ledger = try LedgerEntry(
                    acceptedShotID: shot.id,
                    allowanceKind: .introductory,
                    periodID: nil,
                    creditCost: 1,
                    committedAt: t0
                )
                _ = try await memory.commitAccepted(shot, ledger: ledger)
            }
        }
        let history = HistoryStore(backend: memory, now: { self.t0.addingTimeInterval(2 * 86400) })
        await history.load()
        try await memory.saveBag(Bag(clubs: clubs, seeded: true))
        let bag = BagStore(repository: memory, seedName: { "\($0)" })
        await bag.load()
        let store = AnalysisStore(history: history, bag: bag, defaults: defaults, now: { self.t0.addingTimeInterval(2 * 86400) })
        return Fixture(store: store, history: history, defaults: defaults, clubs: clubs, sessions: [a, b])
    }

    @Test func specFixtureMeansAndSignedGapsFlowThroughTheStore() async throws {
        let f = try await fixture()
        let r = f.store.result
        #expect(r.profiles.map(\.name) == ["Driver", "5 iron", "7 iron", "PW"]) // bag order
        #expect(r.profiles.map(\.mean) == [224, 160, 130, 110]) // pooled over both sessions
        #expect(r.gap.rows.map(\.gapToNextM) == [64, 30, 20, nil] && !r.gap.selectedClubsOnly)
    }

    @Test func selectingTwoClubsGivesTheSubsetGapAndTheWarning() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.clubs = .some([f.clubs[1].id, f.clubs[2].id])
        #expect(f.store.applyFilter())
        let r = f.store.result
        #expect(r.gap.rows.first?.gapToNextM == 30 && r.gap.selectedClubsOnly && r.profiles.count == 2)
    }

    @Test func everyViewSharesTheSameEligibleShots() async throws {
        let f = try await fixture()
        let r = f.store.result
        let ids = Set(r.selection.ids)
        #expect(Set(r.profiles.flatMap(\.shotIDs)) == ids && Set(r.points.map(\.shotID)) == ids)
    }

    @Test func aCancelledDraftLeavesTheAppliedFilterAlone() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.distance = .total
        f.store.cancelFilter()
        #expect(f.store.applied == AnalysisFilter() && !f.store.showingFilter)
        f.store.openFilter()
        #expect(f.store.editor.draft == AnalysisFilter()) // reopening starts from what is applied
    }

    @Test func anEmptyClubSelectionCannotBeApplied() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.clubs = .some([])
        #expect(!f.store.applyFilter() && f.store.showingFilter && f.store.applied.clubs == .all)
    }

    @Test func theAppliedFilterSurvivesARelaunchButADraftDoesNot() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.distance = .total
        f.store.editor.draft.clubs = .some([f.clubs[0].id])
        f.store.applyFilter()
        f.store.openFilter()
        f.store.editor.draft.mode = .target // never applied
        let again = try await fixture(defaults: f.defaults)
        #expect(again.store.applied.distance == .total && again.store.applied.clubs == .some([f.clubs[0].id]) && again.store.applied
            .mode == nil)
    }

    @Test func aCorruptOrEmptyStoredFilterFallsBackToTheDefaults() async throws {
        guard let d = UserDefaults(suiteName: "analysis-corrupt-\(UUID().uuidString)") else { preconditionFailure("suite") }
        d.set(Data("garbage".utf8), forKey: "analysis.filter")
        #expect(try await fixture(defaults: d).store.applied == AnalysisFilter())
        var empty = AnalysisFilter()
        empty.clubs = .some([])
        d.set(try? JSONEncoder().encode(empty), forKey: "analysis.filter")
        #expect(try await fixture(defaults: d).store.applied == AnalysisFilter())
    }

    @Test func focusingOnASessionKeepsTheOtherChoicesAndCanBeCleared() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.distance = .total
        f.store.applyFilter()
        f.store.focus(onSession: f.sessions[0].id)
        #expect(f.store.applied.sessionIDs == [f.sessions[0].id] && f.store.applied.distance == .total)
        #expect(f.store.result.selection.shots.allSatisfy { $0.sessionID == f.sessions[0].id })
        f.store.clearSessionScope()
        #expect(f.store.applied.sessionIDs == nil)
    }

    @Test func excludingAShotMovesTheAverageAndRestoringBringsItBack() async throws {
        let f = try await fixture()
        let driver = try #require(f.store.allShots.first { $0.clubSnapshot.name == "Driver" && $0.value(.carry) == 230 })
        #expect(await f.history.setIncluded(driver.id, false))
        let after = f.store.result.profiles.first
        #expect(
            after?.mean == 221,
            "mean \(String(describing: after?.mean)) shots \(String(describing: after?.shotCount)) name \(String(describing: after?.name))"
        )
        #expect(await f.history.setIncluded(driver.id, true))
        #expect(f.store.result.profiles.first?.mean == 224)
    }

    @Test func aShotIsComparedWithItsClubAverageAndAnExcludedOneIsNot() async throws {
        let f = try await fixture()
        let seven = try #require(f.store.allShots.first { $0.clubSnapshot.name == "7 iron" && $0.value(.carry) == 136 })
        let c = try #require(f.store.comparison(for: seven, key: .carry))
        #expect(c.clubMean == 130 && c.delta == 6 && c.sampleCount == 3 && c.shotIsIncluded)
        #expect(await f.history.setIncluded(seven.id, false))
        let refreshed = try #require(f.store.allShots.first { $0.id == seven.id })
        let after = try #require(f.store.comparison(for: refreshed, key: .carry))
        #expect(after.clubMean == 127 && !after.shotIsIncluded && after.sampleCount == 2)
    }

    @Test func standardisedShowsNoValuesNotRecordedNumbers() async throws {
        let f = try await fixture()
        f.store.openFilter()
        f.store.editor.draft.conditions = .standardised
        f.store.applyFilter()
        #expect(f.store.result.profiles.allSatisfy { $0.mean == nil && $0.distanceSamples == 0 })
    }

    @Test func clubOptionsIncludeClubsOutsideTheBagInBagOrderFirst() async throws {
        let f = try await fixture()
        #expect(f.store.clubOptions.map(\.name) == ["Driver", "5 iron", "7 iron", "PW"])
    }
}
