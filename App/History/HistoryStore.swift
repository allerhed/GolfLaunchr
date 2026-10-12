import Analytics
import Domain
import Foundation
import Observation
import Persistence

enum HistoryError: Equatable {
    /// The change could not be written; what is shown is the last saved state.
    case storageFailed
}

/// Sessions and their shots for the history screens (F10). Every number shown is recomputed from what is stored:
/// each change is written first, then the whole view is rebuilt from the database (so it can never drift from it).
@MainActor @Observable
final class HistoryStore {
    typealias Backend = LedgerRepository & SessionRepository & ShotRepository

    enum LoadState: Equatable {
        case idle, loaded
        case failed(String)
    }

    private(set) var summaries: [SessionSummary] = []
    private(set) var loadState = LoadState.idle
    private(set) var lastError: HistoryError?
    var filter = HistoryFilter()
    /// Shot shown in the detail sheet. Kept here so rotation (which rebuilds the shell) does not close it.
    var selectedShotID: UUID?

    private var shotsBySession: [UUID: [Shot]] = [:]
    private var loadTask: Task<Void, Never>?
    private let backend: (any Backend)?
    private let now: () -> Date
    private let prepare: (() async -> Void)?

    /// - Parameter prepare: runs once before the first load. Used only by debug builds to put demo data in a test database.
    init(
        backend: (any Backend)?,
        failureMessage: String? = nil,
        now: @escaping () -> Date = Date.init,
        prepare: (() async -> Void)? = nil
    ) {
        self.backend = backend
        self.now = now
        self.prepare = prepare
        if backend == nil {
            loadState = .failed(failureMessage ?? "No storage available")
        }
    }

    // MARK: reading

    var visible: [SessionSummary] {
        filter.apply(to: summaries, now: now())
    }

    var clubOptions: [ClubSnapshot] {
        HistoryFilter.clubOptions(from: summaries)
    }

    var modeOptions: [ShotMode] {
        ShotMode.allCases.filter { mode in summaries.contains { $0.mode == mode } }
    }

    func summary(_ id: UUID) -> SessionSummary? {
        summaries.first { $0.sessionID == id }
    }

    func shots(of sessionID: UUID) -> [Shot] {
        shotsBySession[sessionID] ?? []
    }

    func shot(_ id: UUID) -> Shot? {
        shotsBySession.values.lazy.flatMap(\.self).first { $0.id == id }
    }

    func clearFilters() {
        filter = HistoryFilter()
    }

    // MARK: loading and changes

    /// Loads once. Concurrent callers wait for the load already in flight instead of starting a second one: a second
    /// `prepare` + `reload` running while the first is still writing would read a half-written database.
    func load() async {
        guard let backend, loadState == .idle || isFailed else { return }
        if let running = loadTask {
            await running.value
            return
        }
        let task = Task { @MainActor in
            await self.prepare?()
            await self.reload(from: backend)
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Reads everything again from the database (after a session started, a shot was committed or a session ended elsewhere).
    func refresh() async {
        guard let backend else { return }
        await reload(from: backend)
    }

    private var isFailed: Bool {
        if case .failed = loadState {
            return true
        }
        return false
    }

    private func reload(from backend: any Backend) async {
        do {
            let sessions = try await backend.sessions()
            var bySession: [UUID: [Shot]] = [:]
            for session in sessions {
                bySession[session.id] = try await backend.shots(sessionID: session.id)
            }
            shotsBySession = bySession
            summaries = sessions.map { SessionSummaries.make(session: $0, shots: bySession[$0.id] ?? []) }
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }

    @discardableResult
    func setIncluded(_ shotID: UUID, _ included: Bool) async -> Bool {
        await change { try await $0.setIncluded(shotID: shotID, included: included) }
    }

    /// Permanent. The credit ledger entry is deliberately kept by the store.
    @discardableResult
    func deleteShot(_ shotID: UUID) async -> Bool {
        if selectedShotID == shotID {
            selectedShotID = nil
        }
        return await change { try await $0.deleteShot(id: shotID) }
    }

    /// Permanent: removes the session and its shots; the credit ledger is preserved by the store.
    @discardableResult
    func deleteSession(_ sessionID: UUID) async -> Bool {
        if let selected = selectedShotID, shots(of: sessionID).contains(where: { $0.id == selected }) {
            selectedShotID = nil
        }
        return await change { try await $0.deleteSession(id: sessionID) }
    }

    private func change(_ operation: (any Backend) async throws -> some Any) async -> Bool {
        guard let backend, loadState == .loaded else { return false }
        do {
            _ = try await operation(backend)
        } catch {
            lastError = .storageFailed
            return false
        }
        lastError = nil
        await reload(from: backend)
        return true
    }
}
