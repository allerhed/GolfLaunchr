import Domain
import Foundation

/// F19 allowance rules as pure functions of the ledger, the persisted state, the entitlement and a clock.
/// 50 introductory shots; after exhaustion 10 free shots per calendar month from the FOLLOWING month, no rollover; a Pro
/// entitlement spends no free credit. The clock is never trusted backwards.
public enum AllowanceEngine {
    public static let introTotal = 50
    public static let monthlyTotal = 10
    public static let introPeriodID = "intro"

    // MARK: time

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal
    }

    static func periodID(_ date: Date, zone: TimeZone) -> String {
        let c = calendar(zone).dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static func startOfNextMonth(after date: Date, zone: TimeZone) -> Date? {
        let cal = calendar(zone)
        guard let start = cal.dateInterval(of: .month, for: date)?.start else { return nil }
        return cal.date(byAdding: .month, value: 1, to: start)
    }

    /// The clock the rules use: never earlier than anything already seen or committed on this device.
    static func effectiveNow(_ now: Date, state: AllowanceState, entries: [LedgerEntry]) -> Date {
        entries.reduce(max(now, state.latestSeen)) { max($0, $1.committedAt) }
    }

    // MARK: balance

    public static func snapshot(
        entries: [LedgerEntry], state: AllowanceState, entitlement: Entitlement?, now: Date, reserved: Int = 0
    ) -> AllowanceSnapshot {
        let zone = state.timeZone
        let clock = effectiveNow(now, state: state, entries: entries)
        let isPro = entitlement?.isActive(now: clock) == true
        let introEntries = entries.filter { $0.allowanceKind == .introductory }.sorted { $0.committedAt < $1.committedAt }
        let introSpent = introEntries.reduce(0) { $0 + $1.creditCost }
        var introLeft = max(0, introTotal - introSpent)
        var monthlyLeft = 0
        var monthlyID: String?
        var reset: Date?
        if introSpent >= introTotal {
            // Exhaustion time = the commit that reached 50.
            var running = 0
            var exhaustedAt = introEntries.last?.committedAt ?? clock
            for e in introEntries {
                running += e.creditCost
                if running >= introTotal {
                    exhaustedAt = e.committedAt
                    break
                }
            }
            let exhaustedPeriod = periodID(exhaustedAt, zone: zone)
            let current = periodID(clock, zone: zone)
            reset = startOfNextMonth(after: clock, zone: zone)
            if current > exhaustedPeriod {
                monthlyID = current
                let spent = entries.filter { $0.allowanceKind == .monthly && $0.periodID == current }.reduce(0) { $0 + $1.creditCost }
                monthlyLeft = max(0, monthlyTotal - spent)
            }
        }
        var held = reserved
        if held > 0, introLeft > 0 {
            let take = min(held, introLeft)
            introLeft -= take
            held -= take
        }
        if held > 0 {
            monthlyLeft = max(0, monthlyLeft - held)
        }
        return AllowanceSnapshot(
            introRemaining: introLeft, monthlyRemaining: monthlyLeft, monthlyPeriodID: monthlyID, nextReset: reset, isPro: isPro
        )
    }

    /// Reserves permission at arming. Pro spends nothing; otherwise introductory credits go first, then the monthly grant.
    public static func decide(
        entries: [LedgerEntry], state: AllowanceState, entitlement: Entitlement?, now: Date, reserved: Int = 0
    ) -> ArmDecision {
        let snap = snapshot(entries: entries, state: state, entitlement: entitlement, now: now, reserved: reserved)
        if snap.isPro, let entitlement {
            return .allowed(Reservation(kind: entitlement.kind, periodID: nil, cost: 0))
        }
        if snap.introRemaining > 0 {
            return .allowed(Reservation(kind: .introductory, periodID: introPeriodID, cost: 1))
        }
        if snap.monthlyRemaining > 0 {
            return .allowed(Reservation(kind: .monthly, periodID: snap.monthlyPeriodID, cost: 1))
        }
        return .blocked(nextReset: snap.nextReset)
    }

    /// Turns a reservation into the ledger row stored together with the shot. The same reservation and shot always give an
    /// equal row, so a retry after a crash settles once (the shot ID is the ledger key).
    public static func settle(_ reservation: Reservation, shotID: UUID, committedAt: Date) throws(ContractError) -> LedgerEntry {
        try LedgerEntry(
            acceptedShotID: shotID, allowanceKind: reservation.kind, periodID: reservation.periodID,
            creditCost: reservation.cost, committedAt: committedAt
        )
    }

    // MARK: features

    /// Basic practice, history, voice and replay stay free. Advanced analysis and the drills are open during the introduction and
    /// need Pro afterwards. Already saved analysis stays readable: the gate applies to computing new advanced results.
    public static func access(_ feature: Feature, snapshot: AllowanceSnapshot) -> FeatureAccess {
        switch feature {
        case .basicPractice, .history, .voice, .replay:
            .allowed
        case .dispersion, .clubMapping, .trends, .targetDrill, .ladderDrill, .virtualGolf:
            snapshot.isPro || snapshot.introRemaining > 0 ? .allowed : .requiresPro
        }
    }
}
