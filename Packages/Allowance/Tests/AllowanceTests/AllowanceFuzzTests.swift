@testable import Allowance
import Domain
import Foundation
import Testing

/// Milestone QA (6.7): random timelines with clock jumps forward and backward. Whatever the sequence, the free grants never exceed
/// what the rules allow, and a rolled-back clock never reopens an earlier period.
struct AllowanceFuzzTests {
    struct Lcg: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    static let zone = "Europe/Stockholm"
    static let start = Date(timeIntervalSince1970: 1_791_716_400)

    func monthIndex(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: Self.zone) ?? .gmt
        let c = cal.dateComponents([.year, .month], from: date)
        return (c.year ?? 0) * 12 + (c.month ?? 0)
    }

    @Test(arguments: [1, 2, 3, 7, 42, 99, 2026, 31337]) func randomTimelinesNeverExceedTheRules(seed: UInt64) throws {
        var rng = Lcg(state: seed)
        var state = AllowanceState(activatedAt: Self.start, timeZoneID: Self.zone, latestSeen: Self.start)
        var entries: [LedgerEntry] = []
        var device = Self.start
        var maxDevice = Self.start
        var lastMonthlyPeriod = ""
        var exhaustedMonth: Int?
        for _ in 0 ..< 1500 {
            switch Int.random(in: 0 ..< 10, using: &rng) {
            case 0: device = device.addingTimeInterval(-Double(Int.random(in: 0 ... 90, using: &rng)) * 86400) // rollback
            case 1, 2: device = device.addingTimeInterval(Double(Int.random(in: 0 ... 45, using: &rng)) * 86400) // forward
            default: device = device.addingTimeInterval(Double(Int.random(in: 0 ... 7200, using: &rng)))
            }
            maxDevice = max(maxDevice, device)
            state.observe(device)
            guard case let .allowed(reservation) = AllowanceEngine.decide(entries: entries, state: state, entitlement: nil, now: device)
            else { continue }
            let entry = try AllowanceEngine.settle(reservation, shotID: UUID(), committedAt: device)
            entries.append(entry)
            if reservation.kind == .monthly {
                let period = try #require(reservation.periodID)
                #expect(period >= lastMonthlyPeriod, "a rolled-back clock reopened an earlier period: \(period) after \(lastMonthlyPeriod)")
                lastMonthlyPeriod = period
            }
            if exhaustedMonth == nil, entries.filter({ $0.allowanceKind == .introductory }).count == AllowanceEngine.introTotal {
                exhaustedMonth = monthIndex(AllowanceEngine.effectiveNow(device, state: state, entries: entries))
            }
        }
        let intro = entries.filter { $0.allowanceKind == .introductory }.reduce(0) { $0 + $1.creditCost }
        #expect(intro <= AllowanceEngine.introTotal)
        let monthly = entries.filter { $0.allowanceKind == .monthly }
        for period in Set(monthly.compactMap(\.periodID)) {
            let spent = monthly.filter { $0.periodID == period }.reduce(0) { $0 + $1.creditCost }
            #expect(spent <= AllowanceEngine.monthlyTotal, "period \(period) granted \(spent)")
        }
        if let exhaustedMonth {
            let monthsAvailable = max(0, monthIndex(maxDevice) - exhaustedMonth)
            #expect(monthly.count <= monthsAvailable * AllowanceEngine.monthlyTotal, "more monthly shots than months that elapsed")
        } else {
            #expect(monthly.isEmpty, "monthly grants before the introduction ran out")
        }
    }

    @Test func aClockSetTenYearsForwardThenBackStillGivesNothingExtra() throws {
        var state = AllowanceState(activatedAt: Self.start, timeZoneID: Self.zone, latestSeen: Self.start)
        let intro = try (0 ..< 50).map { _ in
            try LedgerEntry(acceptedShotID: UUID(), allowanceKind: .introductory, periodID: "intro", creditCost: 1, committedAt: Self.start)
        }
        let far = Self.start.addingTimeInterval(3650 * 86400)
        state.observe(far)
        guard case let .allowed(r) = AllowanceEngine.decide(entries: intro, state: state, entitlement: nil, now: far) else {
            Issue.record("the far-future month should be granted once")
            return
        }
        let spent = try (0 ..< 10).map { _ in try AllowanceEngine.settle(r, shotID: UUID(), committedAt: far) }
        let after = AllowanceEngine.decide(
            entries: intro + spent,
            state: state,
            entitlement: nil,
            now: Self.start.addingTimeInterval(86400)
        )
        if case .allowed = after {
            Issue.record("setting the clock back must not open another grant")
        }
    }
}
