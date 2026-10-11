import Foundation

public enum ClubCategory: String, Codable, Sendable, CaseIterable {
    case driver, wood, hybrid, iron, wedge, putter, other
}

/// A club in the bag. Identity is the immutable `id`; everything else may be edited (F08).
/// Contract extends spec section 6 (category, label, loftRad, archivedAt) with brand, model, sortOrder, loftRevision: see DECISIONS.md.
public struct Club: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    /// The spec's "label": user-authored, never auto-translated.
    public var name: String
    public var category: ClubCategory
    /// nil = not set. A stock loft is never guessed.
    public var loftRad: Double?
    /// Incremented on every loft change so future estimation can tell which loft a shot used.
    public var loftRevision: Int
    public var brand: String?
    public var model: String?
    public var sortOrder: Int
    /// UTC; nil = active. Clubs are archived, never hard-deleted, so shots cannot be orphaned.
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        category: ClubCategory,
        loftRad: Double? = nil,
        loftRevision: Int = 0,
        brand: String? = nil,
        model: String? = nil,
        sortOrder: Int = 0,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.loftRad = loftRad
        self.loftRevision = loftRevision
        self.brand = brand
        self.model = model
        self.sortOrder = sortOrder
        self.archivedAt = archivedAt
    }

    /// Value copy that shots and sessions store. Later edits to the club never change it.
    public func snapshot() throws(ContractError) -> ClubSnapshot {
        try ClubSnapshot(id: id, name: name, loftRad: loftRad, loftRevision: loftRevision)
    }
}

/// Immutable club identity/name/loft as it was when a shot or session was recorded.
public struct ClubSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let loftRad: Double?
    public let loftRevision: Int

    public init(id: UUID, name: String, loftRad: Double?, loftRevision: Int = 0) throws(ContractError) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .invalidName }
        if let loftRad, !loftRad.isFinite {
            throw .nonFiniteValue("loftRad")
        }
        self.id = id
        self.name = name
        self.loftRad = loftRad
        self.loftRevision = loftRevision
    }

    private enum CodingKeys: String, CodingKey { case id, name, loftRad, loftRevision }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                id: c.decode(UUID.self, forKey: .id),
                name: c.decode(String.self, forKey: .name),
                loftRad: c.decodeIfPresent(Double.self, forKey: .loftRad),
                loftRevision: c.decodeIfPresent(Int.self, forKey: .loftRevision) ?? 0
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }

    /// `loftRad` is written as explicit null when unset (contract: present missing values are null).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(loftRad, forKey: .loftRad)
        try c.encode(loftRevision, forKey: .loftRevision)
    }
}
