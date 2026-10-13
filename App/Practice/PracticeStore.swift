import Domain
import Foundation
import Modes
import Observation
import Persistence

/// One running practice session (Standard Practice or QuickShot): the pure state plus its storage. Nothing here talks to the camera;
/// accepted shots arrive through `commit`, from the production pipeline later or from the Debug-only demo path now.
@MainActor @Observable
final class PracticeStore {
    private(set) var state: PracticeState
    let session: Session
    let clubs: [Club]
    private(set) var lastError: String?
    private(set) var isEnding = false
    private(set) var didEnd = false
    private(set) var endedWithShots = 0

    private let lifecycle: SessionLifecycle
    let backend: any PersistenceStore
    private let settings: SettingsStore
    private let now: () -> Date
    let voice: VoiceController?

    private init(
        state: PracticeState,
        session: Session,
        clubs: [Club],
        lifecycle: SessionLifecycle,
        backend: any PersistenceStore,
        settings: SettingsStore,
        voice: VoiceController?,
        now: @escaping () -> Date
    ) {
        self.state = state
        self.session = session
        self.clubs = clubs
        self.lifecycle = lifecycle
        self.backend = backend
        self.settings = settings
        self.voice = voice
        self.now = now
    }

    /// Starts and saves a session. QuickShot starts from the last-used club (or the first club); Standard Practice from the same, but
    /// both can switch freely. Returns nil if storage is unavailable or the bag is empty.
    static func start(
        _ mode: PracticeMode,
        bag: Bag,
        settings: SettingsStore,
        backend: any PersistenceStore,
        voice: VoiceController? = nil,
        now: @escaping () -> Date = Date.init
    ) async -> PracticeStore? {
        let clubs = bag.active
        let lifecycle = SessionLifecycle(sessions: backend, shots: backend)
        guard let session = try? await lifecycle.start(mode, now: now()) else { return nil }
        let initial = clubs.first { $0.id == settings.lastClubID } ?? clubs.first
        let state = PracticeState(sessionID: session.id, mode: mode, selectedClub: try? initial?.snapshot())
        return PracticeStore(
            state: state, session: session, clubs: clubs, lifecycle: lifecycle, backend: backend, settings: settings, voice: voice, now: now
        )
    }

    var selectedClubID: UUID? {
        state.selectedClub?.id
    }

    var latestShot: Shot? {
        state.shots.last
    }

    func selectClub(_ club: Club) {
        guard let snapshot = try? club.snapshot() else { return }
        state.selectClub(snapshot)
        settings.lastClubID = club.id
    }

    @discardableResult
    func arm(setupReady: Bool, allowanceAvailable: Bool = true) -> ArmResult {
        let result = state.arm(setupReady: setupReady, allowanceAvailable: allowanceAvailable)
        if result == .armed {
            voice?.prompt(.ready) // spoken now, then nothing new starts until the shot is accepted
            voice?.hold()
        }
        return result
    }

    func togglePause() {
        if state.status == .paused {
            state.resume()
        } else {
            state.pause()
            voice?.stop() // pausing disarms: nothing is spoken or held
        }
    }

    /// Commits an accepted shot and its ledger entry in one transaction, then records it in the session state.
    func commit(_ shot: Shot, ledger: LedgerEntry) async -> Bool {
        guard state.isArmed else { return false }
        do {
            _ = try await backend.commitAccepted(shot, ledger: ledger)
            let accepted = state.accept(shot) == .accepted
            if accepted {
                voice?.announce(shot)
            }
            return accepted
        } catch {
            lastError = "\(error)"
            return false
        }
    }

    /// Ends the session once. A second call (double tap, or while the first is still saving) does nothing.
    func end() async -> Bool {
        guard !isEnding, !didEnd else { return false }
        voice?.stop()
        isEnding = true
        defer { isEnding = false }
        // If saving failed the first time the state is already ended; a retry only repeats the save.
        if state.status != .ended {
            guard case let .ended(count) = state.end() else { return false }
            endedWithShots = count
        }
        do {
            _ = try await lifecycle.finish(session.id, shotCount: endedWithShots, now: now())
            didEnd = true
            return true
        } catch {
            lastError = "\(error)"
            return false
        }
    }
}
