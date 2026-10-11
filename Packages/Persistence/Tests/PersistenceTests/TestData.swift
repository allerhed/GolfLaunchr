import Domain
import Foundation
import PersistenceTestSupport

/// Builders for in-memory tests. Shots are marked synthetic because they are fixtures.
struct World {
    let store: InMemoryStore
    let session: Session
    let calibration: CalibrationRecord
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)

    static func make(allowsSynthetic: Bool = true) async throws -> World {
        let store = InMemoryStore(allowsSynthetic: allowsSynthetic)
        let session = try Session(mode: .practice, createdAt: Date(timeIntervalSince1970: 1_791_716_400))
        let calibration = try CalibrationRecord(
            deviceProfileID: "fixture-only",
            format: CaptureFormatRecord(widthPx: 1920, heightPx: 1080, framesPerSecond: 240, lens: "wide"),
            scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1],
            cameraDistanceM: 0.75, cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good,
            createdAt: session.createdAt, calibrationVersion: 1
        )
        await store.save(session)
        await store.save(calibration)
        return World(store: store, session: session, calibration: calibration)
    }

    func shot(
        sequence: Int = 1,
        id: UUID = UUID(),
        ballSpeed: Double = 45,
        synthetic: Bool = true,
        sessionID: UUID? = nil,
        calibrationID: UUID? = nil
    ) throws -> Shot {
        try Shot(
            id: id, sessionID: sessionID ?? session.id, sequence: sequence, mode: .practice, swingHandedness: .right,
            clubSnapshot: ClubSnapshot(id: UUID(), name: "7 iron", loftRad: nil),
            calibrationID: calibrationID ?? calibration.id, impactTimeUTC: t0,
            metrics: [.ballSpeed: Measurement(key: .ballSpeed, value: ballSpeed, provenance: .measured, quality: .valid)],
            environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), isSynthetic: synthetic
        )
    }

    func ledger(for shot: Shot, kind: AllowanceKind = .introductory, cost: Int = 1) throws -> LedgerEntry {
        try LedgerEntry(acceptedShotID: shot.id, allowanceKind: kind, periodID: nil, creditCost: cost, committedAt: t0)
    }
}
