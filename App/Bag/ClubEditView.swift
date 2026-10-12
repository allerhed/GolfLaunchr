import Domain
import SwiftUI

/// New club / edit club. The draft lives in `BagStore`, so rotating the phone does not lose what was typed.
struct ClubEditView: View {
    @SwiftUI.Environment(BagStore.self) private var store
    @SwiftUI.Environment(\.locale) private var locale

    private var draft: Binding<ClubDraft> {
        // The setter ignores writes when there is no draft: while the sheet is dismissing after a save, a field losing focus
        // writes its empty value back, which must not resurrect the draft and reopen the editor.
        Binding(get: { store.draft ?? ClubDraft() }, set: { ClubEditBindingRule.write($0, into: store) })
    }

    /// A row with a visible label, so a filled-in field is never an unlabelled value.
    private func labelled(_ label: LocalizedStringKey, text: Binding<String>, id: String, decimal: Bool = false) -> some View {
        LabeledContent {
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(decimal ? .decimalPad : .default)
                .accessibilityIdentifier(id)
        } label: {
            Text(label)
        }
    }

    var body: some View {
        let current = draft.wrappedValue
        let problem = store.validation(of: current, locale: locale)
        NavigationStack {
            Form {
                Section {
                    labelled("clubEdit.name", text: draft.name, id: "clubEdit.name")
                    Picker(selection: draft.category) {
                        ForEach(ClubCategory.allCases, id: \.self) { Text($0.titleKey).tag($0) }
                    } label: { Text("clubEdit.category", comment: "Field label: club category") }
                        .accessibilityIdentifier("clubEdit.category")
                    labelled("clubEdit.loft", text: draft.loftText, id: "clubEdit.loft", decimal: true)
                    labelled("clubEdit.brand", text: draft.brand, id: "clubEdit.brand")
                    labelled("clubEdit.model", text: draft.model, id: "clubEdit.model")
                } footer: {
                    if let problem, !current.isPristine {
                        Text(problem.messageKey).foregroundStyle(Tokens.textPrimary.color).accessibilityIdentifier("clubEdit.error")
                    } else if case let .some(failure) = store.lastError {
                        Text(failure.messageKey).foregroundStyle(Tokens.textPrimary.color).accessibilityIdentifier("clubEdit.error")
                    } else {
                        Text("clubEdit.loft.hint", comment: "Hint under the loft field").accessibilityIdentifier("clubEdit.hint")
                    }
                }
                .listRowBackground(Tokens.surface.color)
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.background.color)
            .navigationTitle(Text(current.editingID == nil ? "clubEdit.title.new" : "clubEdit.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { store.cancelDraft() } label: { Text("clubEdit.cancel") }
                        .frame(minHeight: Spacing.minTarget).accessibilityIdentifier("clubEdit.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await store.saveDraft(locale: locale) } } label: { Text("clubEdit.save") }
                        .disabled(problem != nil)
                        .frame(minHeight: Spacing.minTarget)
                        .accessibilityIdentifier("clubEdit.save")
                }
            }
        }
        .accessibilityIdentifier("clubEdit.root")
    }
}

/// The one rule for writing the editor's fields back to the store (see the comment in `ClubEditView.draft`).
enum ClubEditBindingRule {
    @MainActor
    static func write(_ value: ClubDraft, into store: BagStore) {
        if store.draft != nil {
            store.draft = value
        }
    }
}
