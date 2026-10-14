import Allowance
import Foundation
import Observation

/// Plans, purchase, restore and the verified entitlement (F19). Nothing is unlocked until the store has verified a transaction;
/// a failed or empty catalog is a failure with a retry, never a plan that looks free.
@MainActor @Observable
final class CommerceStore {
    enum Catalog: Equatable {
        case idle, loading
        case loaded([PlanProduct])
        case failed
    }

    enum Purchase: Equatable {
        case idle
        case purchasing(String)
        case pending, cancelled, failed, succeeded
    }

    enum RestoreState: Equatable {
        case idle, restoring, failed
        case restored(found: Bool)
    }

    private(set) var catalog = Catalog.idle
    private(set) var purchase = Purchase.idle
    private(set) var restoreState = RestoreState.idle
    /// The last verified entitlement, kept for offline use. Whether it still counts is decided by `activeEntitlement`.
    private(set) var entitlement: Entitlement?

    private let store: (any StoreProviding)?
    private let defaults: UserDefaults
    private let now: () -> Date
    static let entitlementKey = "commerce.entitlement"

    init(store: (any StoreProviding)?, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.entitlementKey) {
            entitlement = try? JSONDecoder().decode(Entitlement.self, from: data)
        }
    }

    /// The entitlement if it is valid right now: not revoked, before its known expiry, inside the offline revalidation window.
    var activeEntitlement: Entitlement? {
        entitlement.flatMap { $0.isActive(now: now()) ? $0 : nil }
    }

    var isBusy: Bool {
        if case .purchasing = purchase {
            return true
        }
        return restoreState == .restoring
    }

    private func setEntitlement(_ value: Entitlement?) {
        entitlement = value
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.entitlementKey)
        } else {
            defaults.removeObject(forKey: Self.entitlementKey)
        }
    }

    func loadCatalog() async {
        guard let store else {
            catalog = .failed
            return
        }
        catalog = .loading
        do {
            let products = try await store.products()
            let ordered = PlanPeriod.allCases.compactMap { period in products.first { $0.period == period } }
            catalog = ordered.count == PlanPeriod.allCases.count ? .loaded(ordered) : .failed
        } catch {
            catalog = .failed
        }
    }

    func buy(_ productID: String) async {
        guard let store, !isBusy else { return }
        purchase = .purchasing(productID)
        switch await store.purchase(productID) {
        case let .success(entitlement):
            setEntitlement(entitlement)
            purchase = .succeeded
        case .pending: purchase = .pending
        case .cancelled: purchase = .cancelled
        case .failed: purchase = .failed
        }
    }

    func restore() async {
        guard let store, !isBusy else {
            if store == nil {
                restoreState = .failed
            }
            return
        }
        restoreState = .restoring
        do {
            let found = try await store.restore()
            setEntitlement(found)
            restoreState = .restored(found: found != nil)
        } catch {
            restoreState = .failed
        }
    }

    /// Run at launch and when the store reports a change. A verified answer replaces the cache (including "none": a refund or
    /// revocation takes effect at once); an unreachable store leaves the cache to age out inside its offline window.
    func refreshEntitlement() async {
        guard let store else { return }
        do {
            try await setEntitlement(store.currentEntitlement())
        } catch {
            return
        }
    }

    func dismissOutcome() {
        if !isBusy {
            purchase = .idle
        }
    }
}
