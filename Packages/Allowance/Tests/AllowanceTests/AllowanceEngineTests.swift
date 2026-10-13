@testable import Allowance
import Domain
import Foundation
import Testing

/// F19 acceptance: introductory 49/50/51, monthly 9/10/11, no rollover, clock rollback, entitlement windows, reservations.
struct AllowanceEngineTests {
    static let stockholm = "Europe/Stockholm"
    static let start = date(2026, 10, 3, 12)

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, zone: String = stockholm) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone) ?? .gmt
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    static func state(zone: String = stockholm) -> AllowanceState {
        AllowanceState(activatedAt: start, timeZoneID: zone, latestSeen: start)
    }

    static func entry(_ kind: AllowanceKind, period: String?, cost: Int = 1, at: Date) -> LedgerEntry {
        // swiftlint:disable:next force_try
        try! LedgerEntry(acceptedShotID: UUID(), allowanceKind: kind, periodID: period, creditCost: cost, committedAt: at)
    }

    static func intro(_ count: Int, at: Date = start) -> [LedgerEntry] {
        (0 ..< count).map { _ in entry(.introductory, period: "intro", at: at) }
    }

    func decide(_ entries: [LedgerEntry], now: Date, entitlement: Entitlement? = nil, zone: String = stockholm) -> ArmDecision {
        AllowanceEngine.decide(entries: entries, state: Self.state(zone: zone), entitlement: entitlement, now: now)
    }

    // MARK: introductory 49 / 50 / 51

    @Test(arguments: [(49, 1), (0, 50), (25, 25)])
    func introRemaining(spent: Int, remaining: Int) {
        let snap = AllowanceEngine.snapshot(entries: Self.intro(spent), state: Self.state(), entitlement: nil, now: Self.start)
        #expect(snap.introRemaining == remaining)
    }

    @Test func the49thShotLeavesOneAndThe50thTheLast() {
        guard case let .allowed(r) = decide(Self.intro(49), now: Self.start) else { Issue.record("49 spent should still arm"); return }
        #expect(r.kind == .introductory && r.cost == 1)
        #expect(r.periodID == "intro")
    }

    @Test func afterThe50thShotTheNextCannotArm() {
        let result = decide(Self.intro(50), now: Self.start)
        guard case let .blocked(reset) = result else { Issue.record("51st must not arm: \(result)"); return }
        #expect(reset == Self.date(2026, 11, 1, 0))
    }

    @Test func overspentLedgerNeverGoesNegative() {
        let snap = AllowanceEngine.snapshot(entries: Self.intro(53), state: Self.state(), entitlement: nil, now: Self.start)
        #expect(snap.introRemaining == 0)
    }

    @Test func monthlyCreditsDoNotAccumulateBeforeIntroExhaustion() {
        let later = Self.date(2027, 3, 5)
        let snap = AllowanceEngine.snapshot(entries: Self.intro(10), state: Self.state(), entitlement: nil, now: later)
        #expect(snap.introRemaining == 40)
        #expect(snap.monthlyRemaining == 0)
        #expect(snap.nextReset == nil)
    }

    // MARK: monthly 9 / 10 / 11

    /// Introductory use ends on 3 October; the first monthly grant is 1 November.
    func exhausted() -> [LedgerEntry] {
        Self.intro(50, at: Self.start)
    }

    @Test func noMonthlyGrantInTheMonthOfExhaustion() {
        let r = decide(exhausted(), now: Self.date(2026, 10, 31, 23))
        if case .allowed = r {
            Issue.record("granted in the exhaustion month")
        }
    }

    @Test(arguments: [(9, 1), (10, 0), (0, 10)])
    func monthlyRemaining(spent: Int, remaining: Int) {
        let now = Self.date(2026, 11, 2)
        let used = (0 ..< spent).map { _ in Self.entry(.monthly, period: "2026-11", at: now) }
        let snap = AllowanceEngine.snapshot(entries: exhausted() + used, state: Self.state(), entitlement: nil, now: now)
        #expect(snap.monthlyRemaining == remaining)
        #expect(snap.monthlyPeriodID == "2026-11")
    }

    @Test func the10thMonthlyShotIsAllowedAndThe11thIsNot() {
        let now = Self.date(2026, 11, 2)
        let nine = (0 ..< 9).map { _ in Self.entry(.monthly, period: "2026-11", at: now) }
        guard case let .allowed(r) = decide(exhausted() + nine, now: now) else { Issue.record("10th should arm"); return }
        #expect(r.kind == .monthly && r.periodID == "2026-11")
        let ten = nine + [Self.entry(.monthly, period: "2026-11", at: now)]
        guard case let .blocked(reset) = decide(exhausted() + ten, now: now) else { Issue.record("11th must be blocked"); return }
        #expect(reset == Self.date(2026, 12, 1, 0))
    }

    @Test func unusedMonthlyCreditsExpireWithoutRollover() {
        let nov = Self.date(2026, 11, 2)
        let three = (0 ..< 3).map { _ in Self.entry(.monthly, period: "2026-11", at: nov) }
        let snap = AllowanceEngine.snapshot(
            entries: exhausted() + three,
            state: Self.state(),
            entitlement: nil,
            now: Self.date(2026, 12, 1, 0)
        )
        #expect(snap.monthlyRemaining == 10, "December starts at 10, not 17")
        #expect(snap.monthlyPeriodID == "2026-12")
    }

    @Test func resetIsIdempotent() {
        let now = Self.date(2026, 12, 15)
        let a = AllowanceEngine.snapshot(entries: exhausted(), state: Self.state(), entitlement: nil, now: now)
        let b = AllowanceEngine.snapshot(entries: exhausted(), state: Self.state(), entitlement: nil, now: now.addingTimeInterval(3600))
        #expect(a.monthlyRemaining == 10 && b.monthlyRemaining == 10)
    }

    @Test func yearBoundaryMovesToJanuary() {
        let r = decide(exhausted(), now: Self.date(2026, 12, 31, 23))
        guard case let .allowed(res) = r else { Issue.record("December grant expected"); return }
        #expect(res.periodID == "2026-12")
        let snap = AllowanceEngine.snapshot(entries: exhausted(), state: Self.state(), entitlement: nil, now: Self.date(2027, 1, 1, 0))
        #expect(snap.monthlyPeriodID == "2027-01")
        #expect(snap.nextReset == Self.date(2027, 2, 1, 0))
    }

    // MARK: time zone, language, clock

    @Test func periodUsesThePersistedZoneNotTheDeviceZone() {
        // 23:30 UTC on 31 Oct is already 1 Nov in Stockholm (UTC+1): Stockholm users get November credits.
        let utcLateOct = Date(timeIntervalSince1970: AllowanceEngineTests.date(2026, 10, 31, 23, zone: "UTC").timeIntervalSince1970)
        let stockholm = AllowanceEngine.snapshot(
            entries: exhausted(),
            state: Self.state(),
            entitlement: nil,
            now: utcLateOct.addingTimeInterval(1800)
        )
        #expect(stockholm.monthlyPeriodID == "2026-11")
        let la = AllowanceEngine.snapshot(
            entries: exhausted(), state: Self.state(zone: "America/Los_Angeles"), entitlement: nil, now: utcLateOct.addingTimeInterval(1800)
        )
        #expect(la.monthlyPeriodID == nil, "still October in the persisted Los Angeles zone")
    }

    @Test func clockRollbackNeverGrantsAnotherPeriod() {
        // The last ledger commit was in December; the clock is set back to November.
        let dec = Self.date(2026, 12, 3)
        let decUsed = (0 ..< 10).map { _ in Self.entry(.monthly, period: "2026-12", at: dec) }
        let r = decide(exhausted() + decUsed, now: Self.date(2026, 11, 20))
        if case .allowed = r {
            Issue.record("rolled-back clock created a free grant")
        }
        let snap = AllowanceEngine.snapshot(
            entries: exhausted() + decUsed,
            state: Self.state(),
            entitlement: nil,
            now: Self.date(2026, 11, 20)
        )
        #expect(snap.monthlyPeriodID == "2026-12")
    }

    @Test func clockRollbackIsRememberedAcrossLaunches() {
        var state = Self.state()
        state.observe(Self.date(2026, 12, 3))
        #expect(state.latestSeen == Self.date(2026, 12, 3))
        state.observe(Self.date(2026, 11, 1))
        #expect(state.latestSeen == Self.date(2026, 12, 3), "never moves backwards")
        let snap = AllowanceEngine.snapshot(entries: exhausted(), state: state, entitlement: nil, now: Self.date(2026, 11, 1))
        #expect(snap.monthlyPeriodID == "2026-12")
    }

    @Test func clockForwardCannotCreateMoreThanOneGrantPerCalendarMonth() {
        // Jump forward two months: one fresh period of 10, not 20 or 30.
        let snap = AllowanceEngine.snapshot(entries: exhausted(), state: Self.state(), entitlement: nil, now: Self.date(2027, 1, 10))
        #expect(snap.monthlyRemaining == 10)
    }

    // MARK: entitlement

    func ent(expires: Date, verified: Date, revoked: Bool = false, kind: AllowanceKind = .paid) -> Entitlement {
        Entitlement(kind: kind, expiresAt: expires, lastVerifiedAt: verified, revoked: revoked)
    }

    @Test func paidUseSpendsNoFreeCredit() {
        let now = Self.date(2026, 10, 10)
        let e = ent(expires: Self.date(2026, 11, 3), verified: now)
        guard case let .allowed(r) = decide(Self.intro(50), now: now, entitlement: e) else { Issue.record("Pro should arm"); return }
        #expect(r.kind == .paid && r.cost == 0)
    }

    @Test func purchaseDoesNotResetIntroUsage() {
        let now = Self.date(2026, 10, 10)
        let e = ent(expires: Self.date(2026, 11, 3), verified: now)
        let snap = AllowanceEngine.snapshot(entries: Self.intro(30), state: Self.state(), entitlement: e, now: now)
        #expect(snap.introRemaining == 20)
        #expect(snap.isPro)
    }

    @Test func offlineEntitlementWorksForSevenDaysThenStops() {
        let verified = Self.date(2026, 10, 10)
        let e = ent(expires: Self.date(2026, 12, 1), verified: verified)
        #expect(e.isActive(now: verified.addingTimeInterval(6 * 86400 + 3600)))
        #expect(!e.isActive(now: verified.addingTimeInterval(7 * 86400 + 1)))
    }

    @Test func entitlementIsCappedByKnownExpiryAndRevocationHasNoGrace() {
        let verified = Self.date(2026, 10, 10)
        let e = ent(expires: Self.date(2026, 10, 12), verified: verified)
        #expect(e.isActive(now: Self.date(2026, 10, 11)))
        #expect(!e.isActive(now: Self.date(2026, 10, 12, 13)), "past expiry, inside the revalidation window")
        let revoked = ent(expires: Self.date(2026, 12, 1), verified: verified, revoked: true)
        #expect(!revoked.isActive(now: verified), "no paid grace after a known revocation")
    }

    @Test func afterExpiryUnusedIntroCreditsRemainAndExhaustedFallsBackToMonthly() {
        let now = Self.date(2026, 11, 20)
        let expired = ent(expires: Self.date(2026, 11, 1), verified: Self.date(2026, 10, 25))
        let withIntro = decide(Self.intro(20), now: now, entitlement: expired)
        guard case let .allowed(a) = withIntro else { Issue.record("intro credits should remain"); return }
        #expect(a.kind == .introductory)
        guard case let .allowed(b) = decide(exhausted(), now: now, entitlement: expired) else { Issue.record("monthly expected"); return }
        #expect(b.kind == .monthly)
    }

    @Test func paidShotsDoNotCountAsFreeUse() {
        let paid = (0 ..< 40).map { _ in Self.entry(.paid, period: nil, cost: 0, at: Self.start) }
        let snap = AllowanceEngine.snapshot(entries: paid + Self.intro(5), state: Self.state(), entitlement: nil, now: Self.start)
        #expect(snap.introRemaining == 45)
    }

    // MARK: reservation and settlement

    @Test func reservationFixesTheCreditEvenIfThePeriodFlipsBeforeCommit() throws {
        let armedAt = Self.date(2026, 11, 30, 23)
        guard case let .allowed(r) = decide(exhausted(), now: armedAt) else { Issue.record("arm"); return }
        #expect(r.periodID == "2026-11")
        let commit = Self.date(2026, 12, 1, 0).addingTimeInterval(5)
        let entry = try AllowanceEngine.settle(r, shotID: UUID(), committedAt: commit)
        #expect(entry.periodID == "2026-11" && entry.allowanceKind == .monthly && entry.creditCost == 1)
    }

    @Test func settlingTheSameReservationForTheSameShotTwiceGivesEqualEntries() throws {
        guard case let .allowed(r) = decide(Self.intro(0), now: Self.start) else { Issue.record("arm"); return }
        let id = UUID()
        let a = try AllowanceEngine.settle(r, shotID: id, committedAt: Self.start)
        let b = try AllowanceEngine.settle(r, shotID: id, committedAt: Self.start)
        #expect(a == b)
    }

    @Test func pendingReservationsCountAgainstTheBalance() {
        let snap = AllowanceEngine.snapshot(
            entries: Self.intro(49), state: Self.state(), entitlement: nil, now: Self.start, reserved: 1
        )
        #expect(snap.introRemaining == 0, "an armed swing holds the last credit")
        if case .allowed = AllowanceEngine.decide(
            entries: Self.intro(49), state: Self.state(), entitlement: nil, now: Self.start, reserved: 1
        ) {
            Issue.record("second arm while the last credit is held")
        }
    }

    // MARK: feature gate

    @Test func advancedFeaturesAreOpenDuringIntroAndLockedAfterwardsWithoutPro() {
        let during = AllowanceEngine.snapshot(entries: Self.intro(10), state: Self.state(), entitlement: nil, now: Self.start)
        #expect(AllowanceEngine.access(.dispersion, snapshot: during) == .allowed)
        let after = AllowanceEngine.snapshot(entries: Self.intro(50), state: Self.state(), entitlement: nil, now: Self.start)
        for feature in [Feature.dispersion, .clubMapping, .targetDrill, .ladderDrill, .virtualGolf, .trends] {
            #expect(AllowanceEngine.access(feature, snapshot: after) == .requiresPro, "\(feature)")
        }
        #expect(AllowanceEngine.access(.basicPractice, snapshot: after) == .allowed)
        #expect(AllowanceEngine.access(.history, snapshot: after) == .allowed)
        let pro = AllowanceEngine.snapshot(
            entries: Self.intro(50), state: Self.state(),
            entitlement: ent(expires: Self.date(2026, 12, 1), verified: Self.start), now: Self.start
        )
        #expect(AllowanceEngine.access(.virtualGolf, snapshot: pro) == .allowed)
    }

    // MARK: pricing copy

    @Test func annualPricingFigures() {
        #expect(Pricing.monthlySEK == 49 && Pricing.annualSEK == 499)
        #expect(abs(Pricing.annualPerMonthSEK - 41.58) < 0.01)
        #expect(Pricing.annualSavingPercent == 15.1)
        #expect(Pricing.annualCheaperFromMonth == 11)
    }

    @Test func stateRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(Self.state())
        #expect(try JSONDecoder().decode(AllowanceState.self, from: data) == Self.state())
    }
}
