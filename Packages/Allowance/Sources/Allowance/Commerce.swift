import Domain
import Foundation

public enum PlanPeriod: String, Sendable, CaseIterable {
    case monthly, annual
}

/// Product identifiers: one subscription group, same entitlement level, monthly and annual durations. No lifetime product.
public enum ProductIDs {
    public static let monthly = "com.allerhed.golflaunchr.pro.monthly"
    public static let annual = "com.allerhed.golflaunchr.pro.annual"
    public static let all = [monthly, annual]

    public static func period(of id: String) -> PlanPeriod? {
        switch id {
        case monthly: .monthly
        case annual: .annual
        default: nil
        }
    }
}

/// A purchasable plan as the store reports it. `displayPrice` is the localised price string from StoreKit: checkout amounts are
/// never hard-coded.
public struct PlanProduct: Equatable, Sendable, Identifiable {
    public let id: String
    public let period: PlanPeriod
    public let displayPrice: String
    public let price: Decimal
    public let currencyCode: String

    public init(id: String, period: PlanPeriod, displayPrice: String, price: Decimal, currencyCode: String) {
        self.id = id
        self.period = period
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
    }
}

public enum PurchaseOutcome: Equatable, Sendable {
    case success(Entitlement)
    /// Waiting for approval (Ask to Buy, SCA): nothing is unlocked yet.
    case pending
    case cancelled
    case failed
}

/// The store behind the paywall. The live implementation wraps StoreKit 2; tests use a double.
public protocol StoreProviding: Sendable {
    func products() async throws -> [PlanProduct]
    func purchase(_ productID: String) async -> PurchaseOutcome
    /// Asks the store to sync, then returns the verified entitlement (nil = none). Throws when the store cannot be reached.
    func restore() async throws -> Entitlement?
    /// The verified entitlement the store currently knows about (nil = none). Throws when the store cannot be reached.
    func currentEntitlement() async throws -> Entitlement?
    /// Opens Apple's offer-code redemption sheet and returns when it is closed. False if it could not be shown.
    func presentOfferCodeRedemption() async -> Bool
}

/// One verified, current transaction as far as access goes.
public struct TransactionFact: Sendable, Equatable {
    public let expiresAt: Date
    public let revoked: Bool
    public let kind: AllowanceKind

    public init(expiresAt: Date, revoked: Bool, kind: AllowanceKind) {
        self.expiresAt = expiresAt
        self.revoked = revoked
        self.kind = kind
    }
}

public extension Entitlement {
    /// Picks the verified, unrevoked transaction that lasts longest, and takes its kind (an access granted by a free offer code is
    /// `.complimentary`). Several overlapping transactions (monthly then annual) never add up or double-grant: it is one
    /// entitlement until the latest expiry.
    static func resolve(
        from transactions: [TransactionFact], verifiedAt: Date
    ) -> Entitlement? {
        let live = transactions.filter { !$0.revoked }
        guard let latest = live.max(by: { $0.expiresAt < $1.expiresAt }) else { return nil }
        return Entitlement(kind: latest.kind, expiresAt: latest.expiresAt, lastVerifiedAt: verifiedAt, revoked: false)
    }
}

public extension Pricing {
    /// Saving of the annual plan against twelve monthly payments, from the prices the store reports (nil if not comparable).
    static func annualSavingPercent(monthly: PlanProduct, annual: PlanProduct) -> Double? {
        guard monthly.currencyCode == annual.currencyCode, monthly.price > 0 else { return nil }
        let full = (monthly.price * 12) as NSDecimalNumber
        let paid = annual.price as NSDecimalNumber
        let saving = (full.doubleValue - paid.doubleValue) / full.doubleValue * 100
        return (saving * 10).rounded() / 10
    }

    /// The annual price spread over twelve months, for a line labelled as annual billing, never as a monthly charge.
    static func annualPerMonth(_ annual: PlanProduct) -> Decimal {
        var value = annual.price / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }
}
