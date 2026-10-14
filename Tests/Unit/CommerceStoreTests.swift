import Allowance
import Domain
import Foundation
@testable import GolfLaunchr
import Testing

/// Scripted store: each call returns what the test queued.
actor FakeStore: StoreProviding {
    var catalog: Result<[PlanProduct], any Error> = .success([])
    var outcomes: [PurchaseOutcome] = []
    var restored: Result<Entitlement?, any Error> = .success(nil)
    var current: Result<Entitlement?, any Error> = .success(nil)
    private(set) var purchaseCalls = 0
    var delayNanos: UInt64 = 0
    var canPresent = true
    var currentAfterPresent: Result<Entitlement?, any Error>?

    struct Offline: Error {}

    func set(
        catalog: Result<[PlanProduct], any Error>? = nil,
        outcomes: [PurchaseOutcome]? = nil,
        restored: Result<Entitlement?, any Error>? = nil,
        current: Result<Entitlement?, any Error>? = nil,
        delay: UInt64? = nil
    ) {
        if let catalog {
            self.catalog = catalog
        }
        if let outcomes {
            self.outcomes = outcomes
        }
        if let restored {
            self.restored = restored
        }
        if let current {
            self.current = current
        }
        if let delay {
            delayNanos = delay
        }
    }

    func setPresent(can: Bool, then: Result<Entitlement?, any Error>?) {
        canPresent = can
        currentAfterPresent = then
    }

    func presentOfferCodeRedemption() async -> Bool {
        if let currentAfterPresent {
            current = currentAfterPresent
        }
        return canPresent
    }

    func products() async throws -> [PlanProduct] {
        try catalog.get()
    }

    func purchase(_: String) async -> PurchaseOutcome {
        purchaseCalls += 1
        if delayNanos > 0 {
            try? await Task.sleep(nanoseconds: delayNanos)
        }
        return outcomes.isEmpty ? .failed : outcomes.removeFirst()
    }

    func restore() async throws -> Entitlement? {
        try restored.get()
    }

    func currentEntitlement() async throws -> Entitlement? {
        try current.get()
    }
}

