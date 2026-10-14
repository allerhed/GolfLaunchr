import Domain
@testable import Export
import Foundation
import Persistence
import PersistenceTestSupport
import Testing

/// F21 redacted diagnostic bundle: versions, counts and failure codes only. Never shot values, club names, ids, dates, media.
struct DiagnosticsTests {
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)
    let facts = DiagnosticsFacts(
        appVersion: "1.0", buildNumber: "42", osVersion: "iOS 26.0", deviceClass: "iPhone", language: "sv", storageFreeMegabytes: 12345
    )

    func store(marker: String) async throws -> (InMemoryStore, Session) {
        let store = InMemoryStore(allowsSynthetic: true)
        let calibration = try CalibrationRecord(
            deviceProfileID: "iPhone17,2-wide", format: CaptureFormatRecord(widthPx: 1920, heightPx: 1080, framesPerSecond: 240, lens: "w"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
        await store.save(calibration)
        let session = try Session(mode: .practice, createdAt: t0)
        await store.save(session)
        for seq in 1 ... 3 {
            let failure: MeasurementFailure = seq == 3 ? .occlusion : .blur
            let shot = try Shot(
                id: UUID(), sessionID: session.id, sequence: seq, mode: .practice, swingHandedness: .right,
                clubSnapshot: ClubSnapshot(id: UUID(), name: marker, loftRad: nil), calibrationID: calibration.id,
                impactTimeUTC: t0.addingTimeInterval(Double(seq)),
                metrics: [
                    .ballSpeed: Domain.Measurement(key: .ballSpeed, value: 45.678901, provenance: .measured, quality: .valid),
                    .clubSpeed: Domain.Measurement.unavailable(.clubSpeed, failure: failure),
                ],
                environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
                versions: ShotVersions(pipeline: "pipe-7", flight: "flight-3", deviceProfile: "iPhone17,2-wide"), isSynthetic: true
            )
            let ledger = try LedgerEntry(
                acceptedShotID: shot.id,
                allowanceKind: .introductory,
                periodID: nil,
                creditCost: 0,
                committedAt: t0
            )
            _ = try await store.commitAccepted(shot, ledger: ledger)
        }
        return (store, session)
    }

    @Test func theBundleHoldsVersionsCountsAndFailureCodes() async throws {
        let (store, _) = try await store(marker: "Marker Club")
        let report = try await DiagnosticsService(sessions: store, shots: store).report(facts: facts)
        let text = report.text
        for expected in [
            "App: 1.0 (42)", "iOS 26.0", "Device class: iPhone", "Language: sv", "Free storage: 12345 MB",
            "Sessions: 1", "Shots: 3", "pipe-7", "flight-3", "iPhone17,2-wide", "blur: 2", "occlusion: 1", "Frame drops: not recorded",
        ] {
            #expect(text.contains(expected), "missing \(expected)")
        }
        #expect(report.failureCounts == ["blur": 2, "occlusion": 1])
    }

    @Test func nothingPersonalOrMeasuredLeaksIntoTheBundle() async throws {
        let marker = "ZZ-PRIVATE-CLUB-\(UUID().uuidString)"
        let (store, session) = try await store(marker: marker)
        let text = try await DiagnosticsService(sessions: store, shots: store).report(facts: facts).text
        #expect(!text.contains(marker), "club names are redacted")
        #expect(!text.contains(session.id.uuidString), "ids are redacted")
        #expect(!text.contains("45.67"), "measured values are redacted")
        #expect(!text.contains("2026"), "no dates of practice")
        #expect(!text.contains("1791716"), "no timestamps")
        #expect(text.contains("No video, clips, shot values, club names or dates are included."))
    }

    @Test func anEmptyStoreGivesZerosNotErrors() async throws {
        let store = InMemoryStore()
        let report = try await DiagnosticsService(sessions: store, shots: store).report(facts: facts)
        #expect(report.text.contains("Sessions: 0") && report.text.contains("Shots: 0") && report.text.contains("Failure codes: none"))
    }

    @Test func unknownStorageIsSaidNotZero() async throws {
        let store = InMemoryStore()
        var unknown = facts
        unknown.storageFreeMegabytes = nil
        let text = try await DiagnosticsService(sessions: store, shots: store).report(facts: unknown).text
        #expect(text.contains("Free storage: unknown"))
    }
}
