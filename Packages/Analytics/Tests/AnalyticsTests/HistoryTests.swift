import Analytics
import Domain
import Foundation
import Testing

/// Builders for history tests. Shots are synthetic fixtures.
enum HistoryFixture {
    static let t0 = Date(timeIntervalSince1970: 1_791_716_400) // 2026-10-11 11:00:00 UTC
    static let club7 = ClubSnapshotBox.make("7 iron")
    static let clubPW = ClubSnapshotBox.make("PW")

    static func session(mode: ShotMode = .practice, start: Date = t0, minutes: Double? = 30) throws -> Session {
        try Session(mode: mode, createdAt: start, endedAt: minutes.map { start.addingTimeInterval($0 * 60) })
    }

    static func shot(
        _ session: Session,
        seq: Int,
        club: ClubSnapshot = club7,
        carry: Double? = 130,
        carryQuality: MetricQuality = .provisional,
        speed: Double? = 45,
        included: Bool = true,
        synthetic: Bool = true
    ) throws -> Shot {
        var metrics: [MetricKey: Domain.Measurement] = [:]
        if let carry {
            metrics[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: carryQuality)
        }
        if let speed {
            metrics[.ballSpeed] = try Domain.Measurement(key: .ballSpeed, value: speed, provenance: .measured, quality: .valid)
        }
        return try Shot(
            id: UUID(), sessionID: session.id, sequence: seq, mode: session.mode, swingHandedness: .right, clubSnapshot: club,
            calibrationID: UUID(), impactTimeUTC: session.createdAt, metrics: metrics,
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), included: included, isSynthetic: synthetic
        )
    }
}

enum ClubSnapshotBox {
    static func make(_ name: String) -> ClubSnapshot {
        guard let snap = try? ClubSnapshot(id: UUID(), name: name, loftRad: nil) else { preconditionFailure("valid snapshot") }
        return snap
    }
}

struct SessionSummaryTests {
    @Test func countsMeansAndOrderedClubs() throws {
        let s = try HistoryFixture.session()
        let shots = try [
            HistoryFixture.shot(s, seq: 1, club: HistoryFixture.club7, carry: 100),
            HistoryFixture.shot(s, seq: 2, club: HistoryFixture.clubPW, carry: 120),
            HistoryFixture.shot(s, seq: 3, club: HistoryFixture.club7, carry: 110),
        ]
        let sum = SessionSummaries.make(session: s, shots: shots.reversed()) // order of input must not matter
        #expect(sum.shotCount == 3 && sum.includedCount == 3 && sum.excludedCount == 0)
        #expect(sum.clubs.map(\.name) == ["7 iron", "PW"]) // by first use
        #expect(sum.meanCarryMetres == 110 && sum.carrySamples == 3)
        #expect(sum.duration == 1800)
        #expect(sum.containsDemoData)
    }

    /// F10: excluded shots never enter the averages, and the numbers change consistently when exclusion changes.
    @Test func excludingAShotChangesTheMeanAndRestoringReturnsIt() throws {
        let s = try HistoryFixture.session()
        var shots = try [
            HistoryFixture.shot(s, seq: 1, carry: 100),
            HistoryFixture.shot(s, seq: 2, carry: 120),
            HistoryFixture.shot(s, seq: 3, carry: 200)
        ]
        #expect(SessionSummaries.make(session: s, shots: shots).meanCarryMetres == 140)
        shots[2].included = false
        let after = SessionSummaries.make(session: s, shots: shots)
        #expect(after.meanCarryMetres == 110 && after.includedCount == 2 && after.excludedCount == 1 && after.shotCount == 3)
        shots[2].included = true
        #expect(SessionSummaries.make(session: s, shots: shots).meanCarryMetres == 140)
    }

    @Test func failedOrUnavailableMeasurementsNeverContaminateAverages() throws {
        let s = try HistoryFixture.session()
        let shots = try [
            HistoryFixture.shot(s, seq: 1, carry: 100),
            HistoryFixture.shot(s, seq: 2, carry: 999, carryQuality: .invalid), // marked invalid
            HistoryFixture.shot(s, seq: 3, carry: nil), // no carry reported
        ]
        var unavailable = shots
        unavailable[2] = try {
            var m = unavailable[2].metrics
            m[.carry] = Domain.Measurement.unavailable(.carry, failure: .blur)
            return try Shot(
                id: unavailable[2].id, sessionID: s.id, sequence: 3, mode: .practice, swingHandedness: .right,
                clubSnapshot: HistoryFixture.club7, calibrationID: UUID(), impactTimeUTC: s.createdAt, metrics: m,
                environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
                versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
            )
        }()
        let sum = SessionSummaries.make(session: s, shots: unavailable)
        #expect(sum.meanCarryMetres == 100 && sum.carrySamples == 1)
        #expect(sum.shotCount == 3) // the shots exist; only the averages ignore them
    }

