import Analytics
import Domain
import Formatting
import SwiftUI

/// The detailed profile of one club under the active filter: median, 10th/90th percentile, range, metric averages with how many
/// shots each is based on, and lateral spread where available.
struct ClubProfileView: View {
    let clubID: UUID
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        let result = store.result
        if let profile = result.profiles.first(where: { $0.clubID == clubID }) {
            let kind = store.applied.distance
            List {
                Section {
                    row("analysis.profile.shots") { Text("history.shotCount \(profile.shotCount)") }
                    row("analysis.profile.samples") { Text(verbatim: "\(profile.distanceSamples)") }
                    if profile.isProvisional {
                        Label { Text("analysis.provisional.note") } icon: { Image(systemName: "info.circle") }
                    }
                    distanceRow(kind.meanTitleKey, profile.mean, kind)
                    distanceRow("analysis.profile.median", profile.median, kind)
                    distanceRow("analysis.profile.p10", profile.p10, kind)
                    distanceRow("analysis.profile.p90", profile.p90, kind)
                    row("analysis.profile.range") { Text(verbatim: rangeText(profile, kind)) }
                    row("analysis.card.spread") {
                        Text(verbatim: profile.spread.flatMap { formatter.format($0, for: kind.key) }.map { "±\($0.text)" } ?? "–")
                    }
                } header: { Text(verbatim: profile.name).foregroundStyle(Tokens.textSecondary.color) }
                    .listRowBackground(Tokens.surface.color)
                Section {
                    ForEach(profile.metrics.filter { $0.validSamples > 0 }, id: \.key) { m in
                        row(m.key.titleKey) {
                            VStack(alignment: .trailing) {
                                Text(verbatim: formatter.format(m.mean, for: m.key)?.text ?? "–").font(.body.monospacedDigit())
                                Text("analysis.coverage \(m.validSamples) \(profile.shotCount)").font(.caption)
                                    .foregroundStyle(Tokens.textSecondary.color)
                            }
                        }
                    }
                    if profile.lateralSamples > 0 {
                        row("analysis.profile.lateral") {
                            Text(verbatim: profile.lateralSpread.flatMap { formatter.format($0, for: .lateralLanding) }
                                .map { "±\($0.text)" } ?? "–")
                        }
                    }
                } header: { Text("analysis.profile.metrics").foregroundStyle(Tokens.textSecondary.color) }
                    .listRowBackground(Tokens.surface.color)
                Section {
                    NavigationLink(value: ClubShotsRoute(id: clubID)) {
                        Text("analysis.profile.viewShots").frame(minHeight: Spacing.minTarget)
                    }
                    .accessibilityIdentifier("analysis.profile.viewShots")
                }
                .listRowBackground(Tokens.surface.color)
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.background.color)
            .navigationTitle(Text(verbatim: profile.name))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ClubShotsRoute.self) { ClubShotsView(clubID: $0.id) }
            .accessibilityIdentifier("analysis.profile")
        } else {
            ContentUnavailableView { Label { Text("analysis.empty") } icon: { Image(systemName: "chart.dots.scatter") } }
        }
    }

    private func rangeText(_ p: ClubProfile, _ kind: DistanceKind) -> String {
        guard let lo = formatter.format(p.shortest, for: kind.key), let hi = formatter.format(p.longest, for: kind.key) else { return "–" }
        return "\(lo.number)–\(hi.text)"
    }

    private func distanceRow(_ title: LocalizedStringKey, _ value: Double?, _ kind: DistanceKind) -> some View {
        row(title) {
            VStack(alignment: .trailing) {
                Text(verbatim: formatter.format(value, for: kind.key)?.text ?? "–").font(.body.monospacedDigit().weight(.semibold))
                if value != nil {
                    Text("provenance.estimated").font(.caption).foregroundStyle(Tokens.textSecondary.color)
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        LabeledContent { value() } label: { Text(title) }
    }
}

struct ClubShotsRoute: Hashable {
    let id: UUID
}

/// "View all shots": the club's eligible shots under the filter, each opening the shot detail.
struct ClubShotsView: View {
    let clubID: UUID
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    var body: some View {
        let shots = store.result.selection.shots.filter { $0.clubSnapshot.id == clubID }
        let formatter = MetricFormatter(units: settings.units, locale: locale)
        List {
            ForEach(shots, id: \.id) { shot in
                Button { history.selectedShotID = shot.id } label: { ShotRow(shot: shot, formatter: formatter) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("analysis.shot.\(shot.id.uuidString)")
            }
            .listRowBackground(Tokens.surface.color)
        }
        .scrollContentBackground(.hidden)
        .background(Tokens.background.color)
        .navigationTitle(Text(verbatim: shots.first?.clubSnapshot.name ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.clubShots")
    }
}
