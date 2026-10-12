import Analytics
import Domain
import Foundation
@testable import GolfLaunchr
import Persistence
import PersistenceTestSupport
import Testing

/// Backend that can fail on demand, wrapping a real in-memory store.
actor FlakyBackend: SessionRepository, ShotRepository, LedgerRepository {
    let inner: InMemoryStore
    var failWrites = false

    init(_ inner: InMemoryStore) {
        self.inner = inner
    }

    func setFailWrites(_ value: Bool) {
        failWrites = value
    }

    func save(_ session: Session) async throws {
        try await inner.save(session)
    }

    func session(id: UUID) async throws -> Session? {
        await inner.session(id: id)
    }

    func sessions() async throws -> [Session] {
        await inner.sessions()
    }

    func deleteSession(id: UUID) async throws {
        if failWrites {
            throw PersistenceError.storageFailure("write failed")
        }
        try await inner.deleteSession(id: id)
    }

    func commitAccepted(_ shot: Shot, ledger: LedgerEntry) async throws -> DurableReceipt {
        try await inner.commitAccepted(
            shot,
            ledger: ledger
        )
    }

    func shot(id: UUID) async throws -> Shot? {
        await inner.shot(id: id)
    }

    func shots(sessionID: UUID) async throws -> [Shot] {
        await inner.shots(sessionID: sessionID)
    }

    func setIncluded(shotID: UUID, included: Bool) async throws -> Shot {
        if failWrites {
            throw PersistenceError.storageFailure("write failed")
        }
        return try await inner.setIncluded(shotID: shotID, included: included)
    }

    func deleteShot(id: UUID) async throws {
        if failWrites {
            throw PersistenceError.storageFailure("write failed")
        }
        try await inner.deleteShot(id: id)
    }

    func entries() async throws -> [LedgerEntry] {
        await inner.entries()
    }

    func entry(forShot shotID: UUID) async throws -> LedgerEntry? {
        await inner.entry(forShot: shotID)
    }

    func creditsSpent(kind: AllowanceKind) async throws -> Int {
        await inner.creditsSpent(kind: kind)
    }
}

