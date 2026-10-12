@testable import Domain
import Foundation
import Testing

struct LoftRuleTests {
    @Test func boundariesAreAccepted() throws {
        let low = try #require(try LoftRule.validate(degrees: 1.0))
        let high = try #require(try LoftRule.validate(degrees: 70.0))
        #expect(abs(low - 1.0 * .pi / 180) < 1e-12 && abs(high - 70.0 * .pi / 180) < 1e-12)
    }

    @Test(arguments: [0.99, 70.01, 0, -5, 90, 360])
    func outOfRangeIsRejected(degrees: Double) {
        #expect(throws: ClubValidationError.loftOutOfRange) { try LoftRule.validate(degrees: degrees) }
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity])
    func nonFiniteIsRejectedBeforeRangeIsChecked(degrees: Double) {
        #expect(throws: ClubValidationError.loftNotFinite) { try LoftRule.validate(degrees: degrees) }
    }

    @Test func nilMeansNotSetAndStaysNil() throws {
        #expect(try LoftRule.validate(degrees: nil) == nil)
    }

    @Test func degreesRoundTripToRadians() throws {
        #expect(try abs(#require(try LoftRule.validate(degrees: 56)) - 0.9773843811168246) < 1e-12)
    }
}

struct BagTests {
    func seededBag() -> Bag {
        Bag.seeded { "\($0)" }
    }

    /// U1
    @Test func seedHasThirteenClubsWithNoGuessedLoft() {
        let bag = seededBag()
        #expect(bag.clubs.count == 13 && bag.seeded)
        #expect(bag.clubs.allSatisfy { $0.loftRad == nil }) // never a guessed stock loft
        #expect(bag.clubs.filter { $0.category == .wedge }.count >= 4)
        #expect(Set(bag.clubs.map(\.id)).count == 13)
        #expect(bag.clubs.map(\.sortOrder) == Array(0 ... 12))
        #expect(bag.active.count == 13 && bag.archived.isEmpty)
    }

    /// U3
    @Test func twoClubsMayShareALoft() throws {
        var bag = Bag()
        try bag.add(name: "A", category: .wedge, loftDegrees: 56)
        try bag.add(name: "B", category: .wedge, loftDegrees: 56)
        #expect(bag.active.count == 2)
    }