@MainActor
struct CommerceStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)
    let monthly = PlanProduct(id: ProductIDs.monthly, period: .monthly, displayPrice: "49 kr", price: 49, currencyCode: "SEK")
    let annual = PlanProduct(id: ProductIDs.annual, period: .annual, displayPrice: "499 kr", price: 499, currencyCode: "SEK")

    func defaults() -> UserDefaults {
        UserDefaults(suiteName: "commerce-\(UUID().uuidString)") ?? .standard
    }

    func entitlement(days: Double = 30, verified: Date? = nil) -> Entitlement {
        Entitlement(kind: .paid, expiresAt: t0.addingTimeInterval(days * 86400), lastVerifiedAt: verified ?? t0, revoked: false)
    }

    func make(_ fake: FakeStore, defaults: UserDefaults? = nil, now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_791_716_400) })
        -> CommerceStore {
        CommerceStore(store: fake, defaults: defaults ?? self.defaults(), now: now)
    }

    @Test func catalogLoadsStorePricesInOrderMonthlyThenAnnual() async {
        let fake = FakeStore()
        await fake.set(catalog: .success([annual, monthly]))
        let store = make(fake)
        await store.loadCatalog()
        #expect(store.catalog == .loaded([monthly, annual]))
    }

    @Test func aFailedLoadIsAFailureNeverAFreePlan() async {
        let fake = FakeStore()
        await fake.set(catalog: .failure(FakeStore.Offline()))
        let store = make(fake)
        await store.loadCatalog()
        #expect(store.catalog == .failed)
        await fake.set(catalog: .success([monthly, annual]))
        await store.loadCatalog() // retry
        #expect(store.catalog == .loaded([monthly, annual]))
    }

    @Test func anEmptyCatalogCountsAsFailed() async {
        let store = make(FakeStore())
        await store.loadCatalog()
        #expect(store.catalog == .failed)
    }

    @Test func aSuccessfulPurchaseGrantsAndPersistsTheEntitlement() async {
        let fake = FakeStore()
        let e = entitlement()
        await fake.set(outcomes: [.success(e)])
        let d = defaults()
        let store = make(fake, defaults: d)
        await store.buy(ProductIDs.annual)
        #expect(store.purchase == .succeeded && store.activeEntitlement == e)
        let relaunched = make(fake, defaults: d)
        #expect(relaunched.activeEntitlement == e, "survives a relaunch")
    }

    @Test func pendingCancelledAndFailedUnlockNothing() async {
        for (outcome, expected) in [
            (PurchaseOutcome.pending, CommerceStore.Purchase.pending),
            (.cancelled, .cancelled),
            (.failed, .failed)
        ] {
            let fake = FakeStore()
            await fake.set(outcomes: [outcome])
            let store = make(fake)
            await store.buy(ProductIDs.monthly)
            #expect(store.purchase == expected)
            #expect(store.activeEntitlement == nil)
        }
    }

    @Test func aSecondTapWhilePurchasingDoesNotBuyTwice() async {
        let fake = FakeStore()
        await fake.set(outcomes: [.success(entitlement()), .success(entitlement())], delay: 200_000_000)
        let store = make(fake)
        async let first: Void = store.buy(ProductIDs.monthly)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await store.buy(ProductIDs.monthly)
        await first
        #expect(await fake.purchaseCalls == 1)
    }

    @Test func retryAfterAFailureCanSucceedOnce() async {
        let fake = FakeStore()
        await fake.set(outcomes: [.failed, .success(entitlement())])
        let store = make(fake)
        await store.buy(ProductIDs.monthly)
        #expect(store.purchase == .failed)
        await store.buy(ProductIDs.monthly)
        #expect(store.purchase == .succeeded && store.activeEntitlement != nil)
    }

    @Test func restoreFindsAPurchaseOrSaysNone() async {
        let fake = FakeStore()
        await fake.set(restored: .success(entitlement()))
        let store = make(fake)
        await store.restore()
        #expect(store.restoreState == .restored(found: true) && store.activeEntitlement != nil)
        let none = make(FakeStore())
        await none.restore()
        #expect(none.restoreState == .restored(found: false) && none.activeEntitlement == nil)
        let offline = FakeStore()
        await offline.set(restored: .failure(FakeStore.Offline()))
        let failed = make(offline)
        await failed.restore()
        #expect(failed.restoreState == .failed)
    }

    @Test func offlineKeepsTheCachedEntitlementOnlyInsideTheSevenDayWindow() async {
        let fake = FakeStore()
        let d = defaults()
        await fake.set(outcomes: [.success(entitlement(days: 60))])
        let buyer = make(fake, defaults: d)
        await buyer.buy(ProductIDs.annual)
        await fake.set(current: .failure(FakeStore.Offline()))
        let day6 = make(fake, defaults: d, now: { t0.addingTimeInterval(6 * 86400) })
        await day6.refreshEntitlement()
        #expect(day6.activeEntitlement != nil, "six days offline: still valid")
        let day8 = make(fake, defaults: d, now: { t0.addingTimeInterval(8 * 86400) })
        await day8.refreshEntitlement()
        #expect(day8.activeEntitlement == nil, "eight days offline: revalidate first")
    }

    @Test func aVerifiedNoneFromTheStoreClearsTheCacheAtOnce() async {
        let fake = FakeStore()
        let d = defaults()
        await fake.set(outcomes: [.success(entitlement(days: 60))])
        let store = make(fake, defaults: d)
        await store.buy(ProductIDs.annual)
        await fake.set(current: .success(nil)) // refund or revocation
        await store.refreshEntitlement()
        #expect(store.activeEntitlement == nil, "no paid grace after a known revocation")
        #expect(make(fake, defaults: d).activeEntitlement == nil)
    }

    @Test func cancellationKeepsAccessUntilTheKnownExpiry() async {
        let fake = FakeStore()
        await fake.set(current: .success(entitlement(days: 10)))
        let before = make(fake, now: { t0.addingTimeInterval(5 * 86400) })
        await before.refreshEntitlement()
        #expect(before.activeEntitlement != nil)
        let after = make(fake, now: { t0.addingTimeInterval(11 * 86400) })
        await after.refreshEntitlement()
        #expect(after.activeEntitlement == nil, "expired")
    }

    @Test func noStoreMeansNothingIsGrantedAndTheCatalogFails() async {
        let store = CommerceStore(store: nil, defaults: defaults(), now: { t0 })
        await store.loadCatalog()
        #expect(store.catalog == .failed)
        await store.buy(ProductIDs.monthly)
        #expect(store.activeEntitlement == nil)
    }

    // MARK: offer-code redemption (F19a)

    func complimentary(days: Double = 90) -> Entitlement {
        Entitlement(kind: .complimentary, expiresAt: t0.addingTimeInterval(days * 86400), lastVerifiedAt: t0, revoked: false)
    }

    func quick(_ fake: FakeStore, now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_791_716_400) }) -> CommerceStore {
        let store = make(fake, now: now)
        store.redeemAttempts = 3
        store.redeemRetryDelayNanos = 0
        return store
    }

    @Test func aRedeemedFreeOfferBecomesVerifiedComplimentaryAccess() async {
        let fake = FakeStore()
        await fake.setPresent(can: true, then: .success(complimentary()))
        let store = quick(fake)
        await store.redeemOfferCode()
        #expect(store.redeem == .activated)
        #expect(store.activeEntitlement?.kind == .complimentary)
    }

    @Test func nothingChangedMeansNothingUnlockedAndASaneMessage() async {
        let fake = FakeStore() // cancelled sheet, invalid, expired, used or ineligible code: the store still reports no entitlement
        let store = quick(fake)
        await store.redeemOfferCode()
        #expect(store.redeem == .notActivated && store.activeEntitlement == nil)
    }

    @Test func aSheetThatCannotBeShownIsReportedNotPretended() async {
        let fake = FakeStore()
        await fake.setPresent(can: false, then: nil)
        let store = quick(fake)
        await store.redeemOfferCode()
        #expect(store.redeem == .unavailable && store.activeEntitlement == nil)
    }

    @Test func offlineAfterTheSheetKeepsWhatWasKnownAndUnlocksNothingNew() async {
        let fake = FakeStore()
        await fake.setPresent(can: true, then: .failure(FakeStore.Offline()))
        let store = quick(fake)
        await store.redeemOfferCode()
        #expect(store.redeem == .notActivated && store.activeEntitlement == nil)
    }

    @Test func verificationDelayIsRetriedBeforeGivingUp() async {
        let fake = FakeStore()
        await fake.setPresent(can: true, then: .success(nil))
        let store = quick(fake)
        async let redeeming: Void = store.redeemOfferCode()
        try? await Task.sleep(nanoseconds: 20_000_000)
        await fake.set(current: .success(complimentary()))
        await redeeming
        #expect(store.redeem == .activated || store.redeem == .notActivated, "either outcome is honest; it must finish")
    }

    @Test func aPaidSubscriberWhoRedeemsKeepsPaidAccessWhenTheFreeOfferEndsEarlier() async {
        let fake = FakeStore()
        await fake.set(current: .success(entitlement(days: 200)))
        let store = quick(fake)
        await store.refreshEntitlement()
        let paid = store.activeEntitlement
        await fake.setPresent(can: true, then: .success(entitlement(days: 200))) // the store resolves overlap itself
        await store.redeemOfferCode()
        #expect(store.activeEntitlement?.kind == .paid && store.activeEntitlement == paid)
    }

    @Test func complimentaryAccessEndsAtItsKnownExpiryAndNoOneIsCharged() async {
        let fake = FakeStore()
        // Verified at the moment of each check, as the live store does: only the known expiry decides here.
        let verifiedLate = Entitlement(
            kind: .complimentary, expiresAt: t0.addingTimeInterval(90 * 86400), lastVerifiedAt: t0.addingTimeInterval(80 * 86400),
            revoked: false
        )
        await fake.set(current: .success(verifiedLate))
        let before = quick(fake, now: { t0.addingTimeInterval(80 * 86400) })
        await before.refreshEntitlement()
        #expect(before.activeEntitlement != nil)
        let verifiedEnd = Entitlement(
            kind: .complimentary, expiresAt: t0.addingTimeInterval(90 * 86400), lastVerifiedAt: t0.addingTimeInterval(91 * 86400),
            revoked: false
        )
        await fake.set(current: .success(verifiedEnd))
        let after = quick(fake, now: { t0.addingTimeInterval(91 * 86400) })
        await after.refreshEntitlement()
        #expect(after.activeEntitlement == nil, "back to the Free balance after the term")
    }
}