@MainActor
struct HistoryStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)

    struct World {
        let memory: InMemoryStore
        let backend: FlakyBackend
        let store: HistoryStore
        let sessions: [Session]
        let shotIDs: [[UUID]]
    }

    /// Two sessions: A (3 shots, carry 100/120/200) and B (1 shot).
    func world() async throws -> World {
        let memory = InMemoryStore(allowsSynthetic: true)
        let calibration = try CalibrationRecord(
            deviceProfileID: "fixture-only", format: CaptureFormatRecord(widthPx: 1920, heightPx: 1080, framesPerSecond: 240, lens: "wide"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 0.75,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
        await memory.save(calibration)
        let a = try Session(mode: .practice, createdAt: t0.addingTimeInterval(-86400), endedAt: t0.addingTimeInterval(-86400 + 1800))
        let b = try Session(mode: .target, createdAt: t0.addingTimeInterval(-10 * 86400))
        await memory.save(a)
        await memory.save(b)
        let club = try ClubSnapshot(id: UUID(), name: "7 iron", loftRad: nil)
        let context = Context(memory: memory, club: club, calibration: calibration)
        var ids: [[UUID]] = [[], []]
        for (index, carry) in [100.0, 120.0, 200.0].enumerated() {
            try await ids[0].append(commit(context, a, seq: index + 1, carry: carry))
        }
        try await ids[1].append(commit(context, b, seq: 1, carry: 90))
        let backend = FlakyBackend(memory)
        let store = HistoryStore(backend: backend, now: { self.t0 })
        await store.load()
        return World(memory: memory, backend: backend, store: store, sessions: [a, b], shotIDs: ids)
    }

    struct Context {
        let memory: InMemoryStore
        let club: ClubSnapshot
        let calibration: CalibrationRecord
    }

    func commit(_ context: Context, _ session: Session, seq: Int, carry: Double) async throws -> UUID {
        let (memory, club, calibration) = (context.memory, context.club, context.calibration)
        let shot = try Shot(
            id: UUID(), sessionID: session.id, sequence: seq, mode: session.mode, swingHandedness: .right, clubSnapshot: club,
            calibrationID: calibration.id, impactTimeUTC: session.createdAt,
            metrics: [.carry: Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional)],
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        let ledger = try LedgerEntry(acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: t0)
        _ = try await memory.commitAccepted(shot, ledger: ledger)
        return shot.id
    }

    @Test func loadBuildsSummariesNewestFirstFromWhatIsStored() async throws {
        let w = try await world()
        #expect(w.store.loadState == .loaded)
        #expect(w.store.visible.map(\.mode) == [.practice, .target])
        #expect(w.store.visible.first?.meanCarryMetres == 140 && w.store.visible.first?.shotCount == 3)
        #expect(w.store.shots(of: w.sessions[0].id).count == 3, "the detail list gets every shot the summary counts")
        #expect(w.store.shots(of: w.sessions[0].id).map(\.sequence) == [1, 2, 3])
        #expect(w.store.modeOptions == [.practice, .target])
        #expect(w.store.clubOptions.count == 1)
    }

    /// F10: exclusion and restoration recompute the numbers, and the recompute comes from the persisted state.
    @Test func excludeAndRestoreRecomputeFromTheDatabase() async throws {
        let w = try await world()
        let sessionID = w.sessions[0].id
        #expect(await w.store.setIncluded(w.shotIDs[0][2], false))
        #expect(w.store.summary(sessionID)?.meanCarryMetres == 110)
        #expect(w.store.summary(sessionID)?.includedCount == 2 && w.store.summary(sessionID)?.excludedCount == 1)
        #expect(await w.memory.shot(id: w.shotIDs[0][2])?.included == false) // really persisted, not just displayed
        // A brand-new store over the same database shows the same numbers.
        let again = HistoryStore(backend: w.backend, now: { self.t0 })
        await again.load()
        #expect(again.summary(sessionID)?.meanCarryMetres == 110)
        #expect(await w.store.setIncluded(w.shotIDs[0][2], true))
        #expect(w.store.summary(sessionID)?.meanCarryMetres == 140)
    }

    @Test func deletingAShotKeepsItsLedgerEntryAndUpdatesTheSession() async throws {
        let w = try await world()
        #expect(await w.store.deleteShot(w.shotIDs[0][0]))
        #expect(w.store.summary(w.sessions[0].id)?.shotCount == 2)
        #expect(w.store.shot(w.shotIDs[0][0]) == nil)
        #expect(await w.memory.entries().count == 4) // all four credits still recorded
        #expect(await w.memory.creditsSpent(kind: .introductory) == 4)
    }

    @Test func deletingASessionRemovesItAndItsShotsButNotTheLedgerOrOtherSessions() async throws {
        let w = try await world()
        w.store.selectedShotID = w.shotIDs[0][1]
        #expect(await w.store.deleteSession(w.sessions[0].id))
        #expect(w.store.visible.map(\.mode) == [.target])
        #expect(w.store.selectedShotID == nil) // the open detail of a deleted shot closes
        #expect(w.store.shots(of: w.sessions[0].id).isEmpty)
        #expect(await w.memory.entries().count == 4)
        #expect(w.store.shots(of: w.sessions[1].id).count == 1)
    }

    @Test func aFailedWriteKeepsTheShownStateAndReportsIt() async throws {
        let w = try await world()
        let before = w.store.summaries
        await w.backend.setFailWrites(true)
        #expect(await w.store.setIncluded(w.shotIDs[0][0], false) == false)
        #expect(await w.store.deleteShot(w.shotIDs[0][0]) == false)
        #expect(await w.store.deleteSession(w.sessions[0].id) == false)
        #expect(w.store.summaries == before && w.store.lastError == .storageFailed)
        await w.backend.setFailWrites(false)
        #expect(await w.store.setIncluded(w.shotIDs[0][0], false))
        #expect(w.store.lastError == nil)
    }

    @Test func filtersApplyToTheVisibleListAndClear() async throws {
        let w = try await world()
        w.store.filter.mode = .target
        #expect(w.store.visible.count == 1)
        w.store.filter.range = .last7Days // the target session is 10 days old
        #expect(w.store.visible.isEmpty)
        w.store.clearFilters()
        #expect(w.store.visible.count == 2 && w.store.filter.isActive == false)
    }

    @Test func anUnavailableStoreIsReportedAndDoesNothing() async {
        let none = HistoryStore(backend: nil, failureMessage: "no storage")
        await none.load()
        #expect(none.loadState == .failed("no storage"))
        #expect(await none.setIncluded(UUID(), true) == false)
    }

    @Test func prepareRunsOnceBeforeTheFirstLoad() async {
        let memory = InMemoryStore(allowsSynthetic: true)
        var ran = 0
        let store = HistoryStore(backend: memory, prepare: { ran += 1 })
        await store.load()
        await store.load()
        #expect(ran == 1)
    }
}

/// The exact demo fixtures through the real SQLite store and the real HistoryStore, as the app wires them in UI tests.
@MainActor
struct DemoFixtureTests {
    @Test func everySeededShotReachesTheHistoryStore() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixtures-\(UUID().uuidString)/store.sqlite")
        let sqlite = try SQLiteStore(url: url, allowsSynthetic: true)
        await HistoryFixtures.seedIfEmpty(sqlite)
        await HistoryFixtures.seedIfEmpty(sqlite) // seeding twice must not duplicate
        let store = HistoryStore(backend: sqlite)
        await store.load()
        let counts = store.summaries.sorted { $0.startedAt > $1.startedAt }.map { store.shots(of: $0.sessionID).map(\.sequence) }
        #expect(counts == [[1, 2, 3, 4, 5, 6], [1, 2, 3, 4], [1, 2, 3]])
        #expect(store.summaries.map(\.shotCount).sorted() == [3, 4, 6])
        #expect(try await sqlite.entries().count == 13)
    }
}

/// Regression: two loads started together must not run the preparation/seeding twice.
@MainActor
struct ConcurrentLoadTests {
    @Test func historyStoreLoadsOnceWhenCalledConcurrently() async {
        let memory = InMemoryStore(allowsSynthetic: true)
        let counter = Counter()
        let store = HistoryStore(backend: memory, prepare: {
            counter.value += 1
            try? await Task.sleep(for: .milliseconds(50)) // the first load is still busy when the second arrives
        })
        async let a: Void = store.load()
        async let b: Void = store.load()
        _ = await (a, b)
        #expect(counter.value == 1)
        #expect(store.loadState == .loaded)
    }

    @Test func bagStoreSeedsOnceWhenLoadedConcurrently() async throws {
        let repo = RecordingRepository()
        let store = BagStore(repository: repo, seedName: { "S-\($0)" })
        async let a: Void = store.load()
        async let b: Void = store.load()
        _ = await (a, b)
        #expect(await repo.saves == 1) // one seed, one save: the shown bag is the stored bag
        #expect(try await store.bag == (repo.loadBag()))
    }
}

@MainActor
final class Counter {
    var value = 0
}
