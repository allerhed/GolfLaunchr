#if DEBUG
    import Domain
    import Foundation
    import Persistence

    /// DEMO DATA for UI tests and screenshots. Debug builds only (a Release build contains none of this: verified by
    /// `scripts/check-harness-separation.sh`). Every shot is marked synthetic, so the history screens label it "Demo data", and a
    /// production store refuses such shots. Enabled only by the launch argument `-uiTestSeedHistory` together with a test database.
    enum HistoryFixtures {
        private static func club(_ name: String, _ id: String) -> ClubSnapshot {
            guard let uuid = UUID(uuidString: id), let snapshot = try? ClubSnapshot(id: uuid, name: name, loftRad: nil) else {
                preconditionFailure("valid fixture club")
            }
            return snapshot
        }

        static let sevenIron = club("7 iron", "00000000-0000-4000-8000-0000000000A7")
        static let pitchingWedge = club("PW", "00000000-0000-4000-8000-0000000000A9")
        static let driver = club("Driver", "00000000-0000-4000-8000-0000000000A1")

        /// One demo shot: its club, an optional carry (nil = ball hidden) and its ball speed.
        private struct DemoShot {
            let club: ClubSnapshot
            let carry: Double?
            let speed: Double
        }

        /// Adds the demo sessions once. Does nothing if the database already holds any session.
        static func seedIfEmpty(_ store: SQLiteStore, now: Date = Date()) async {
            guard let existing = try? await store.sessions(), existing.isEmpty else { return }
            do { try await seed(store, now: now) } catch { print("HistoryFixtures: seeding failed: \(error)") }
        }

        private static func seed(_ store: SQLiteStore, now: Date) async throws {
            let calibration = try CalibrationRecord(
                deviceProfileID: "demo-fixture", format: CaptureFormatRecord(
                    widthPx: 1920,
                    heightPx: 1080,
                    framesPerSecond: 240,
                    lens: "demo"
                ),
                scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 0.75,
                cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: now, calibrationVersion: 1
            )
            try await store.save(calibration)
            let day: TimeInterval = 86400
            // Session 1: practice, 2 days ago. Shot 3 has no club speed (blur), shot 4 has no carry (ball hidden).
            let s1 = try Session(mode: .practice, createdAt: now - 2 * day, endedAt: now - 2 * day + 32 * 60)
            let s2 = try Session(mode: .target, createdAt: now - 5 * day, endedAt: now - 5 * day + 18 * 60)
            let s3 = try Session(mode: .practice, createdAt: now - 40 * day, endedAt: now - 40 * day + 25 * 60)
            for session in [s1, s2, s3] {
                try await store.save(session)
            }
            func demo(_ club: ClubSnapshot, _ carry: Double?, _ speed: Double) -> DemoShot {
                DemoShot(club: club, carry: carry, speed: speed)
            }
            let plan: [(Session, [DemoShot])] = [
                (s1, [
                    demo(sevenIron, 128, 45.1), demo(sevenIron, 131, 45.8), demo(sevenIron, 134, 46.2), demo(sevenIron, nil, 44.9),
                    demo(pitchingWedge, 94, 38.0), demo(pitchingWedge, 96, 38.6),
                ]),
                (
                    s2,
                    [
                        demo(pitchingWedge, 92, 37.5),
                        demo(pitchingWedge, 95, 38.2),
                        demo(pitchingWedge, 99, 39.0),
                        demo(pitchingWedge, 90, 37.0)
                    ]
                ),
                (s3, [demo(driver, 221, 63.0), demo(driver, 228, 64.5), demo(driver, 215, 62.1)]),
            ]
            for (session, shots) in plan {
                for (index, entry) in shots.enumerated() {
                    try await commit(store, session: session, calibration: calibration, sequence: index + 1, entry: entry)
                }
            }
        }

        private static func commit(
            _ store: SQLiteStore,
            session: Session,
            calibration: CalibrationRecord,
            sequence: Int,
            entry: DemoShot
        ) async throws {
            var metrics: [MetricKey: Domain.Measurement] = try [
                .ballSpeed: Domain.Measurement(key: .ballSpeed, value: entry.speed, provenance: .measured, quality: .valid),
                .clubSpeed: Domain.Measurement.unavailable(.clubSpeed, failure: sequence == 3 ? .blur : .unsupportedMetric),
                .spinAxis: Domain.Measurement.unavailable(.spinAxis),
            ]
            // Demo sideways landing (metres, right positive): a small deterministic scatter, only where the ball was seen.
            if entry.carry != nil {
                metrics[.lateralLanding] = try Domain.Measurement(
                    key: .lateralLanding, value: Double(sequence * 5 % 13) - 6, provenance: .estimated, quality: .provisional
                )
            }
            metrics[.carry] = try entry.carry.map { try Domain.Measurement(
                key: .carry,
                value: $0,
                provenance: .estimated,
                quality: .provisional
            ) }
                ?? Domain.Measurement.unavailable(.carry, failure: .occlusion)
            let shot = try Shot(
                id: UUID(), sessionID: session.id, sequence: sequence, mode: session.mode, swingHandedness: .right,
                clubSnapshot: entry.club,
                calibrationID: calibration.id, impactTimeUTC: session.createdAt.addingTimeInterval(Double(sequence) * 60), metrics: metrics,
                environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
                versions: ShotVersions(pipeline: "demo", flight: "demo", deviceProfile: "demo-fixture"), isSynthetic: true
            )
            let ledger = try LedgerEntry(
                acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 0, committedAt: shot.impactTimeUTC
            )
            _ = try await store.commitAccepted(shot, ledger: ledger)
        }
    }
#endif
