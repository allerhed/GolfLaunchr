@testable import Allowance
import Domain
import Foundation
import Testing

struct CommerceTests {
    let now = Date(timeIntervalSince1970: 1_791_716_400)
    let monthly = PlanProduct(id: ProductIDs.monthly, period: .monthly, displayPrice: "49 kr", price: 49, currencyCode: "SEK")
    let annual = PlanProduct(id: ProductIDs.annual, period: .annual, displayPrice: "499 kr", price: 499, currencyCode: "SEK")

    @Test func productIDsMapToPlansAndNothingElse() {
        #expect(ProductIDs.period(of: ProductIDs.monthly) == .monthly)
        #expect(ProductIDs.period(of: ProductIDs.annual) == .annual)
        #expect(ProductIDs.period(of: "com.example.lifetime") == nil)
        #expect(ProductIDs.all.count == 2, "no lifetime or credit products at launch")
    }

    @Test func overlappingTransactionsGiveOneEntitlementUntilTheLatestExpiry() throws {
        let a = now.addingTimeInterval(10 * 86400), b = now.addingTimeInterval(300 * 86400)
        let e = try #require(Entitlement.resolve(from: [(a, false), (b, false)], verifiedAt: now))
        #expect(e.expiresAt == b && !e.revoked && e.kind == .paid)
    }

    @Test func revokedTransactionsNeverCountAndNoneMeansNoEntitlement() {
        let a = now.addingTimeInterval(86400)
        #expect(Entitlement.resolve(from: [(a, true)], verifiedAt: now) == nil)
        #expect(Entitlement.resolve(from: [], verifiedAt: now) == nil)
        let e = Entitlement.resolve(from: [(a, true), (a.addingTimeInterval(86400), false)], verifiedAt: now)
        #expect(e?.expiresAt == a.addingTimeInterval(86400))
    }

    @Test func savingIsComputedFromTheStorePricesAndRoundedToOneDecimal() {
        #expect(Pricing.annualSavingPercent(monthly: monthly, annual: annual) == 15.1)
        let eur = PlanProduct(id: ProductIDs.annual, period: .annual, displayPrice: "€49", price: 49, currencyCode: "EUR")
        #expect(Pricing.annualSavingPercent(monthly: monthly, annual: eur) == nil, "different currencies are not comparable")
    }

    @Test func annualPerMonthIsAnAnnualFigure() {
        #expect(Pricing.annualPerMonth(annual) == Decimal(string: "41.58"))
    }
}
