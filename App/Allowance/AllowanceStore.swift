import Allowance
import Domain
import Foundation
import Observation
import Persistence

/// What the golfer may still do for free (F19), computed from the usage ledger and the device-local allowance state. The
/// subscription entitlement comes from the commerce store; without one everyone is on the free allowance.
@MainActor @Observable
final class AllowanceStore {
    private(set) var snapshot: AllowanceSnapshot?
    private(set) var loadFailed = false

    private let backend: (any LedgerRepository)?
    private let defaults: UserDefaults
    private let now: () -> Date
    /// The verified entitlement, from the commerce store; none until the first purchase or restore.
    var entitlement: () -> Entitlement? = { nil }
    private let zone: () -> TimeZone
    private var state: AllowanceState?
    /// Debug-only: ledger rows added in memory so UI tests can reach the exhausted state without 50 stored shots.
    var extraEntries: [LedgerEntry] = []
    static let stateKey = "allowance.state"

    init(
        backend: (any LedgerRepository)?,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        zone: @escaping () -> TimeZone = { .current }
    ) {
        self.backend = backend
        self.defaults = defaults
        self.now = now
        self.zone = zone
    }

    /// First launch fixes the reset time zone; later zone or language changes never move it.
    private func loadState() -> AllowanceState {
        if let state {
            return state
        }
        let current: AllowanceState = if let data = defaults.data(forKey: Self.stateKey), let saved = try? JSONDecoder().decode(
            AllowanceState.self,
            from: data
        ) {
            saved
        } else {
            AllowanceState(activatedAt: now(), timeZoneID: zone().identifier, latestSeen: now())
        }
        state = current
        return current
    }

    private func save(_ state: AllowanceState) {
        self.state = state
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }

    func refresh() async {
        guard let backend else {
            loadFailed = true
            return
        }
        do {
            let entries = try await backend.entries() + extraEntries
            var current = loadState()
            current.observe(now())
            save(current)
            snapshot = AllowanceEngine.snapshot(entries: entries, state: current, entitlement: entitlement(), now: now())
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    /// The reservation for the next shot, from the last refreshed balance. Nothing is granted before the ledger has been read.
    func decision(reserved: Int = 0) async -> ArmDecision? {
        guard let backend, let stored = try? await backend.entries() else { return nil }
        let entries = stored + extraEntries
        var current = loadState()
        current.observe(now())
        save(current)
        return AllowanceEngine.decide(entries: entries, state: current, entitlement: entitlement(), now: now(), reserved: reserved)
    }

    var canArm: Bool {
        guard let snapshot else { return false }
        return snapshot.isPro || snapshot.introRemaining > 0 || snapshot.monthlyRemaining > 0
    }
}
