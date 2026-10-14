import Domain
import Export
import Foundation
@testable import GolfLaunchr
import Persistence
import PersistenceTestSupport
import Testing

@MainActor
struct PrivacyStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)

    func facts() -> DiagnosticsFacts {
        DiagnosticsFacts(
            appVersion: "1",
            buildNumber: "2",
            osVersion: "iOS",
            deviceClass: "iPhone",
            language: "en",
            storageFreeMegabytes: 1
        )
    }

    func filled() async throws -> InMemoryStore {
        let store = InMemoryStore(allowsSynthetic: true)
        let session = try Session(mode: .practice, createdAt: t0)
        await store.save(session)
        let calibration = try CalibrationRecord(
            deviceProfileID: "p", format: CaptureFormatRecord(widthPx: 1, heightPx: 1, framesPerSecond: 240, lens: "w"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
        await store.save(calibration)
        let shot = try Shot(
            id: UUID(), sessionID: session.id, sequence: 1, mode: .practice, swingHandedness: .right,
            clubSnapshot: ClubSnapshot(id: UUID(), name: "Secret Club", loftRad: nil), calibrationID: calibration.id, impactTimeUTC: t0,
            metrics: [:], environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "p", flight: "f", deviceProfile: "d"), isSynthetic: true
        )
        _ = try await store.commitAccepted(shot, ledger: LedgerEntry(
            acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: t0
        ))
        return store
    }

    func mediaDir() throws -> MediaDirectory {
        try MediaDirectory(root: FileManager.default.temporaryDirectory.appendingPathComponent("privacy-\(UUID().uuidString)"))
    }

    @Test func deletingAllDataEmptiesTheStoreKeepsTheLedgerAndRefreshesTheScreens() async throws {
        let store = try await filled()
        let media = try mediaDir()
        try media.commit(media.stage(Data("clip".utf8)), as: "a.mov")
        var refreshed = 0
        let privacy = PrivacyStore(backend: store, media: media, facts: facts, afterDeletion: { refreshed += 1 })
        await privacy.deleteAllPracticeData()
        #expect(privacy.deletion == .done && refreshed == 1)
        #expect(try await store.sessions().isEmpty)
        #expect(try await store.entries().count == 1, "the usage ledger stays")
        #expect(try media.scanOrphans(referenced: []).isEmpty, "media is removed too")
    }

    @Test func noStorageMeansADeletionFailureNotASilentSuccess() async {
        var refreshed = 0
        let privacy = PrivacyStore(backend: nil, media: nil, facts: facts, afterDeletion: { refreshed += 1 })
        await privacy.deleteAllPracticeData()
        #expect(privacy.deletion == .failed && refreshed == 0)
    }

    @Test func mediaOnlyDeletionLeavesSessionsAndShots() async throws {
        let store = try await filled()
        let media = try mediaDir()
        try media.commit(media.stage(Data("clip".utf8)), as: "a.mov")
        let privacy = PrivacyStore(backend: store, media: media, facts: facts, afterDeletion: {})
        await privacy.deleteMediaOnly()
        #expect(privacy.mediaDeletion == .done && privacy.mediaFilesRemoved == 1)
        #expect(try await store.sessions().count == 1)
        await privacy.deleteMediaOnly()
        #expect(privacy.mediaFilesRemoved == 0, "nothing left to delete is reported as zero, not as an error")
    }

    @Test func exportWritesAFileThatDeletionThenDiscards() async throws {
        let store = try await filled()
        let privacy = PrivacyStore(backend: store, media: nil, facts: facts, afterDeletion: {})
        await privacy.prepareExport(.json)
        let file = try #require(privacy.exportFile)
        #expect(privacy.export == .done && FileManager.default.fileExists(atPath: file.path))
        await privacy.deleteAllPracticeData()
        #expect(!FileManager.default.fileExists(atPath: file.path), "no export copy is left in the temporary folder")
    }

    @Test func theDiagnosticPreviewIsRedactedAndNothingIsSharedUntilAsked() async throws {
        let store = try await filled()
        let privacy = PrivacyStore(backend: store, media: nil, facts: facts, afterDeletion: {})
        #expect(privacy.diagnostics == nil)
        await privacy.buildDiagnostics()
        let text = try #require(privacy.diagnostics?.text)
        #expect(text.contains("Shots: 1") && !text.contains("Secret Club"))
    }
}
