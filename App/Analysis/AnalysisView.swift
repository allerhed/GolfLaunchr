import Analytics
import Domain
import Formatting
import SwiftUI

struct ClubRoute: Hashable {
    let id: UUID
}

/// Progress -> Analysis (F10a): the shared filter chips, the scope, and one of Averages / Gapping / Dispersion over the same shots.
struct AnalysisView: View {
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(HistoryStore.self) private var history
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    var body: some View {
        @Bindable var store = store
        let result = store.result
        GeometryReader { geo in
            ScrollView {
                content(result, width: min(720, geo.size.width - 2 * Spacing.m))
                    .padding(Spacing.m)
                    .frame(width: geo.size.width)
            }
        }
        .background(Tokens.background.color)
        .sheet(isPresented: $store.showingFilter) {
            FilterSheet().environment(store).environment(settings)
        }
        .sheet(isPresented: Binding(get: { history.selectedShotID != nil }, set: {
            if !$0 {
                history.selectedShotID = nil
            }
        })) {
            ShotDetailView().environment(history).environment(settings).environment(store)
        }
        .navigationDestination(for: ClubRoute.self) { ClubProfileView(clubID: $0.id) }
    }

    /// The screen's content in a column of exactly `width`: a child that wants to be wider wraps or shrinks instead of shifting the page.
    private func content(_ result: AnalysisStore.Result, width: CGFloat) -> some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: Spacing.m) {
            chips(result)
            if store.applied.sessionIDs != nil {
                scopeNote
            }
            Picker(selection: $store.tab) {
                ForEach(AnalysisStore.Tab.allCases) { Text($0.titleKey).tag($0) }
            } label: { Text("progress.analysis") }
                .adaptiveSegmented()
                .accessibilityIdentifier("analysis.tab")
            if result.selection.shots.isEmpty {
                emptyNote
            } else {
                switch store.tab {
                case .averages: ClubAveragesView(result: result)
                case .gapping: GappingView(result: result)
                case .dispersion: DispersionView(result: result)
                }
            }
            if store.applied.conditions == .standardised {
                standardisedNote
            }
        }
        .frame(width: width, alignment: .leading)
    }

    // MARK: filter chips

    private func chips(_: AnalysisStore.Result) -> some View {
        WrappingChips {
            Group {
                Button { store.openFilter() } label: {
                    chipLabel(clubChipText, symbol: "figure.golf")
                }
                .accessibilityIdentifier("analysis.chip.clubs")
                Menu {
                    ForEach(DistanceKind.allCases, id: \.rawValue) { kind in
                        Button { store.update { $0.distance = kind } } label: {
                            if kind == store.applied.distance {
                                Label { Text(kind.titleKey) } icon: { Image(systemName: "checkmark") }
                            } else {
                                Text(kind.titleKey)
                            }
                        }
                    }
                } label: { chipLabel(Text(store.applied.distance.titleKey), symbol: "ruler") }
                    .accessibilityIdentifier("analysis.chip.distance")
                Menu {
                    ForEach(ConditionsView.allCases, id: \.rawValue) { view in
                        Button { store.update { $0.conditions = view } } label: {
                            if view == store.applied.conditions {
                                Label { Text(view.titleKey) } icon: { Image(systemName: "checkmark") }
                            } else {
                                Text(view.titleKey)
                            }
                        }
                    }
                } label: { chipLabel(Text(store.applied.conditions.titleKey), symbol: "cloud") }
                    .accessibilityIdentifier("analysis.chip.conditions")
            }
        }
    }

    private var clubChipText: Text {
        switch store.applied.clubs {
        case .all: Text("analysis.chip.allClubs")
        case let .some(ids): Text("analysis.chip.clubs \(ids.count)")
        }
    }

    private func chipLabel(_ text: Text, symbol: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol).accessibilityHidden(true)
            text.multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(minHeight: Spacing.minTarget)
        .foregroundStyle(Tokens.textPrimary.color)
        .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Tokens.textSecondary.color.opacity(0.3)))
    }

    private var scopeNote: some View {
        HStack {
            Label { Text("analysis.scope.session") } icon: { Image(systemName: "calendar") }
                .accessibilityIdentifier("analysis.scope")
            Spacer()
            Button { store.clearSessionScope() } label: { Text("analysis.scope.all").frame(minHeight: Spacing.minTarget) }
                .accessibilityIdentifier("analysis.scope.clear")
        }
        .font(.footnote)
    }

    private var emptyNote: some View {
        ContentUnavailableView {
            Label { Text("analysis.empty") } icon: { Image(systemName: "chart.dots.scatter") }
        }
        .accessibilityIdentifier("analysis.empty")
    }

    private var standardisedNote: some View {
        Label { Text("analysis.standardised.note") } icon: { Image(systemName: "info.circle") }
            .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
            .accessibilityIdentifier("analysis.standardised.note")
    }
}

/// Shared by the analysis screens: format a distance mean with its estimate label.
struct DistanceText: View {
    let metres: Double?
    let kind: DistanceKind
    let formatter: MetricFormatter
    var font: Font = Typography.metricNumeral

    var body: some View {
        if let formatted = formatter.format(metres, for: kind.key) {
            Text(verbatim: formatted.text).font(font).minimumScaleFactor(0.6).lineLimit(1)
        } else {
            Text("history.noData").font(.title3).foregroundStyle(Tokens.textSecondary.color)
        }
    }
}