    @Test func noDataMeansNilNeverZero() throws {
        let s = try HistoryFixture.session()
        let empty = SessionSummaries.make(session: s, shots: [])
        #expect(empty.meanCarryMetres == nil && empty.meanBallSpeedMetresPerSecond == nil && empty.shotCount == 0 && empty.clubs.isEmpty)
        let allExcluded = try SessionSummaries.make(session: s, shots: [HistoryFixture.shot(s, seq: 1, included: false)])
        #expect(allExcluded.meanCarryMetres == nil && allExcluded.includedCount == 0 && allExcluded.excludedCount == 1)
    }

    @Test func anOpenSessionHasNoDurationAndRealDataIsNotDemo() throws {
        let s = try HistoryFixture.session(minutes: nil)
        let sum = try SessionSummaries.make(session: s, shots: [HistoryFixture.shot(s, seq: 1, synthetic: false)])
        #expect(sum.duration == nil && sum.containsDemoData == false)
    }
}

struct HistoryFilterTests {
    func summaries() throws -> [SessionSummary] {
        let now = HistoryFixture.t0
        let a = try HistoryFixture.session(mode: .practice, start: now.addingTimeInterval(-2 * 86400))
        let b = try HistoryFixture.session(mode: .target, start: now.addingTimeInterval(-10 * 86400))
        let c = try HistoryFixture.session(mode: .practice, start: now.addingTimeInterval(-40 * 86400))
        return try [
            SessionSummaries.make(session: a, shots: [HistoryFixture.shot(a, seq: 1, club: HistoryFixture.club7)]),
            SessionSummaries.make(session: b, shots: [HistoryFixture.shot(b, seq: 1, club: HistoryFixture.clubPW)]),
            SessionSummaries.make(session: c, shots: [HistoryFixture.shot(c, seq: 1, club: HistoryFixture.club7)]),
        ]
    }

    @Test func noFilterReturnsEverythingNewestFirst() throws {
        let all = try HistoryFilter().apply(to: summaries(), now: HistoryFixture.t0)
        #expect(all.count == 3)
        #expect(all.map(\.startedAt) == all.map(\.startedAt).sorted(by: >))
    }

    @Test func timeRangesUseTheStartTimeBoundaryInclusively() throws {
        let now = HistoryFixture.t0
        let list = try summaries()
        #expect(HistoryFilter(range: .last7Days).apply(to: list, now: now).count == 1)
        #expect(HistoryFilter(range: .last30Days).apply(to: list, now: now).count == 2)
        // A session starting exactly 7 days ago is kept.
        let edge = try HistoryFixture.session(start: now.addingTimeInterval(-7 * 86400))
        let edgeSummary = SessionSummaries.make(session: edge, shots: [])
        #expect(HistoryFilter(range: .last7Days).apply(to: [edgeSummary], now: now).count == 1)
        let justOutside = try HistoryFixture.session(start: now.addingTimeInterval(-7 * 86400 - 1))
        #expect(HistoryFilter(range: .last7Days).apply(to: [SessionSummaries.make(session: justOutside, shots: [])], now: now).isEmpty)
    }

    @Test func modeAndClubFiltersCombine() throws {
        let list = try summaries()
        let now = HistoryFixture.t0
        #expect(HistoryFilter(mode: .target).apply(to: list, now: now).count == 1)
        #expect(HistoryFilter(clubID: HistoryFixture.club7.id).apply(to: list, now: now).count == 2) // sessions a and c
        #expect(HistoryFilter(clubID: HistoryFixture.clubPW.id).apply(to: list, now: now).count == 1) // session b
        #expect(HistoryFilter(clubID: UUID()).apply(to: list, now: now).isEmpty)
        #expect(HistoryFilter(range: .last7Days, mode: .target).apply(to: list, now: now).isEmpty) // target session is 10 days old
        #expect(HistoryFilter(range: .last30Days, mode: .practice, clubID: HistoryFixture.club7.id).apply(to: list, now: now).count == 1)
        #expect(HistoryFilter().isActive == false && HistoryFilter(mode: .practice).isActive)
    }

    @Test func clubOptionsAreDistinctAndMostRecentFirst() throws {
        let options = try HistoryFilter.clubOptions(from: summaries())
        #expect(options.map(\.name) == ["7 iron", "PW"]) // 7 iron (newest session) first, shared by two sessions but listed once
        let reused = ClubSnapshotBox.make("Driver")
        let s1 = try HistoryFixture.session(start: HistoryFixture.t0)
        let s2 = try HistoryFixture.session(start: HistoryFixture.t0.addingTimeInterval(-86400))
        let both = try [
            SessionSummaries.make(session: s1, shots: [HistoryFixture.shot(s1, seq: 1, club: reused)]),
            SessionSummaries.make(session: s2, shots: [HistoryFixture.shot(s2, seq: 1, club: reused)]),
        ]
        #expect(HistoryFilter.clubOptions(from: both).map(\.name) == ["Driver"])
    }
}
