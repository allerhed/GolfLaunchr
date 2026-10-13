import Analytics
import Domain
import Formatting
import SwiftUI

struct SessionDetailView: View {
    let sessionID: UUID
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(AnalysisStore.self) private var analysis
    @SwiftUI.Environment(AppNavigation.self) private var navigation
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var shotToDelete: UUID?
    @State private var confirmSessionDelete = false

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        @Bindable var history = history
        Group {
            if let summary = history.summary(sessionID) {
                content(summary)
            } else {
                ContentUnavailableView { Label { Text("history.noMatches") } icon: { Image(systemName: "questionmark.folder") } }
            }
        }
        .sheet(isPresented: Binding(get: { history.selectedShotID != nil }, set: {
            if !$0 {
                history.selectedShotID = nil
            }
        })) {
            ShotDetailView().environment(history).environment(settings)
        }
    }

    private func content(_ summary: SessionSummary) -> some View {
        List {
            if case .storageFailed = history.lastError {
                Text("history.saveError", comment: "Shown when a history change could not be saved")
                    .accessibilityIdentifier("session.error")
            }
            Section {
                ForEach(history.shots(of: sessionID)) { shot in
                    Button { history.selectedShotID = shot.id } label: { ShotRow(shot: shot, formatter: formatter) }
                        .buttonStyle(.plain)
                        // Long-press menu and VoiceOver actions: every shot action is reachable without a swipe.
                        .contextMenu { shotActions(shot) }
                        .accessibilityAction(named: Text(shot.included ? "shot.exclude" : "shot.restore")) {
                            Task { await history.setIncluded(shot.id, !shot.included) }
                        }
                        .accessibilityAction(named: Text("shot.delete")) { shotToDelete = shot.id }
                        .accessibilityIdentifier("session.shotRow.\(shot.id.uuidString)")
                }
            } header: {
                // The summary is the section's header (not a tall first row): rows below it are laid out by the list normally.
                VStack(alignment: .leading, spacing: Spacing.m) {
                    header(summary)
                        .foregroundStyle(Tokens.textPrimary.color)
                        .padding(Spacing.m)
                        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                    Text("session.shots", comment: "Section header: the shots of a session")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityValue(Text(verbatim: "\(history.shots(of: sessionID).count)"))
                        .accessibilityIdentifier("session.shotsHeader")
                }
                .textCase(nil)
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Tokens.surface.color)
        }
        .scrollContentBackground(.hidden)
        .background(Tokens.background.color)
        .navigationTitle(Text(summary.mode.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    analysis.focus(onSession: sessionID)
                    navigation.paths[.progress] = NavigationPath()
                    navigation.progressSection = .analysis
                } label: {
                    Image(systemName: "chart.dots.scatter").frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                }
                .accessibilityLabel(Text("session.analyse", comment: "Button: open this session's averages, gapping and dispersion"))
                .accessibilityIdentifier("session.analyse")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { confirmSessionDelete = true } label: {
                    Image(systemName: "trash").frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                }
                .accessibilityLabel(Text("session.delete", comment: "Button: delete this session permanently"))
                .accessibilityIdentifier("session.delete")
            }
        }
        .modifier(DeletionDialogs(sessionID: sessionID, shotToDelete: $shotToDelete, confirmSessionDelete: $confirmSessionDelete))
    }

    @ViewBuilder
    private func shotActions(_ shot: Shot) -> some View {
        Button { Task { await history.setIncluded(shot.id, !shot.included) } } label: {
            Label { Text(shot.included ? "shot.exclude" : "shot.restore") } icon: {
                Image(systemName: shot.included ? "eye.slash" : "arrow.uturn.backward")
            }
        }
        Button(role: .destructive) { shotToDelete = shot.id } label: {
            Label { Text("shot.delete") } icon: { Image(systemName: "trash") }
        }
    }

    private func header(_ summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(summary.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
                    .font(.headline)
                if summary.containsDemoData {
                    DemoBadge()
                }
            }
            if let duration = summary.duration {
                Text(Duration.seconds(duration), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                    .foregroundStyle(Tokens.textSecondary.color)
            }
            Text("history.included \(summary.includedCount) \(summary.shotCount)")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("session.summary.included")
            metricLine(
                "history.carry.mean",
                value: formatter.format(summary.meanCarryMetres, for: .carry),
                provenance: .estimated,
                id: "session.mean.carry"
            )
            metricLine(
                "history.speed.mean", value: formatter.format(summary.meanBallSpeedMetresPerSecond, for: .ballSpeed), provenance: .measured,
                id: "session.mean.speed"
            )
            if !summary.clubs.isEmpty {
                Text(verbatim: ListFormatter.localizedString(byJoining: summary.clubs.map(\.name)))
                    .foregroundStyle(Tokens.textSecondary.color)
            }
        }
    }

    /// "Average estimated carry  130 m (Estimated)", or "No data" with the same label: never a 0. The value and its label drop below
    /// the title when the row is too narrow, so nothing is clipped.
    private func metricLine(_ title: LocalizedStringKey, value: FormattedMetric?, provenance: Provenance, id: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).foregroundStyle(Tokens.textSecondary.color).lineLimit(1)
                Spacer()
                valueParts(value, provenance)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).foregroundStyle(Tokens.textSecondary.color)
                HStack { valueParts(value, provenance) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder private func valueParts(_ value: FormattedMetric?, _ provenance: Provenance) -> some View {
        if let value {
            Text(verbatim: value.text).font(.headline.monospacedDigit())
            Text(provenance.titleKey).font(.caption).foregroundStyle(Tokens.textSecondary.color)
        } else {
            Text("history.noData").foregroundStyle(Tokens.textSecondary.color)
        }
    }
}

