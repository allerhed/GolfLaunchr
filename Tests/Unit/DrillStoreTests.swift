import Domain
import Foundation
@testable import GolfLaunchr
import Modes
import Persistence
import PersistenceTestSupport
import Testing

/// F11 in the app: the drill config is stored with the session, each shot records its target, and the score follows the shots.
@MainActor
struct DrillStoreTests {
    private func settings() -> SettingsStore {
        guard let defaults = UserDefaults(suiteName: "drill-tests-\(UUID().uuidString)") else { preconditionFailure("suite") }
        return SettingsStore(defaults: defaults)
    }

    private func bag() -> Bag {
        Bag(clubs: ["Driver", "7 iron"].enumerated().compactMap { try? Club(name: $1, category: .iron, loftRad: nil, sortOrder: $0) })
    }

    private func start(_ drill: TargetDrillConfig, store: InMemoryStore) async throws -> PracticeStore {
        try #require(await PracticeStore.start(.target, drill: drill, bag: bag(), settings: settings(), backend: store))
    }

    private func commitShot(_ practice: PracticeStore, carry: Double?) async throws -> Bool {
        let calibration = try CalibrationRecord(
            deviceProfileID: "p", format: CaptureFormatRecord(widthPx: 1, heightPx: 1, framesPerSecond: 240, lens: "w"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
            cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: Date(), calibrationVersion: 1
        )
        try await practice.backend.save(calibration)
        _ = practice.arm(setupReady: true)
        let club = try #require(practice.state.armedClub)
        var metrics: [MetricKey: Domain.Measurement] = [:]
        if let carry {
            metrics[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional)
        } else {
            metrics[.carry] = Domain.Measurement.unavailable(.carry, failure: .blur)
        }
        let shot = try Shot(
            id: UUID(), sessionID: practice.session.id, sequence: practice.state.shots.count + 1, mode: .target, swingHandedness: .right,
            clubSnapshot: club, calibrationID: calibration.id, impactTimeUTC: Date(), metrics: metrics,
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: true
        )
        let ledger = try LedgerEntry(
            acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 0, committedAt: Date()
        )
        return await practice.commit(shot, ledger: ledger)
    }

    @Test func theDrillIsStoredWithTheSessionAndTheTargetIsRecordedPerShot() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let config = try TargetDrillConfig(targetCarryM: 130, longitudinalToleranceM: 6, attempts: 3)
        let practice = try await start(config, store: store)
        #expect(practice.drill == config)
        #expect(try await store.session(id: practice.session.id)?.drill == config)
        #expect(practice.state.targetCarryM == 130)
        #expect(try await commitShot(practice, carry: 128))
        #expect(practice.state.targetSnapshots == [130])
    }

    @Test func theScoreFollowsTheCommittedShotsAndInvalidOnesDoNotAdvance() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try await start(TargetDrillConfig(targetCarryM: 100, longitudinalToleranceM: 5, attempts: 2), store: store)
        #expect(try await commitShot(practice, carry: nil))
        #expect(practice.drillResult?.scoredCount == 0 && practice.drillResult?.unscoredShotCount == 1)
        #expect(try await commitShot(practice, carry: 105))
        #expect(try await commitShot(practice, carry: 90))
        let result = try #require(practice.drillResult)
        #expect(result.isComplete && result.hits == 1 && result.misses == 1 && result.isDistanceOnly)
    }

    @Test func otherModesHaveNoDrill() async throws {
        let store = InMemoryStore(allowsSynthetic: true)
        let practice = try #require(await PracticeStore.start(.standard, bag: bag(), settings: settings(), backend: store))
        #expect(practice.drill == nil && practice.drillResult == nil)
    }
}
