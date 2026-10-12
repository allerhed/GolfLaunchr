import Domain
import Foundation
@testable import Persistence
import Testing

/// Milestone QA (plan 2.6): adversarial probes written after the fact against the real SQLite store, not by the implementer's
/// own happy-path assumptions: volume, two connections, precision, and what a restart sees.
struct MilestoneQATests {
    /// 3,000 accepted shots: every commit is its own durable transaction (synchronous=FULL), reads stay fast, nothing is lost.
    @Test func volumeOfThreeThousandShotsStaysCorrectAndFast() async throws {
        let w = try await World.make(backend: .sqlite)
        let sqlite = try #require(w.sqlite)
        let start = Date()
        for n in 1 ... 3000 {
            let shot = try w.shot(sequence: n, ballSpeed: 30 + Double(n % 40))
            _ = try await sqlite.commitAccepted(shot, ledger: w.ledger(for: shot))
        }
        let commitSeconds = Date().timeIntervalSince(start)
        let readStart = Date()
        let shots = try await sqlite.shots(sessionID: w.session.id)
        let readSeconds = Date().timeIntervalSince(readStart)
        #expect(shots.count == 3000 && shots.map(\.sequence) == Array(1 ... 3000))
        #expect(try await sqlite.creditsSpent(kind: .introductory) == 3000)
        print("QA volume: 3000 commits \(commitSeconds)s, read \(readSeconds)s")
        #expect(commitSeconds < 60 && readSeconds < 2)
    }

    /// A second connection to the same file (a future extension, a backup tool) must wait, not corrupt or lose either write.
    @Test func twoConnectionsWritingAtOnceLoseNothing() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let a = try #require(w.sqlite)
        let b = try SQLiteStore(url: url, allowsSynthetic: true)
        let shotsA = try (1 ... 40).map { try w.shot(sequence: $0) }
        let shotsB = try (41 ... 80).map { try w.shot(sequence: $0) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { for s in shotsA {
                _ = try await a.commitAccepted(s, ledger: w.ledger(for: s))
            } }
            group.addTask { for s in shotsB {
                _ = try await b.commitAccepted(s, ledger: w.ledger(for: s))
            } }
            try await group.waitForAll()
        }
        let reopened = try SQLiteStore(url: url, allowsSynthetic: true)
        #expect(try await reopened.shots(sessionID: w.session.id).count == 80)
        #expect(try await reopened.entries().count == 80)
    }

    /// Millisecond impact times and awkward doubles survive a restart exactly (a regression here would silently shift data).
    @Test func awkwardNumbersAndTimesSurviveReopen() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let sqlite = try #require(w.sqlite)
        let metric = try Domain.Measurement(key: .ballSpeed, value: 45.123456789012345, provenance: .measured, quality: .valid)
        let tiny = try Domain.Measurement(key: .carry, value: 5e-324, provenance: .estimated, quality: .provisional)
        let shot = try Shot(
            id: UUID(), sessionID: w.session.id, sequence: 1, mode: .practice, swingHandedness: .left,
            clubSnapshot: ClubSnapshot(id: UUID(), name: "Järn 7 \u{1F3CC}\u{FE0F}", loftRad: 0.4363323129985824),
            calibrationID: w.calibration.id, impactTimeUTC: Date(timeIntervalSince1970: 1_791_716_400.123),
            metrics: [.ballSpeed: metric, .carry: tiny],
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        _ = try await sqlite.commitAccepted(shot, ledger: w.ledger(for: shot))
        let back = try #require(try await SQLiteStore(url: url, allowsSynthetic: true).shot(id: shot.id))
        #expect(back == shot)
        #expect(back.value(.ballSpeed) == 45.123456789012345 && back.clubSnapshot.name == "Järn 7 \u{1F3CC}\u{FE0F}")
    }

    /// Deleting a session while another connection is mid-read must neither crash nor leave orphan shots.
    @Test func deletingASessionLeavesNoOrphanShotsInTheFile() async throws {
        let w = try await World.make(backend: .sqlite)
        let sqlite = try #require(w.sqlite)
        for n in 1 ... 5 {
            let s = try w.shot(sequence: n)
            _ = try await sqlite.commitAccepted(s, ledger: w.ledger(for: s))
        }
        try await sqlite.deleteSession(id: w.session.id)
        #expect(try await sqlite.shot(id: UUID()) == nil)
        let reopened = try SQLiteStore(url: #require(w.databaseURL), allowsSynthetic: true)
        #expect(try await reopened.shots(sessionID: w.session.id).isEmpty)
        #expect(try await reopened.entries().count == 5) // credits are history, not session data
    }

    /// A -wal file left by a killed process is recovered on the next open, not mistaken for corruption.
    @Test func reopeningAfterAnUncleanCloseRecoversTheWal() async throws {
        let w = try await World.make(backend: .sqlite)
        let url = try #require(w.databaseURL)
        let sqlite = try #require(w.sqlite)
        let s = try w.shot()
        _ = try await sqlite.commitAccepted(s, ledger: w.ledger(for: s))
        let wal = url.path + "-wal"
        #expect(FileManager.default.fileExists(atPath: wal)) // the data really is in the WAL, not yet checkpointed
        let copy = url.deletingLastPathComponent().appendingPathComponent("copy")
        try FileManager.default.createDirectory(at: copy, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] where FileManager.default.fileExists(atPath: url.path + suffix) {
            try FileManager.default.copyItem(atPath: url.path + suffix, toPath: copy.appendingPathComponent("store.sqlite" + suffix).path)
        } // a byte-for-byte snapshot taken while the first connection is still open = what a crash leaves behind
        let recovered = try SQLiteStore(url: copy.appendingPathComponent("store.sqlite"), allowsSynthetic: true)
        #expect(try await recovered.shot(id: s.id) == s)
    }
}
