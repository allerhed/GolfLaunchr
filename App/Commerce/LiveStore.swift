import Allowance
import Foundation
import StoreKit
import UIKit

/// StoreKit 2. Only verified transactions count; an unverified one is never granted.
struct LiveStore: StoreProviding {
    func products() async throws -> [PlanProduct] {
        // The store can answer empty or fail for a moment right after launch: ask a few times before reporting a failure.
        var lastError: (any Error)?
        for attempt in 0 ..< 3 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            do {
                let found = try await Product.products(for: ProductIDs.all)
                let plans = found.compactMap { product -> PlanProduct? in
                    guard let period = ProductIDs.period(of: product.id) else { return nil }
                    return PlanProduct(
                        id: product.id, period: period, displayPrice: product.displayPrice, price: product.price,
                        currencyCode: product.priceFormatStyle.currencyCode
                    )
                }
                if plans.count == ProductIDs.all.count {
                    return plans
                }
            } catch {
                lastError = error
            }
        }
        throw lastError ?? URLError(.resourceUnavailable)
    }

    func purchase(_ productID: String) async -> PurchaseOutcome {
        do {
            guard let product = try await Product.products(for: [productID]).first else { return .failed }
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await transaction.finish()
                guard let entitlement = try await currentEntitlement() else { return .failed }
                return .success(entitlement)
            case .success(.unverified):
                return .failed
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async throws -> Entitlement? {
        try await AppStore.sync()
        return try await currentEntitlement()
    }

    func currentEntitlement() async throws -> Entitlement? {
        var found: [TransactionFact] = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result, ProductIDs.all.contains(transaction.productID),
                  let expires = transaction.expirationDate else { continue }
            // Only verified offer metadata marks complimentary access: a free offer code. Anything else is shown as plain Pro.
            let free = transaction.offer?.type == .code && transaction.offer?.paymentMode == .freeTrial
            found.append(TransactionFact(
                expiresAt: expires,
                revoked: transaction.revocationDate != nil,
                kind: free ? .complimentary : .paid
            ))
        }
        return Entitlement.resolve(from: found, verifiedAt: Date())
    }

    @MainActor
    func presentOfferCodeRedemption() async -> Bool {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let scene else { return false }
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            return true
        } catch {
            return false
        }
    }
}
