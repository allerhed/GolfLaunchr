import Allowance
import SwiftUI

struct MembershipSection: View {
    @SwiftUI.Environment(CommerceStore.self) private var commerce
    @State private var showingPlans = false

    /// Membership (F19/F19a): what access is verified right now, the plans, and Apple's offer-code sheet. Complimentary access is
    /// labelled only when the store's verified offer metadata says so; otherwise it is plain Pro.
    var body: some View {
        Section {
            if let access = commerce.activeEntitlement {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if access.kind == .complimentary {
                        Text("membership.complimentary").font(.headline)
                        HStack(spacing: Spacing.xs) {
                            Text("membership.ends")
                            Text(access.expiresAt, format: .dateTime.day().month(.wide).year())
                        }
                        Text("membership.noCharge").font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                    } else {
                        Text("membership.pro").font(.headline)
                        HStack(spacing: Spacing.xs) {
                            Text("paywall.active")
                            Text(access.expiresAt, format: .dateTime.day().month(.wide).year())
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.membership.status")
            } else {
                Text("membership.free").accessibilityIdentifier("settings.membership.status")
            }
            Button { showingPlans = true } label: {
                Text("allowance.see.plans").frame(minHeight: Spacing.minTarget, alignment: .leading)
            }
            .accessibilityIdentifier("settings.plans")
            // The presentation hangs on one row: on the Section it would apply to every row.
            .sheet(isPresented: $showingPlans) { PaywallView() }
            Button { Task { await commerce.redeemOfferCode() } } label: {
                Text("membership.redeem").frame(minHeight: Spacing.minTarget, alignment: .leading)
            }
            .disabled(commerce.isBusy)
            .accessibilityIdentifier("settings.redeem")
            redeemStatus
        } header: {
            Text("membership.header", comment: "Section header: membership and plans").foregroundStyle(Tokens.textSecondary.color)
        } footer: {
            Text("membership.redeem.footer", comment: "Warning for people who already subscribe, before they apply an offer code")
                .foregroundStyle(Tokens.textSecondary.color)
        }
        .listRowBackground(Tokens.surface.color)
    }

    @ViewBuilder
    private var redeemStatus: some View {
        switch commerce.redeem {
        case .checking, .presenting: Text("membership.redeem.checking").accessibilityIdentifier("settings.redeem.status")
        case .activated: Text("membership.redeem.activated").accessibilityIdentifier("settings.redeem.status")
        case .notActivated: Text("membership.redeem.notActivated").accessibilityIdentifier("settings.redeem.status")
        case .unavailable: Text("membership.redeem.unavailable").accessibilityIdentifier("settings.redeem.status")
        case .idle: EmptyView()
        }
    }
}
