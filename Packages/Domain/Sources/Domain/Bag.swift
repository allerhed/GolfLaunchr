import Foundation

/// The common bag a golfer starts with. Names are localised once at seed time and then stored as plain user data.
public enum SeedClub: CaseIterable, Sendable {
    case driver, wood3, hybrid4, iron5, iron6, iron7, iron8, iron9, pitchingWedge, gapWedge, sandWedge, lobWedge, putter

    public var category: ClubCategory {
        switch self {
        case .driver: .driver
        case .wood3: .wood
        case .hybrid4: .hybrid
        case .iron5, .iron6, .iron7, .iron8, .iron9: .iron
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge: .wedge
        case .putter: .putter
        }
    }
}

/// The golfer's clubs and every rule for changing them (F08). A value type: each mutation validates first, so a failed
/// call leaves the bag unchanged. There is deliberately no way to delete a club: archiving keeps the ID, so no shot can be orphaned.
public struct Bag: Codable, Sendable, Equatable {
    public private(set) var clubs: [Club]
    /// True once the bag was created from the seed. A bag the golfer later empties is never re-seeded.
    public let seeded: Bool

    public init(clubs: [Club] = [], seeded: Bool = false) {
        self.clubs = clubs
        self.seeded = seeded
    }

    /// Active clubs in the golfer's order.
    public var active: [Club] {
        clubs.filter { $0.archivedAt == nil }.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    /// Archived clubs, most recently archived first.
    public var archived: [Club] {
        clubs.filter { $0.archivedAt != nil }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    public static func seeded(names: (SeedClub) -> String) -> Bag {
        let clubs = SeedClub.allCases.enumerated().map { index, seed in
            Club(name: names(seed), category: seed.category, sortOrder: index)
        }
        return Bag(clubs: clubs, seeded: true)
    }

    /// Validates a draft without changing anything: the editor uses this to enable Save and show the reason.
    /// - Parameter editing: the club being edited, which may keep its own name.
    public func validate(
        name: String,
        loftDegrees: Double?,
        editing: UUID? = nil
    ) throws(ClubValidationError) -> (name: String, loftRad: Double?) {
        let clean = try ClubName.normalized(name)
        let loft = try LoftRule.validate(degrees: loftDegrees)
        let clash = clubs.contains { $0.archivedAt == nil && $0.id != editing && ClubName.matches($0.name, clean) }
        guard !clash else { throw .duplicateActiveName }
        return (clean, loft)
    }

    @discardableResult
    public mutating func add(
        name: String,
        category: ClubCategory,
        loftDegrees: Double?,
        brand: String? = nil,
        model: String? = nil
    ) throws(ClubValidationError) -> Club {
        let valid = try validate(name: name, loftDegrees: loftDegrees)
        let club = Club(
            name: valid.name, category: category, loftRad: valid.loftRad, brand: Self.clean(brand), model: Self.clean(model),
            sortOrder: (active.last?.sortOrder ?? -1) + 1
        )
        clubs.append(club)
        return club
    }

    // swiftlint:disable function_parameter_count
    /// Edits a club. `loftRevision` goes up only when the loft really changes, so future estimation knows which loft a shot used.
    public mutating func update(
        _ id: UUID,
        name: String,
        category: ClubCategory,
        loftDegrees: Double?,
        brand: String?,
        model: String?
    ) throws(ClubValidationError) {
        guard let index = clubs.firstIndex(where: { $0.id == id }) else { throw .unknownClub }
        guard clubs[index].archivedAt == nil else { throw .archived }
        let valid = try validate(name: name, loftDegrees: loftDegrees, editing: id)
        if !Self.sameLoft(clubs[index].loftRad, valid.loftRad) {
            clubs[index].loftRevision += 1
        }
        clubs[index].name = valid.name
        clubs[index].category = category
        clubs[index].loftRad = valid.loftRad
        clubs[index].brand = Self.clean(brand)
        clubs[index].model = Self.clean(model)
    }

    // swiftlint:enable function_parameter_count

    /// Reorders the active clubs (the same offsets contract as SwiftUI's `onMove`) and renumbers them 0, 1, 2 ...
    public mutating func move(fromOffsets: IndexSet, toOffset: Int) {
        var list = active
        guard !fromOffsets.isEmpty, fromOffsets.allSatisfy({ list.indices.contains($0) }),
              (0 ... list.count).contains(toOffset) else { return }
        let moving = fromOffsets.sorted().map { list[$0] }
        for index in fromOffsets.sorted(by: >) {
            list.remove(at: index)
        }
        list.insert(contentsOf: moving, at: toOffset - fromOffsets.filter { $0 < toOffset }.count)
        for (order, club) in list.enumerated() {
            if let index = clubs.firstIndex(where: { $0.id == club.id }) {
                clubs[index].sortOrder = order
            }
        }
    }

    public mutating func archive(_ id: UUID, now: Date) throws(ClubValidationError) {
        guard let index = clubs.firstIndex(where: { $0.id == id }) else { throw .unknownClub }
        guard clubs[index].archivedAt == nil else { throw .archived }
        clubs[index].archivedAt = now
    }

    /// Brings an archived club back at the end of the active order. Fails if an active club now has the same name.
    public mutating func restore(_ id: UUID) throws(ClubValidationError) {
        guard let index = clubs.firstIndex(where: { $0.id == id }) else { throw .unknownClub }
        guard clubs[index].archivedAt != nil else { throw .notArchived }
        guard !clubs.contains(where: { $0.archivedAt == nil && ClubName.matches($0.name, clubs[index].name) }) else {
            throw .duplicateActiveName
        }
        clubs[index].sortOrder = (active.last?.sortOrder ?? -1) + 1
        clubs[index].archivedAt = nil
    }

    /// The identity, name and loft as recorded now. Works for archived clubs too, so history keeps resolving.
    public func snapshot(_ id: UUID) -> ClubSnapshot? {
        guard let club = clubs.first(where: { $0.id == id }) else { return nil }
        return try? club.snapshot()
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func sameLoft(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (x?, y?): abs(x - y) < 1e-12
        default: false
        }
    }
}
