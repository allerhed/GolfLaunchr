import Domain
import SwiftUI

/// My Bag (F08, mockups 09/15). Per-club distances and the profile pane belong to F09/F10a and are not built here.
struct BagView: View {
    @SwiftUI.Environment(BagStore.self) private var store
    @SwiftUI.Environment(\.locale) private var locale

    var body: some View {
        @Bindable var store = store
        // Read inside body so this view updates when the draft is cleared: a binding closure alone is not observed.
        let isEditing = store.draft != nil
        content
            .toolbar {
                if store.loadState == .loaded {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton().frame(minHeight: Spacing.minTarget).accessibilityIdentifier("bag.edit")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { store.beginAdd() } label: {
                            Image(systemName: "plus").frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                        }
                        .accessibilityLabel(Text("bag.add", comment: "Button: add a club"))
                        .accessibilityIdentifier("bag.add")
                    }
                }
            }
            .sheet(isPresented: Binding(get: { store.draft != nil }, set: {
                if !$0 {
                    store.cancelDraft()
                }
            })) {
                ClubEditView().environment(store)
            }
    }

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .idle:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label { Text("bag.loadError") } icon: { Image(systemName: "exclamationmark.triangle") }
            }
            .accessibilityIdentifier("bag.loadError")
        case .loaded:
            list
        }
    }

    private var list: some View {
        @Bindable var store = store
        return List {
            if case .saveFailed = store.lastError, store.draft == nil {
                Text("bag.saveError", comment: "Shown when a change could not be saved")
                    .foregroundStyle(Tokens.textPrimary.color)
                    .accessibilityIdentifier("bag.error")
            } else if case let .validation(error) = store.lastError, store.draft == nil {
                Text(error.messageKey).foregroundStyle(Tokens.textPrimary.color).accessibilityIdentifier("bag.error")
            }
            Section {
                if store.bag.active.isEmpty {
                    Text("bag.empty", comment: "Empty state: no active clubs").foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("bag.emptyState")
                }
                ForEach(store.bag.active) { club in
                    row(club)
                        .swipeActions(edge: .trailing) {
                            Button { Task { await store.archive(club.id) } } label: { Text("bag.archive") }
                                .tint(Tokens.textSecondary.color)
                                .accessibilityIdentifier("bag.row.archive")
                        }
                }
                .onMove { source, destination in Task { await store.move(fromOffsets: source, toOffset: destination) } }
            }
            .listRowBackground(Tokens.surface.color)
            if !store.bag.archived.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $store.showsArchived) {
                        ForEach(store.bag.archived) { club in
                            row(club)
                                .swipeActions(edge: .trailing) {
                                    Button { Task { await store.restore(club.id) } } label: { Text("bag.restore") }
                                        .tint(Tokens.accent.color)
                                        .accessibilityIdentifier("bag.row.restore")
                                }
                        }
                    } label: {
                        Text("bag.archived", comment: "Section: archived clubs") + Text(verbatim: " (\(store.bag.archived.count))")
                    }
                    .accessibilityIdentifier("bag.archivedSection")
                }
                .listRowBackground(Tokens.surface.color)
            }
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("bag.list")
    }

    private func row(_ club: Club) -> some View {
        Button {
            if club.archivedAt == nil {
                store.beginEdit(club, locale: locale)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: club.name).font(.headline).foregroundStyle(Tokens.textPrimary.color)
                    detail(club).font(.subheadline).foregroundStyle(Tokens.textSecondary.color)
                }
                Spacer(minLength: Spacing.s)
                if club.archivedAt == nil {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Spacing.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bag.row.\(club.id.uuidString)")
    }

    /// "Iron" or "Iron · 34,5°" (loft only when the golfer set one: never a guessed stock loft).
    private func detail(_ club: Club) -> Text {
        let category = Text(club.category.titleKey)
        guard let rad = club.loftRad else { return category }
        return category + Text(verbatim: " · \(BagStore.loftText(radians: rad, locale: locale))°")
    }
}
