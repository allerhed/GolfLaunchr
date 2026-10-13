import Allowance
import Domain
import Foundation
@testable import GolfLaunchr
import Persistence
import PersistenceTestSupport
import Testing

@MainActor
struct AllowanceStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_791_716_400) // 2026-10-11

    func defaults() -> UserDefaults {
        UserDefaults(suiteName: "allowance-test-\(UUID().uuidString)") ?? .standard
    }

    func entries(_ n: Int, cost: Int = 1) throws -> [LedgerEntry] {
        try (0 ..< n).map { _ in
            try LedgerEntry(acceptedShotID: UUID(), allowanceKind: .introductory, periodID: "intro", creditCost: cost, committedAt: t0)
        }
    }

    @Test func freshInstallHasFiftyFreeShots() async {
        let store = AllowanceStore(backend: InMemoryStore(), defaults: defaults(), now: { t0 })
        #expect(store.canArm == false, "nothing is granted before the ledger has been read")
        await store.refresh()
        #expect(store.snapshot?.introRemaining == 50 && store.canArm)
    }

    @Test func exhaustedBlocksArmingAndShowsTheNextReset() async throws {
        let store = AllowanceStore(backend: InMemoryStore(), defaults: defaults(), now: { t0 })
        store.extraEntries = try entries(50)
        await store.refresh()
        #expect(!store.canArm)
        #expect(store.snapshot?.nextReset != nil)
        let decision = await store.decision()
        guard case .blocked = decision else { Issue.record("expected blocked, got \(String(describing: decision))"); return }
    }

    @Test func demoShotsSpendNothing() async throws {
        let store = AllowanceStore(backend: InMemoryStore(), defaults: defaults(), now: { t0 })
        store.extraEntries = try entries(30, cost: 0)
        await store.refresh()
        #expect(store.snapshot?.introRemaining == 50)
    }

    @Test func activationZoneIsFixedAtFirstUseAndSurvivesRelaunchAndZoneChange() async throws {
        let d = defaults()
        let first = AllowanceStore(
            backend: InMemoryStore(),
            defaults: d,
            now: { t0 },
            zone: { TimeZone(identifier: "Europe/Stockholm") ?? .gmt }
        )
        await first.refresh()
        let relaunch = AllowanceStore(
            backend: InMemoryStore(), defaults: d, now: { t0 }, zone: { TimeZone(identifier: "America/New_York") ?? .gmt }
        )
        await relaunch.refresh()
        let data = try #require(d.data(forKey: AllowanceStore.stateKey))
        let saved = try JSONDecoder().decode(AllowanceState.self, from: data)
        #expect(saved.timeZoneID == "Europe/Stockholm")
    }

    @Test func clockRollbackIsRememberedAcrossLaunches() async throws {
        let d = defaults()
        var clock = t0.addingTimeInterval(40 * 86400)
        let a = AllowanceStore(backend: InMemoryStore(), defaults: d, now: { clock })
        a.extraEntries = try entries(50)
        await a.refresh()
        let periodLater = a.snapshot?.monthlyPeriodID
        clock = t0
        let b = AllowanceStore(backend: InMemoryStore(), defaults: d, now: { clock })
        b.extraEntries = try entries(50)
        await b.refresh()
        #expect(b.snapshot?.monthlyPeriodID == periodLater, "an earlier clock does not move the period back")
    }

    @Test func noStorageMeansNothingArms() async {
        let store = AllowanceStore(backend: nil, defaults: defaults(), now: { t0 })
        await store.refresh()
        #expect(store.loadFailed && !store.canArm)
    }
}
