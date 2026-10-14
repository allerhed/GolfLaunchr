import Allowance
import SwiftUI

/// Plans and purchase (F19). Prices are the store's own localised strings; a loading failure offers a retry and never shows a free
/// plan. "Continue free" is always there. No trial and no promise beyond what is built and validated.
struct PaywallView: View {
    @SwiftUI.Environment(CommerceStore.self) private var commerce
    @SwiftUI.Environment(AllowanceStore.self) private var allowance
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    if let active = commerce.activeEntitlement {
                        activeCard(active)
                    }
                    catalog
                    status
                    actions
                    Text("paywall.autorenew").font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(Spacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(Tokens.background.color)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("paywall.continueFree") }.accessibilityIdentifier("paywall.continueFree")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if commerce.catalog == .idle || commerce.catalog == .failed {
                await commerce.loadCatalog()
            }
        }
        .accessibilityIdentifier("paywall.root")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("paywall.title").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text("paywall.subtitle").font(.title3).foregroundStyle(Tokens.textSecondary.color)
            Label { Text("paywall.feature.unlimited") } icon: { Image(systemName: "infinity") }
            Label { Text("paywall.feature.analysis") } icon: { Image(systemName: "chart.dots.scatter") }
            Text("paywall.free.summary").font(.footnote).foregroundStyle(Tokens.textSecondary.color)
        }
    }

    private func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }

    private func perMonth(_ plan: PlanProduct) -> String {
        Pricing.annualPerMonth(plan).formatted(.currency(code: plan.currencyCode).locale(locale))
    }

    private func activeCard(_ entitlement: Entitlement) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label { Text("paywall.active") } icon: { Image(systemName: "checkmark.seal.fill") }.font(.headline)
            Text(entitlement.expiresAt, format: .dateTime.day().month(.wide).year())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.active")
    }

    @ViewBuilder
    private var catalog: some View {
        switch commerce.catalog {
        case .idle, .loading:
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text("paywall.loading")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paywall.loading")
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label { Text("paywall.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .accessibilityIdentifier("paywall.failed")
                Button { Task { await commerce.loadCatalog() } } label: {
                    Text("paywall.retry").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("paywall.retry")
            }
        case let .loaded(products):
            VStack(spacing: Spacing.m) {
                ForEach(products) { plan in
                    planCard(plan, all: products)
                }
            }
        }
    }

    private func planCard(_ plan: PlanProduct, all: [PlanProduct]) -> some View {
        let isAnnual = plan.period == .annual
        let monthly = all.first { $0.period == .monthly }
        return VStack(alignment: .leading, spacing: Spacing.s) {
            // The texts are one element with the identifier; the button stays its own element (a container identifier would hide it).
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(isAnnual ? "paywall.plan.annual" : "paywall.plan.monthly").font(.headline)
                Text(isAnnual ? "paywall.price.year \(plan.displayPrice)" : "paywall.price.month \(plan.displayPrice)")
                    .font(.title2.bold())
                if isAnnual {
                    Text("paywall.annual.perMonth \(perMonth(plan))")
                        .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
                    if let monthly, let saving = Pricing.annualSavingPercent(monthly: monthly, annual: plan), saving > 0 {
                        Text("paywall.annual.saving \(percent(saving))")
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paywall.plan.\(plan.period.rawValue)")
            Button { Task { await commerce.buy(plan.id) } } label: {
                Text(isAnnual ? "paywall.buy.annual" : "paywall.buy.monthly").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(commerce.isBusy)
            .accessibilityIdentifier("paywall.buy.\(plan.period.rawValue)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var status: some View {
        let message: LocalizedStringKey? = switch commerce.purchase {
        case .pending: "paywall.status.pending"
        case .cancelled: "paywall.status.cancelled"
        case .failed: "paywall.status.failed"
        case .succeeded: "paywall.status.succeeded"
        default: nil
        }
        if let message {
            Text(message).font(.subheadline.weight(.semibold)).accessibilityIdentifier("paywall.status")
        }
        switch commerce.restoreState {
        case .restored(found: true): Text("paywall.restore.found").accessibilityIdentifier("paywall.restoreStatus")
        case .restored(found: false): Text("paywall.restore.none").accessibilityIdentifier("paywall.restoreStatus")
        case .failed: Text("paywall.restore.failed").accessibilityIdentifier("paywall.restoreStatus")
        default: EmptyView()
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button { Task { await commerce.restore() } } label: {
                Text("paywall.restore").frame(minHeight: Spacing.minTarget)
            }
            .disabled(commerce.isBusy)
            .accessibilityIdentifier("paywall.restore")
            Button {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            } label: { Text("paywall.manage").frame(minHeight: Spacing.minTarget) }
                .accessibilityIdentifier("paywall.manage")
            Button {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    openURL(url)
                }
            } label: { Text("paywall.terms").frame(minHeight: Spacing.minTarget) }
                .accessibilityIdentifier("paywall.terms")
        }
    }
}
