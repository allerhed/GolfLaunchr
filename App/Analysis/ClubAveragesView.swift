import Analytics
import Domain
import Formatting
import SwiftUI

/// One card per club: shots, mean distance and Spread (±1 SD, sample SD) with provenance, and a Provisional flag below ten shots.
struct ClubAveragesView: View {
    let result: AnalysisStore.Result
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("analysis.title.averages").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            ForEach(Array(result.profiles.enumerated()), id: \.element.clubID) { index, profile in
                NavigationLink(value: ClubRoute(id: profile.clubID)) { card(profile, style: store.style(for: profile.clubID)) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("analysis.card.\(index)")
            }
            Label { Text("analysis.footer") } icon: { Image(systemName: "info.circle") }
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
        }
    }

    private func card(_ p: ClubProfile, style: ClubStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                ClubAvatar(name: p.name, style: style)
                VStack(alignment: .leading) {
                    Text(verbatim: p.name).font(.headline)
                    HStack(spacing: Spacing.s) {
                        Text("history.shotCount \(p.shotCount)").foregroundStyle(Tokens.textSecondary.color)
                        if p.isProvisional, p.distanceSamples > 0 {
                            ProvisionalBadge()
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Tokens.textSecondary.color).accessibilityHidden(true)
            }
            Divider()
            HStack(alignment: .top) {
                stat(result.gap.distance.meanTitleKey, value: formatter.format(p.mean, for: result.gap.distance.key)?.text, id: "mean")
                Divider()
                stat(
                    "analysis.card.spread",
                    value: p.spread.flatMap { formatter.format($0, for: result.gap.distance.key) }.map { "±\($0.text)" },
                    note: p.spread == nil && p.mean != nil ? "analysis.spread.needTwo" : nil,
                    id: "spread"
                )
            }
        }
        .padding(Spacing.m)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: LocalizedStringKey, value: String?, note: LocalizedStringKey? = nil, id _: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
            if let value {
                Text(verbatim: value).font(Typography.metricNumeral).minimumScaleFactor(0.6).lineLimit(1)
                Text("provenance.estimated").font(.caption).foregroundStyle(Tokens.textSecondary.color)
            } else {
                Text("history.noData").font(.title3).foregroundStyle(Tokens.textSecondary.color)
                if let note {
                    Text(note).font(.caption).foregroundStyle(Tokens.textSecondary.color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProvisionalBadge: View {
    var body: some View {
        Text("analysis.provisional").font(.caption2.bold())
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .overlay(Capsule().stroke(Tokens.textSecondary.color))
            .accessibilityIdentifier("analysis.provisional")
    }
}
