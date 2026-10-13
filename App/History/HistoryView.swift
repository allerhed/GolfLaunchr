import Analytics
import Domain
import Formatting
import SwiftUI

/// Where a tap on a session leads. Stored in the shell's navigation state so rotation keeps the selection.
struct SessionRoute: Hashable {
    let id: UUID
}

/// The Progress tab (mockup 08): Sessions and Trends. Trends are a later feature.
struct ProgressScreen: View {
    @SwiftUI.Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        VStack(spacing: Spacing.s) {
            Picker(selection: $navigation.progressSection) {
                Text("progress.sessions", comment: "Progress tab segment: session history").tag(ProgressSection.sessions)
                Text("progress.analysis", comment: "Progress tab segment: club averages, gapping and dispersion")
                    .tag(ProgressSection.analysis)
                Text("progress.trends", comment: "Progress tab segment: trends (not built yet)").tag(ProgressSection.trends)
            } label: { Text("progress.sessions") }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.m)
                .accessibilityIdentifier("progress.section")
            switch navigation.progressSection {
            case .sessions: HistoryView()
            case .analysis: AnalysisView()
            case .trends: PlaceholderView(symbol: "chart.line.uptrend.xyaxis", message: "progress.placeholder")
            }
        }
    }
}

struct HistoryView: View {
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(\.locale) private var locale

    var body: some View {
        switch history.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label { Text("history.loadError") } icon: { Image(systemName: "exclamationmark.triangle") }
            }
            .accessibilityIdentifier("history.loadError")
        case .loaded:
            loaded
        }
    }

    private var loaded: some View {
        @Bindable var history = history
        return VStack(spacing: Spacing.s) {
            filters
            if history.summaries.isEmpty {
                ContentUnavailableView {
                    Label { Text("history.empty") } icon: { Image(systemName: "figure.golf") }
                }
                .accessibilityIdentifier("history.empty")
            } else if history.visible.isEmpty {
                ContentUnavailableView {
                    Label { Text("history.noMatches") } icon: { Image(systemName: "line.3.horizontal.decrease.circle") }
                } actions: {
                    Button { history.clearFilters() } label: { Text("history.filter.clear") }
                        .frame(minHeight: Spacing.minTarget)
                        .accessibilityIdentifier("history.clear")
                }
                .accessibilityIdentifier("history.noMatches")
            } else {
                List(history.visible) { summary in
                    NavigationLink(value: SessionRoute(id: summary.sessionID)) { SessionRow(summary: summary) }
                        .listRowBackground(Tokens.surface.color)
                        .accessibilityIdentifier("history.row.\(summary.sessionID.uuidString)")
                }
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("history.list")
            }
        }
    }

    private var filters: some View {
        @Bindable var history = history
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                chip(id: "history.filter.range", active: history.filter.range != .allTime) {
                    Picker(selection: $history.filter.range) {
                        ForEach(TimeRange.allCases, id: \.self) { Text($0.titleKey).tag($0) }
                    } label: { Text("history.range.allTime") }
                } label: { Text(history.filter.range.titleKey) }
                chip(id: "history.filter.mode", active: history.filter.mode != nil) {
                    Picker(selection: $history.filter.mode) {
                        Text("history.mode.all").tag(ShotMode?.none)
                        ForEach(history.modeOptions, id: \.self) { Text($0.titleKey).tag(Optional($0)) }
                    } label: { Text("history.mode.all") }
                } label: {
                    if let mode = history.filter.mode {
                        Text(mode.titleKey)
                    } else {
                        Text("history.mode.all")
                    }
                }
                chip(id: "history.filter.club", active: history.filter.clubID != nil) {
                    Picker(selection: $history.filter.clubID) {
                        Text("history.club.all").tag(UUID?.none)
                        ForEach(history.clubOptions, id: \.id) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                    } label: { Text("history.club.all") }
                } label: {
                    if let id = history.filter.clubID, let club = history.clubOptions.first(where: { $0.id == id }) {
                        Text(verbatim: club.name)
                    } else {
                        Text("history.club.all")
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
        }
    }

    /// A pill-shaped menu. A filtered state is shown with a filled pill and an explicit label, not colour alone.
    private func chip(
        id: String,
        active: Bool,
        @ViewBuilder content: () -> some View,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: Spacing.xs) {
                label()
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(active ? .bold : .regular))
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Spacing.minTarget)
            .foregroundStyle(active ? Tokens.onAccent.color : Tokens.textPrimary.color)
            .background(active ? Tokens.accent.color : Tokens.surface.color, in: Capsule())
        }
        .accessibilityIdentifier(id)
    }
}

struct SessionRow: View {
    let summary: SessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(summary.mode.titleKey).font(.headline).foregroundStyle(Tokens.textPrimary.color)
                if summary.containsDemoData {
                    DemoBadge()
                }
            }
            when.font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
            what.font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
        }
        .frame(minHeight: Spacing.minTarget)
        .accessibilityElement(children: .combine)
    }

    /// "Sat, 10 Oct 2026 at 13:19 · 32 min" in the user's local time zone (storage is UTC).
    private var when: Text {
        let date = Text(summary.startedAt, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
        guard let duration = summary.duration else { return date }
        return date + Text(verbatim: " · ") + Text(
            Duration.seconds(duration),
            format: .units(allowed: [.hours, .minutes], width: .abbreviated)
        )
    }

    /// "7 iron and PW · 6 shots · 1 excluded"
    private var what: Text {
        var parts: [Text] = []
        if !summary.clubs.isEmpty {
            parts.append(Text(verbatim: ListFormatter.localizedString(byJoining: summary.clubs.map(\.name))))
        }
        parts.append(Text("history.shotCount \(summary.shotCount)"))
        if summary.excludedCount > 0 {
            parts.append(Text("history.excludedCount \(summary.excludedCount)"))
        }
        return parts.dropFirst().reduce(parts.first ?? Text(verbatim: "")) { $0 + Text(verbatim: " · ") + $1 }
    }
}

/// Fixture/demo data is always labelled (spec F24).
struct DemoBadge: View {
    var body: some View {
        Text("history.demo", comment: "Badge on sessions and shots made of demo data, not real recordings")
            .font(.caption.weight(.bold))
            .padding(.horizontal, Spacing.s).padding(.vertical, 2)
            .foregroundStyle(Tokens.onAccent.color)
            .background(Tokens.accent.color, in: Capsule())
            .accessibilityIdentifier("history.demoBadge")
    }
}
