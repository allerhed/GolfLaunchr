import Foundation

public enum AllowanceKind: String, Codable, Sendable, CaseIterable {
    case introductory, monthly, paid, complimentary
}

/// Trial/allowance ledger row. Separate from deletable history and deliberately holds no golf or video data (spec section 6).
/// `acceptedShotID` is unique: one shot, one credit (T02).
public struct LedgerEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID {
        acceptedShotID
    }

    public let acceptedShotID: UUID
    public let allowanceKind: AllowanceKind
    public let periodID: String?
    public let creditCost: Int
    public let committedAt: Date

    public init(
        acceptedShotID: UUID,
        allowanceKind: AllowanceKind,
        periodID: String?,
        creditCost: Int,
        committedAt: Date
    ) throws(ContractError) {
        guard creditCost >= 0 else { throw .invalidCreditCost(creditCost) }
        self.acceptedShotID = acceptedShotID
        self.allowanceKind = allowanceKind
        self.periodID = periodID
        self.creditCost = creditCost
        self.committedAt = committedAt
    }

    private enum CodingKeys: String, CodingKey { case acceptedShotID, allowanceKind, periodID, creditCost, committedAt }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                acceptedShotID: c.decode(UUID.self, forKey: .acceptedShotID),
                allowanceKind: c.decode(AllowanceKind.self, forKey: .allowanceKind),
                periodID: c.decodeIfPresent(String.self, forKey: .periodID),
                creditCost: c.decode(Int.self, forKey: .creditCost),
                committedAt: c.decode(Date.self, forKey: .committedAt)
            )
        } catch let error as ContractError {
            throw error.asDecodingError(decoder.codingPath)
        }
    }
}
