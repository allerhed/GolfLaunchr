import Export
import SwiftUI

/// Settings -> your data (F21): what stays on the iPhone, export, delete everything (with export first), delete media only, and the
/// diagnostic bundle with a preview. Nothing is uploaded; sharing is always the golfer's own choice in the system share sheet.
struct PrivacyDataSection: View {
    @SwiftUI.Environment(PrivacyStore.self) private var privacy
    @State private var showingDelete = false
    @State private var confirmingMedia = false
    @State private var showingDiagnostics = false

    var body: some View {
        Section {
            Label { Text("settings.privacy.text") } icon: { Image(systemName: "lock.iphone") }
                .accessibilityIdentifier("settings.privacy.text")
                // Presentations hang on ONE row: on the Section they would apply to every row.
                .sheet(isPresented: $showingDelete) { DeleteDataSheet() }
                .sheet(isPresented: $showingDiagnostics) { DiagnosticsSheet() }
                .confirmationDialog("privacy.media.title", isPresented: $confirmingMedia, titleVisibility: .visible) {
                    Button(role: .destructive) { Task { await privacy.deleteMediaOnly() } } label: { Text("privacy.media.confirm") }
                        .accessibilityIdentifier("settings.deleteMedia.confirm")
                    Button(role: .cancel) {} label: { Text("privacy.delete.cancel") }
                } message: {
                    Text("privacy.media.text")
                }
            exportRow(.json, title: "privacy.export.json", id: "settings.export.json")
            exportRow(.csv, title: "privacy.export.csv", id: "settings.export.csv")
            exportStatus
            Button { showingDiagnostics = true } label: {
                Text("privacy.diagnostics.start").frame(minHeight: Spacing.minTarget, alignment: .leading)
            }
            .accessibilityIdentifier("settings.diagnostics")
            Button { confirmingMedia = true } label: {
                Text("privacy.media.start").frame(minHeight: Spacing.minTarget, alignment: .leading)
            }
            .accessibilityIdentifier("settings.deleteMedia")
            mediaStatus
            Button(role: .destructive) {
                privacy.resetStatuses()
                showingDelete = true
            } label: {
                Text("privacy.delete.start").frame(minHeight: Spacing.minTarget, alignment: .leading)
            }
            .accessibilityIdentifier("settings.deleteAll")
            if privacy.deletion == .done {
                Text("privacy.delete.done").accessibilityIdentifier("settings.deleteAll.status")
            }
        } header: {
            Text("settings.privacy", comment: "Section header: privacy").foregroundStyle(Tokens.textSecondary.color)
        }
        .listRowBackground(Tokens.surface.color)
    }

    private func exportRow(_ format: ExportFormat, title: LocalizedStringKey, id: String) -> some View {
        Button { Task { await privacy.prepareExport(format) } } label: {
            Text(title).frame(minHeight: Spacing.minTarget, alignment: .leading)
        }
        .disabled(privacy.export == .working)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var exportStatus: some View {
        switch privacy.export {
        case .working: Text("privacy.export.preparing").accessibilityIdentifier("settings.export.status")
        case .failed: Text("privacy.export.failed").accessibilityIdentifier("settings.export.status")
        case .done:
            if let file = privacy.exportFile {
                ShareLink(item: file) { Label { Text("privacy.export.share") } icon: { Image(systemName: "square.and.arrow.up") } }
                    .accessibilityIdentifier("settings.export.share")
            }
        case .idle: EmptyView()
        }
    }

    @ViewBuilder
    private var mediaStatus: some View {
        switch privacy.mediaDeletion {
        case .done:
            Text(privacy.mediaFilesRemoved > 0 ? "privacy.media.done" : "privacy.media.none")
                .accessibilityIdentifier("settings.deleteMedia.status")
        case .failed: Text("privacy.media.failed").accessibilityIdentifier("settings.deleteMedia.status")
        default: EmptyView()
        }
    }
}

/// The full explanation before anything is deleted, with export first and a clear statement of what is and is not affected.
struct DeleteDataSheet: View {
    @SwiftUI.Environment(PrivacyStore.self) private var privacy
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("privacy.delete.title").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text("privacy.delete.removes").accessibilityIdentifier("delete.removes")
                    Label { Text("privacy.delete.keeps") } icon: { Image(systemName: "info.circle") }
                        .foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("delete.keeps")
                    Button { Task { await privacy.prepareExport(.json) } } label: {
                        Text("privacy.delete.exportFirst").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(privacy.export == .working)
                    .accessibilityIdentifier("delete.exportFirst")
                    if privacy.export == .done, let file = privacy.exportFile {
                        ShareLink(item: file) { Label { Text("privacy.export.share") } icon: { Image(systemName: "square.and.arrow.up") } }
                            .accessibilityIdentifier("delete.share")
                    }
                    if privacy.export == .failed {
                        Text("privacy.export.failed")
                    }
                    Button(role: .destructive) {
                        Task {
                            await privacy.deleteAllPracticeData()
                            if privacy.deletion == .done {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("privacy.delete.confirm").frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(privacy.deletion == .working)
                    .accessibilityIdentifier("delete.confirm")
                    if privacy.deletion == .failed {
                        Text("privacy.delete.failed").accessibilityIdentifier("delete.failed")
                    }
                }
                .padding(Spacing.m)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("privacy.delete.cancel") }.accessibilityIdentifier("delete.cancel")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Shows exactly what would be shared before it can be shared.
struct DiagnosticsSheet: View {
    @SwiftUI.Environment(PrivacyStore.self) private var privacy
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("privacy.diagnostics.title").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text("privacy.diagnostics.note").foregroundStyle(Tokens.textSecondary.color)
                    if let report = privacy.diagnostics {
                        Text(verbatim: report.text)
                            .font(.footnote.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.m)
                            .background(Tokens.surface.color, in: RoundedRectangle(cornerRadius: Spacing.cornerRadius, style: .continuous))
                            .textSelection(.enabled)
                            .accessibilityIdentifier("diagnostics.text")
                        ShareLink(item: report.text) {
                            Label { Text("privacy.diagnostics.share") } icon: { Image(systemName: "square.and.arrow.up") }
                        }
                        .accessibilityIdentifier("diagnostics.share")
                    } else if privacy.diagnosticsFailed {
                        Text("privacy.diagnostics.failed").accessibilityIdentifier("diagnostics.failed")
                    } else {
                        ProgressView()
                    }
                }
                .padding(Spacing.m)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("settings.done") }.accessibilityIdentifier("diagnostics.done")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await privacy.buildDiagnostics() }
    }
}
