import Domain
import Foundation
@testable import GolfLaunchr
import Modes
import Persistence
import PersistenceTestSupport
import Testing

@MainActor
struct PracticeStoreTests {
    private func settings() -> SettingsStore {
        guard let defaults = UserDefaults(suiteName: "practice-tests-\(UUID().uuidString)") else { preconditionFailure("suite") }
        return SettingsStore(defaults: defaults)
    }

    private let fixedBag = PracticeStoreTests.makeBag()

    private static func makeBag() -> Bag {
        let clubs = ["Driver", "7 iron", "PW"].enumerated().compactMap { index, name in
            try? Club(name: name, category: .iron, loftRad: nil, sortOrder: index)
        }
        return Bag(clubs: clubs)
    }

    private func start(
        _ mode: PracticeMode = .standard,
        settings: SettingsStore? = nil,
        store: InMemoryStore = InMemoryStore(allowsSynthetic: true)
    ) async throws -> PracticeStore {
        let started = await PracticeStore.start(mode, bag: fixedBag, settings: settings ?? self.settings(), backend: store)
        return try #require(started)
    }

    @Test func startingSavesAnActiveSessionAndPicksTheFirstClub() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(store: store)
        #expect(try await store.session(id: practice.session.id)?.recoveryState == .active)
        #expect(practice.state.selectedClub?.name == "Driver" && practice.state.mode == .standard)
    }

    @Test func quickShotStartsFromTheLastUsedClub() async throws {
        let s = settings()
        let first = try await start(.standard, settings: s)
        first.selectClub(first.clubs[1]) // 7 iron
        let second = try await start(.quickShot, settings: s)
        #expect(second.state.selectedClub?.name == "7 iron" && second.state.mode == .quickShot)
    }

    @Test func settingsRememberTheClubAcrossRelaunch() {
        let defaults = UserDefaults(suiteName: "last-club-\(UUID().uuidString)") ?? .standard
        let id = UUID()
        SettingsStore(defaults: defaults).lastClubID = id
        #expect(SettingsStore(defaults: defaults).lastClubID == id)
        #expect(SettingsStore(defaults: defaults, resetting: true).lastClubID == nil)
    }

    @Test func endingTwiceSavesOnceAndAnEmptySessionIsDropped() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(store: store)
        async let a = practice.end()
        async let b = practice.end()
        let results = await [a, b]
        #expect(results.filter(\.self).count == 1) // double tap: exactly one end
        #expect(try await store.sessions().isEmpty) // no shots -> not kept
        #expect(practice.didEnd)
    }

    @Test func settingsNeverBlockEndingAfterAFailedSaveRetry() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(store: store)
        _ = practice.arm(setupReady: true)
        #expect(practice.state.isArmed)
        #expect(await practice.end())
        #expect(try await store.sessions().isEmpty)
        #expect(await practice.end() == false)
    }

    @Test func aShotCanOnlyBeCommittedWhileArmed() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(store: store)
        let club = try #require(practice.state.selectedClub)
        let shot = try Shot(
            id: UUID(), sessionID: practice.session.id, sequence: 1, mode: .practice, swingHandedness: .right, clubSnapshot: club,
            calibrationID: UUID(), impactTimeUTC: Date(), metrics: [:], environment: Environment(
                pressurePa: 1,
                temperatureK: 1,
                source: .standard
            ),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        let ledger = try LedgerEntry(
            acceptedShotID: shot.id,
            allowanceKind: .introductory,
            periodID: nil,
            creditCost: 1,
            committedAt: Date()
        )
        #expect(await practice.commit(shot, ledger: ledger) == false) // not armed: nothing written
        #expect(try await store.entries().isEmpty)
        #expect(practice.arm(setupReady: false) == .blocked(.setupNotReady)) // safeguards are not skipped, even for QuickShot
    }

    @Test func recoveryClosesInterruptedSessionsAtLaunch() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(.standard, store: store)
        let launcher = PracticeLauncher(bagStore: BagStore(repository: nil, seedName: { "\($0)" }), settings: settings(), backend: store) {
            preconditionFailure("not used")
        }
        await launcher.recoverInterrupted() // the session has no shots, so it is dropped
        #expect(try await store.session(id: practice.session.id) == nil)
    }
}
