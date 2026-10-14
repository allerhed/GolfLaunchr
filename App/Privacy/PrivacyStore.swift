import Export
import Foundation
import Observation
import Persistence
import UIKit

/// F21 actions: export, delete everything, delete media only, diagnostic bundle. Nothing here talks to a network. Deleting
/// practice data keeps the usage ledger (disclosed in the confirmation) and never touches purchases.
@MainActor @Observable
final class PrivacyStore {
    enum Task: Equatable {
        case idle, working, done, failed
    }

    private(set) var export = Task.idle
    private(set) var exportFile: URL?
    private(set) var deletion = Task.idle
    private(set) var mediaDeletion = Task.idle
    private(set) var mediaFilesRemoved = 0
    private(set) var diagnostics: DiagnosticsReport?
    private(set) var diagnosticsFailed = false

    private let backend: (any PersistenceStore)?
    private let media: MediaDirectory?
    private let facts: @MainActor () -> DiagnosticsFacts
    private let afterDeletion: () async -> Void

    init(
        backend: (any PersistenceStore)?,
        media: MediaDirectory?,
        facts: @escaping @MainActor () -> DiagnosticsFacts = PrivacyStore.deviceFacts,
        afterDeletion: @escaping () async -> Void
    ) {
        self.backend = backend
        self.media = media
        self.facts = facts
        self.afterDeletion = afterDeletion
    }

    static func deviceFacts() -> DiagnosticsFacts {
        let info = Bundle.main.infoDictionary ?? [:]
        let free = (try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage
        return DiagnosticsFacts(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceClass: UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone",
            language: Locale.preferredLanguages.first ?? "unknown",
            storageFreeMegabytes: free.map { Int($0 / 1_000_000) }
        )
    }

    func prepareExport(_ format: ExportFormat) async {
        guard let backend else {
            export = .failed
            return
        }
        discardExport()
        export = .working
        do {
            exportFile = try await ExportService(sessions: backend, shots: backend).writeTemporary(format)
            export = .done
        } catch {
            export = .failed
        }
    }

    func discardExport() {
        if let exportFile {
            ExportService.discard(exportFile)
        }
        exportFile = nil
        export = .idle
    }

    /// All or nothing for the database; the screens are refreshed afterwards so nothing stale remains on screen.
    func deleteAllPracticeData() async {
        guard let backend, deletion != .working else {
            deletion = .failed
            return
        }
        deletion = .working
        do {
            _ = try await backend.deleteAllPracticeData()
            _ = try? media?.deleteAll()
            discardExport()
            await afterDeletion()
            deletion = .done
        } catch {
            deletion = .failed
        }
    }

    func deleteMediaOnly() async {
        guard let media, mediaDeletion != .working else {
            mediaDeletion = .failed
            return
        }
        mediaDeletion = .working
        do {
            mediaFilesRemoved = try media.deleteAll().files
            mediaDeletion = .done
        } catch {
            mediaDeletion = .failed
        }
    }

    func buildDiagnostics() async {
        guard let backend else {
            diagnosticsFailed = true
            return
        }
        do {
            diagnostics = try await DiagnosticsService(sessions: backend, shots: backend).report(facts: facts())
            diagnosticsFailed = false
        } catch {
            diagnostics = nil
            diagnosticsFailed = true
        }
    }

    func resetStatuses() {
        deletion = .idle
        mediaDeletion = .idle
    }
}