struct ShotRow: View {
    let shot: Shot
    let formatter: MetricFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("shot.number \(shot.sequence)").font(.headline)
                Text(verbatim: shot.clubSnapshot.name)
                if !shot.included {
                    Text("shot.excluded", comment: "Tag on a shot that is excluded from averages")
                        .font(.caption.weight(.bold)).padding(.horizontal, Spacing.s).padding(.vertical, 2)
                        .overlay(Capsule().stroke(Tokens.textSecondary.color))
                }
                if shot.isSynthetic {
                    DemoBadge()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                valueText(.ballSpeed)
                valueText(.carry)
            }
            .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(shot.included ? Tokens.textPrimary.color : Tokens.textSecondary.color)
        .frame(minHeight: Spacing.minTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "Ball speed   162,4 km/h · Measured" or "Carry   Unavailable". One metric per line so nothing wraps mid-word.
    private func valueText(_ key: MetricKey) -> some View {
        let metric = shot.metrics[key]
        let usable = metric.flatMap { $0.provenance == .unavailable ? nil : $0.value }
        return HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(key.titleKey).frame(minWidth: 96, alignment: .leading)
            if let formatted = formatter.format(usable, for: key), let metric {
                Text(verbatim: formatted.text)
                Text(verbatim: "·")
                Text(metric.provenance.titleKey)
            } else {
                Text("provenance.unavailable")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// The two permanent-delete confirmations of a session screen. Nothing is deleted until the person confirms.
private struct DeletionDialogs: ViewModifier {
    let sessionID: UUID
    @Binding var shotToDelete: UUID?
    @Binding var confirmSessionDelete: Bool
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text("delete.shot.title"), isPresented: Binding(get: { shotToDelete != nil }, set: {
                    if !$0 {
                        shotToDelete = nil
                    }
                }),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let id = shotToDelete {
                        Task { await history.deleteShot(id) }
                    }
                    shotToDelete = nil
                } label: { Text("delete.confirm") }
                Button(role: .cancel) { shotToDelete = nil } label: { Text("common.cancel") }
            } message: { Text("delete.shot.message") }
            .confirmationDialog(Text("delete.session.title"), isPresented: $confirmSessionDelete, titleVisibility: .visible) {
                Button(role: .destructive) {
                    Task {
                        if await history.deleteSession(sessionID) {
                            dismiss()
                        }
                    }
                } label: { Text("delete.confirm") }
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: { Text("delete.session.message") }
    }
}
