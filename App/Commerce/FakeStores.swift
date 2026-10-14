#if DEBUG
    import Allowance
    import Foundation

    /// Debug-only store for UI tests (`-uiTestStore ok|loadFail|pending|cancel|fail`): no StoreKit, no network, no charge.
    final class ScriptedStore: StoreProviding, @unchecked Sendable {
        enum Scenario: String { case ok, loadFail, pending, cancel, fail, redeem }
        let scenario: Scenario
        private var redeemed = false
        init(_ scenario: Scenario) {
            self.scenario = scenario
        }

        func products() async throws -> [PlanProduct] {
            if scenario == .loadFail {
                throw URLError(.notConnectedToInternet)
            }
            return [
                PlanProduct(id: ProductIDs.monthly, period: .monthly, displayPrice: "49 kr", price: 49, currencyCode: "SEK"),
                PlanProduct(id: ProductIDs.annual, period: .annual, displayPrice: "499 kr", price: 499, currencyCode: "SEK"),
            ]
        }

        func purchase(_: String) async -> PurchaseOutcome {
            switch scenario {
            case .ok: .success(Entitlement(
                    kind: .paid,
                    expiresAt: Date().addingTimeInterval(30 * 86400),
                    lastVerifiedAt: Date(),
                    revoked: false
                ))
            case .pending: .pending
            case .cancel: .cancelled
            case .fail, .loadFail, .redeem: .failed
            }
        }

        func restore() async throws -> Entitlement? {
            nil
        }

        func currentEntitlement() async throws -> Entitlement? {
            guard redeemed else { return nil }
            return Entitlement(
                kind: .complimentary,
                expiresAt: Date().addingTimeInterval(90 * 86400),
                lastVerifiedAt: Date(),
                revoked: false
            )
        }

        /// `redeem` scenario: the sheet "accepts" a free offer code. Every other scenario closes it with nothing redeemed.
        func presentOfferCodeRedemption() async -> Bool {
            if scenario == .redeem {
                redeemed = true
            }
            return true
        }
    }
#endif
