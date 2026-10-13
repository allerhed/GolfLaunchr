import Analytics
import Domain
import Formatting
import SwiftUI

/// Mean distance per club in bag order and the signed gap to the next club. Never sorted, never bridged over a club without data.
struct GappingView: View {
    let result: AnalysisStore.Result
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        let table = result.gap
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("analysis.title.gapping").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("analysis.gap.table")
            VStack(spacing: 0) {
                HStack {
                    Text("analysis.gap.club").frame(maxWidth: .infinity, alignment: .leading)
                    Text(table.distance.meanTitleKey).frame(width: 84, alignment: .trailing)
                    Text("analysis.gap.next").frame(width: 96, alignment: .trailing)
                }
                .font(.caption).foregroundStyle(Tokens.textSecondary.color)
                .padding(.vertical, Spacing.s)
                ForEach(Array(table.rows.enumerated()), id: \.element.clubID) { index, row in
                    Divider()
                    rowView(row, index: index)
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
            if table.selectedClubsOnly {
                warning("analysis.gap.selectedOnly", detail: "analysis.gap.selectedOnly.text", id: "analysis.gap.selectedOnly")
            }
            if table.mixedConditions {
                warning("analysis.gap.mixed", detail: nil, id: "analysis.gap.mixed")
            }
            Label { Text("analysis.footer") } icon: { Image(systemName: "info.circle") }
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
        }
    }

    private func rowView(_ row: ClubGapRow, index: Int) -> some View {
        HStack {
            HStack(spacing: Spacing.m) {
                ClubAvatar(name: row.name, style: store.style(for: row.clubID))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: row.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Text("history.shotCount \(row.sampleCount)").font(.caption).foregroundStyle(Tokens.textSecondary.color).lineLimit(1)
                    if row.isProvisional, row.sampleCount > 0 {
                        ProvisionalBadge()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let text = formatter.format(row.meanM, for: result.gap.distance.key)?.text {
                    Text(verbatim: text).font(.title3.bold().monospacedDigit())
                } else {
                    Text("history.noData").foregroundStyle(Tokens.textSecondary.color)
                }
            }
            .frame(width: 84, alignment: .trailing)
            gapCell(row).frame(width: 96, alignment: .trailing)
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("analysis.gap.row.\(index)")
    }

    @ViewBuilder private func gapCell(_ row: ClubGapRow) -> some View {
        if let gap = row.gapToNextM, let f = formatter.format(abs(gap), for: result.gap.distance.key) {
            if gap < 0 {
                VStack(alignment: .trailing, spacing: 0) {
                    Label { Text(verbatim: "−\(f.text)") } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .font(.headline.monospacedDigit())
                    Text("analysis.gap.inverted").font(.caption2).foregroundStyle(Tokens.textSecondary.color)
                }
            } else {
                Text(verbatim: f.text).font(.headline.monospacedDigit()).foregroundStyle(Tokens.accent.color)
            }
        } else {
            Text(verbatim: "—").foregroundStyle(Tokens.textSecondary.color)
        }
    }

    private func warning(_ title: LocalizedStringKey, detail: LocalizedStringKey?, id: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: "info.circle").accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                if let detail {
                    Text(detail)
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
