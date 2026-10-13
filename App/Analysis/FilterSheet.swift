import Analytics
import Domain
import SwiftUI

/// The multi-club filter (F10a): choose clubs, range, mode, inclusion, distance and conditions in a draft, then Apply or Cancel.
struct FilterSheet: View {
    @SwiftUI.Environment(AnalysisStore.self) private var store
    @SwiftUI.Environment(\.locale) private var locale

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Toggle("analysis.chip.allClubs", isOn: Binding(
                        get: { store.editor.draft.clubs == .all },
                        set: { on in store.editor.draft.clubs = on ? .all : .some([]) }
                    ))
                    .accessibilityIdentifier("filter.allClubs")
                    ForEach(Array(store.clubOptions.enumerated()), id: \.element.id) { index, club in
                        Button { store.editor.draft.clubs = clubChoice(toggling: club.id) } label: {
                            HStack(spacing: Spacing.m) {
                                ClubAvatar(name: club.name, style: store.style(for: club.id))
                                Text(verbatim: club.name).foregroundStyle(Tokens.textPrimary.color)
                                Spacer()
                                Image(systemName: isOn(club.id) ? "checkmark.square.fill" : "square").foregroundStyle(Tokens.accent.color)
                            }
                            .frame(minHeight: Spacing.minTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn(club.id) ? .isSelected : [])
                        .accessibilityIdentifier("filter.club.\(index)")
                    }
                } header: {
                    Text("analysis.filter.subtitle").foregroundStyle(Tokens.textSecondary.color)
                } footer: {
                    if !store.editor.draft.canApply {
                        Text("analysis.filter.empty").foregroundStyle(Tokens.textPrimary.color)
                    }
                }
                .listRowBackground(Tokens.surface.color)
                Section {
                    Picker("analysis.filter.range", selection: $store.editor.draft.range) {
                        ForEach(TimeRange.allCases, id: \.rawValue) { Text($0.titleKey).tag($0) }
                    }
                    Picker("analysis.filter.mode", selection: $store.editor.draft.mode) {
                        Text("history.mode.all").tag(ShotMode?.none)
                        ForEach(ShotMode.allCases, id: \.rawValue) { Text($0.titleKey).tag(ShotMode?.some($0)) }
                    }
                    Picker("analysis.filter.inclusion", selection: $store.editor.draft.inclusion) {
                        ForEach(InclusionState.allCases, id: \.rawValue) { Text($0.titleKey).tag($0) }
                    }
                }
                .listRowBackground(Tokens.surface.color)
                Section {
                    Picker("analysis.filter.distance", selection: $store.editor.draft.distance) {
                        ForEach(DistanceKind.allCases, id: \.rawValue) { Text($0.titleKey).tag($0) }
                    }
                    .adaptiveSegmented()
                    .accessibilityIdentifier("filter.distance")
                    Picker("analysis.filter.conditions", selection: $store.editor.draft.conditions) {
                        ForEach(ConditionsView.allCases, id: \.rawValue) { Text($0.titleKey).tag($0) }
                    }
                    .adaptiveSegmented()
                    .accessibilityIdentifier("filter.conditions")
                } footer: {
                    if store.editor.draft.conditions == .standardised {
                        Text("analysis.standardised.note")
                    }
                }
                .listRowBackground(Tokens.surface.color)
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.background.color)
            .navigationTitle(Text("analysis.filter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.cancelFilter() } label: { Text("common.cancel") }.accessibilityIdentifier("filter.cancel")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button { store.clearDraft() } label: { Text("analysis.filter.clear") }.accessibilityIdentifier("filter.clear")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { store.applyFilter() } label: { Text("analysis.filter.apply") }
                        .disabled(!store.editor.draft.canApply)
                        .accessibilityIdentifier("filter.apply")
                }
            }
        }
        .tint(Tokens.accent.color)
        .accessibilityIdentifier("filter.root")
    }

    private func isOn(_ id: UUID) -> Bool {
        store.editor.draft.clubs == .all || store.editor.draft.clubs.contains(id)
    }

    /// Choosing a club while "All clubs" is on starts a specific selection; tapping the last chosen club leaves it empty (visible).
    private func clubChoice(toggling id: UUID) -> ClubSelection {
        if store.editor.draft.clubs == .all {
            return .some([id])
        }
        return store.editor.draft.clubs.toggling(id)
    }
}
