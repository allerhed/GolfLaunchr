import Domain
import Foundation
@testable import Persistence
import PersistenceTestSupport
import Testing

struct BagRepositoryTests {
    func sampleBag() throws -> Bag {
        var bag = Bag.seeded { "\($0)" }
        let first = try #require(bag.active.first)
        try bag.archive(first.id, now: Date(timeIntervalSince1970: 1_791_716_400))
        try bag.add(name: "Låtsas 7", category: .iron, loftDegrees: 34.5, brand: "B", model: nil)
        return bag
    }

    @Test(arguments: Backend.allCases) func neverSavedMeansNilSoTheAppSeeds(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        #expect(try await w.store.loadBag() == nil)
    }

    @Test(arguments: Backend.allCases) func saveThenLoadIsEqualIncludingArchivedAndOptionals(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        let bag = try sampleBag()
        try await w.store.saveBag(bag)
        #expect(try await w.store.loadBag() == bag)
    }

    @Test(arguments: Backend.allCases) func savingAgainReplacesTheBag(backend: Backend) async throws {
        let w = try await World.make(backend: backend)
        try await w.store.saveBag(Bag.seeded { "\($0)" })
        var changed = try sampleBag()
        try changed.add(name: "Extra", category: .other, loftDegrees: nil)
        try await w.store.saveBag(changed)
        #expect(try await w.store.loadBag() == changed)
    }

    @Test func aBagSurvivesReopeningTheDatabase() async throws {
        let w = try await World.make(backend: .sqlite)
        let bag = try sampleBag()
        try await w.store.saveBag(bag)
        let reopened = try SQLiteStore(url: #require(w.databaseURL))
        #expect(try await reopened.loadBag() == bag)
    }

    @Test func aBagWrittenByANewerAppIsRefusedNotMisread() async throws {
        let w = try await World.make(backend: .sqlite)
        let raw = try SQLiteDatabase(path: #require(w.databaseURL).path)
        try raw.run("INSERT INTO bag (id, json) VALUES (1, ?)", [.text(#"{"schemaVersion":99,"bag":{"clubs":[],"seeded":true}}"#)])
        await #expect(throws: PersistenceError.schemaTooNew(found: 99, supported: 1)) { try await w.store.loadBag() }
    }

    @Test func anUnreadableBagIsAnErrorNeverNilSoTheAppDoesNotReseedOverIt() async throws {
        let w = try await World.make(backend: .sqlite)
        let raw = try SQLiteDatabase(path: #require(w.databaseURL).path)
        try raw.run("INSERT INTO bag (id, json) VALUES (1, '{broken')")
        await #expect(throws: PersistenceError.self) { try await w.store.loadBag() }
    }
}
