import Analytics
import Domain
import Formatting
import SwiftUI

/// One shot: every metric with how it was obtained, its quality and any failure reason, plus the context it was taken in.
struct ShotDetailView: View {
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(AnalysisStore.self) private var analysis
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.dismiss) private var dismiss

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        NavigationStack {
            if let id = history.selectedShotID, let shot = history.shot(id) {
                List {
                    comparisonSection(shot)
                    Section {
                        ForEach(MetricKey.allCases, id: \.self) { key in metricRow(key, shot: shot) }
                    } header: { Text("shot.section.metrics", comment: "Section: the shot's measurements") }
                        .listRowBackground(Tokens.surface.color)
                    Section {
                        row("shot.club") { Text(verbatim: shot.clubSnapshot.name) }
                        row("shot.handedness") { Text(shot.swingHandedness == .right ? "handedness.right" : "handedness.left") }
                        row("shot.time") { Text(shot.impactTimeUTC, format: .dateTime.day().month().year().hour().minute().second()) }
                        row("shot.exclusion") { Text(shot.included ? "shot.included" : "shot.excluded") }
                        if shot.isSynthetic {
                            row("history.demo") { DemoBadge() }
                        }
                    } header: { Text("shot.section.context", comment: "Section: when and how the shot was taken") }
                        .listRowBackground(Tokens.surface.color)
                    Section {
                        Button { Task { await history.setIncluded(shot.id, !shot.included) } } label: {
                            Text(shot.included ? "shot.exclude" : "shot.restore").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                        }
                        .accessibilityIdentifier("shotDetail.toggle")
                    }
                    .listRowBackground(Tokens.surface.color)
                }
                .scrollContentBackground(.hidden)
                .background(Tokens.background.color)
                .navigationTitle(Text("shot.number \(shot.sequence)"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: { Text("settings.done") }
                            .frame(minHeight: Spacing.minTarget).accessibilityIdentifier("shotDetail.done")
                    }
                }
            }
        }
        .accessibilityIdentifier("shotDetail.root")
    }

    /// The shot against its own club's average under the filter in force (F10a): average, signed difference, sample count, and whether
    /// this shot is part of that average. Nothing is shown when either side has no value.
    @ViewBuilder private func comparisonSection(_ shot: Shot) -> some View {
        let key = analysis.applied.distance.key
        Section {
            if let c = analysis.comparison(for: shot, key: key) {
                row("shot.compare.average") {
                    Text(verbatim: formatter.format(c.clubMean, for: key)?.text ?? "–").font(.body.monospacedDigit())
                }
                row("shot.compare.difference") {
                    Text(verbatim: signed(c.delta, key)).font(.body.monospacedDigit().weight(.semibold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("shotDetail.compare.delta")
                row("shot.compare.basedOn") { Text("history.shotCount \(c.sampleCount)") }
                if !c.shotIsIncluded {
                    Label { Text("shot.compare.excluded") } icon: { Image(systemName: "eye.slash") }
                        .accessibilityIdentifier("shotDetail.compare.excluded")
                }
            } else {
                Text("shot.compare.none").foregroundStyle(Tokens.textSecondary.color)
                    .accessibilityIdentifier("shotDetail.compare.none")
            }
        } header: { Text("shot.compare.title", comment: "Section: comparison with the club's average") }
            .listRowBackground(Tokens.surface.color)
    }

    private func signed(_ si: Double, _ key: MetricKey) -> String {
        guard let f = formatter.format(abs(si), for: key) else { return "–" }
        return si < 0 ? "−\(f.text)" : (si > 0 ? "+\(f.text)" : f.text)
    }

    private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        LabeledContent { value() } label: { Text(title) }
    }

    private func metricRow(_ key: MetricKey, shot: Shot) -> some View {
        let metric = shot.metrics[key]
        let usable = metric.flatMap { $0.provenance == .unavailable ? nil : $0.value }
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(key.titleKey)
                Spacer()
                if let formatted = formatter.format(usable, for: key) {
                    Text(verbatim: formatted.text).font(.body.monospacedDigit().weight(.semibold))
                } else {
                    Text("provenance.unavailable").foregroundStyle(Tokens.textSecondary.color)
                }
            }
            if let metric, metric.provenance != .unavailable {
                // A value: say how it was obtained and how good it is.
                HStack(spacing: Spacing.s) {
                    Text(metric.provenance.titleKey)
                    Text(metric.quality.titleKey)
                    if let u = metric.uncertainty95, let text = formatter.format(u, for: key) {
                        Text(verbatim: "± \(text.text)")
                    }
                }
                .font(.caption).foregroundStyle(Tokens.textSecondary.color)
            } else if let failure = metric?.failure {
                // No value: the only useful extra is why.
                Text(failure.titleKey).font(.caption).foregroundStyle(Tokens.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shotDetail.metric.\(key.rawValue)")
    }
}