    /// U4
    @Test func namesAreTrimmedBoundedAndUniqueAmongActiveClubs() throws {
        var bag = Bag()
        #expect(throws: ClubValidationError.emptyName) { try bag.add(name: "", category: .iron, loftDegrees: nil) }
        #expect(throws: ClubValidationError.emptyName) { try bag.add(name: "   ", category: .iron, loftDegrees: nil) }
        #expect(throws: ClubValidationError.nameTooLong) { try bag.add(
            name: String(repeating: "x", count: 41),
            category: .iron,
            loftDegrees: nil
        ) }
        let longest = try bag.add(name: String(repeating: "y", count: 40), category: .iron, loftDegrees: nil)
        #expect(longest.name.count == 40)
        let trimmed = try bag.add(name: "  7 iron ", category: .iron, loftDegrees: nil)
        #expect(trimmed.name == "7 iron")
        #expect(throws: ClubValidationError.duplicateActiveName) { try bag.add(name: "7 IRON", category: .iron, loftDegrees: nil) }
        try bag.add(name: "Järn 6", category: .iron, loftDegrees: nil)
        #expect(throws: ClubValidationError.duplicateActiveName) { try bag.add(
            name: "Jarn 6",
            category: .iron,
            loftDegrees: nil
        ) } // diacritics
    }

    @Test func aFailedAddLeavesTheBagUnchanged() throws {
        var bag = seededBag()
        let before = bag
        #expect(throws: ClubValidationError.loftOutOfRange) { try bag.add(name: "Bad", category: .iron, loftDegrees: 99) }
        #expect(bag == before)
    }

    @Test func aNameCanBeReusedWhileTheOldClubIsArchived() throws {
        var bag = Bag()
        let old = try bag.add(name: "7 iron", category: .iron, loftDegrees: nil)
        try bag.archive(old.id, now: Date())
        let fresh = try bag.add(name: "7 iron", category: .iron, loftDegrees: nil)
        #expect(fresh.id != old.id)
        #expect(throws: ClubValidationError.duplicateActiveName) { try bag.restore(old.id) } // but restoring would create a clash
    }

    /// U5 / T08: renaming never changes an earlier snapshot.
    @Test func renamingKeepsIdentityAndOldSnapshotsKeepTheOldName() throws {
        var bag = Bag()
        let club = try bag.add(name: "7 iron", category: .iron, loftDegrees: 34)
        let old = try #require(bag.snapshot(club.id))
        try bag.update(club.id, name: "Seven", category: .iron, loftDegrees: 34, brand: nil, model: nil)
        #expect(old.name == "7 iron")
        #expect(bag.snapshot(club.id)?.name == "Seven" && bag.snapshot(club.id)?.id == club.id)
    }

    /// U6
    @Test func loftRevisionGoesUpOnlyWhenTheLoftChanges() throws {
        var bag = Bag()
        let club = try bag.add(name: "SW", category: .wedge, loftDegrees: 56)
        let old = try #require(bag.snapshot(club.id))
        try bag.update(club.id, name: "Sand wedge", category: .wedge, loftDegrees: 56, brand: nil, model: nil)
        #expect(bag.snapshot(club.id)?.loftRevision == 0) // rename only
        try bag.update(club.id, name: "Sand wedge", category: .wedge, loftDegrees: 56.0, brand: "B", model: nil)
        #expect(bag.snapshot(club.id)?.loftRevision == 0) // same loft again
        try bag.update(club.id, name: "Sand wedge", category: .wedge, loftDegrees: 58, brand: "B", model: nil)
        #expect(bag.snapshot(club.id)?.loftRevision == 1)
        try bag.update(club.id, name: "Sand wedge", category: .wedge, loftDegrees: nil, brand: "B", model: nil) // clearing is a change
        #expect(bag.snapshot(club.id)?.loftRevision == 2)
        #expect(old.loftRevision == 0 && abs((old.loftRad ?? 0) - 56 * .pi / 180) < 1e-12) // the snapshot is a frozen value
    }

    /// U7
    @Test func archivingKeepsTheIDAndHistoryResolves() throws {
        var bag = Bag()
        let club = try bag.add(name: "Driver", category: .driver, loftDegrees: 10.5)
        let now = Date(timeIntervalSince1970: 1_791_716_400)
        try bag.archive(club.id, now: now)
        #expect(bag.active.isEmpty && bag.archived.map(\.id) == [club.id])
        #expect(bag.archived.first?.archivedAt == now)
        #expect(bag.snapshot(club.id)?.name == "Driver") // still resolves for history
        #expect(throws: ClubValidationError.archived) { try bag.archive(club.id, now: now) }
        #expect(throws: ClubValidationError.archived) { try bag.update(
            club.id,
            name: "X",
            category: .driver,
            loftDegrees: nil,
            brand: nil,
            model: nil
        ) }
        #expect(throws: ClubValidationError.unknownClub) { try bag.archive(UUID(), now: now) }
        #expect(throws: ClubValidationError.unknownClub) { try bag.restore(UUID()) }
        #expect(throws: ClubValidationError.unknownClub) { try bag.update(
            UUID(),
            name: "X",
            category: .iron,
            loftDegrees: nil,
            brand: nil,
            model: nil
        ) }
    }

    @Test func restoringPutsTheClubAtTheEndOfTheActiveOrder() throws {
        var bag = Bag()
        let a = try bag.add(name: "A", category: .iron, loftDegrees: nil)
        try bag.add(name: "B", category: .iron, loftDegrees: nil)
        try bag.archive(a.id, now: Date())
        try bag.restore(a.id)
        #expect(bag.active.map(\.name) == ["B", "A"])
        #expect(throws: ClubValidationError.notArchived) { try bag.restore(a.id) }
    }

    /// U8
    @Test func reorderingRenumbersContiguouslyAndLeavesArchivedClubsAlone() throws {
        var bag = Bag()
        let ids = try ["A", "B", "C", "D"].map { try bag.add(name: $0, category: .iron, loftDegrees: nil).id }
        try bag.archive(ids[1], now: Date())
        let archivedBefore = bag.archived
        bag.move(fromOffsets: IndexSet(integer: 0), toOffset: 3) // active is A, C, D -> C, D, A
        #expect(bag.active.map(\.name) == ["C", "D", "A"])
        #expect(bag.active.map(\.sortOrder) == [0, 1, 2])
        #expect(bag.archived == archivedBefore)
    }

    @Test func reorderingEdgeCases() throws {
        var bag = Bag()
        for n in ["A", "B", "C"] {
            try bag.add(name: n, category: .iron, loftDegrees: nil)
        }
        bag.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(bag.active.map(\.name) == ["C", "A", "B"])
        bag.move(fromOffsets: IndexSet(integer: 0), toOffset: 1) // moving onto itself: no change
        #expect(bag.active.map(\.name) == ["C", "A", "B"])
        let before = bag
        bag.move(fromOffsets: IndexSet(integer: 9), toOffset: 0) // invalid offsets are ignored
        bag.move(fromOffsets: IndexSet(integer: 0), toOffset: 99)
        bag.move(fromOffsets: IndexSet(), toOffset: 0)
        #expect(bag == before)
        bag.move(fromOffsets: IndexSet([0, 1]), toOffset: 3) // two at once to the end
        #expect(bag.active.map(\.name) == ["B", "C", "A"])
    }

    /// U9: Codable and no way to delete a club.
    @Test func codableRoundTripKeepsEverythingIncludingNilOptionals() throws {
        var bag = seededBag()
        let first = try #require(bag.active.first)
        try bag.archive(first.id, now: Date(timeIntervalSince1970: 1_791_716_400))
        let enc = ContractJSON.encoder(), dec = ContractJSON.decoder()
        let back = try dec.decode(Bag.self, from: enc.encode(bag))
        #expect(back == bag)
        #expect(back.clubs.allSatisfy { $0.loftRad == nil })
    }

    @Test func clubCountNeverShrinksWhateverYouDo() throws {
        var bag = seededBag()
        let ids = bag.clubs.map(\.id)
        for id in ids.prefix(5) {
            try bag.archive(id, now: Date())
        }
        try bag.restore(ids[0])
        #expect(bag.clubs.count == 13)
        #expect(Set(bag.clubs.map(\.id)) == Set(ids))
    }

    @Test func blankBrandAndModelAreStoredAsNil() throws {
        var bag = Bag()
        let club = try bag.add(name: "X", category: .iron, loftDegrees: nil, brand: "  ", model: "")
        #expect(club.brand == nil && club.model == nil)
        try bag.update(club.id, name: "X", category: .iron, loftDegrees: nil, brand: " Ping ", model: "G430")
        #expect(bag.clubs.first?.brand == "Ping" && bag.clubs.first?.model == "G430")
    }

    @Test func validateWithoutChangingAnything() throws {
        let bag = seededBag()
        #expect(try bag.validate(name: "New", loftDegrees: 30).name == "New")
        #expect(throws: ClubValidationError.duplicateActiveName) { try bag.validate(name: "driver", loftDegrees: nil) }
        let id = try #require(bag.active.first?.id)
        #expect(try bag.validate(name: "driver", loftDegrees: nil, editing: id).name == "driver") // a club may keep its own name
    }
}
