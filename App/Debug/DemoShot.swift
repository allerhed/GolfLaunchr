#if DEBUG
    import Domain
    import Foundation
    import SwiftUI

    /// DEMO shots for the practice screen in Debug builds, labelled "Demo" and flagged synthetic: a production store refuses them.
    /// Shown only when the store accepts synthetic shots (UI-test database started with `-uiTestSeedHistory`).
    extension PracticeStore {
        func addDemoShot() async -> Bool {
            guard state.isArmed, let club = state.armedClub else { return false }
            let sequence = state.shots.count + 1
            do {
                let calibration = try CalibrationRecord(
                    deviceProfileID: "demo-fixture", format: CaptureFormatRecord(
                        widthPx: 1920,
                        heightPx: 1080,
                        framesPerSecond: 240,
                        lens: "demo"
                    ),
                    scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 0.75,
                    cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: Date(), calibrationVersion: 1
                )
                try await backend.save(calibration)
                let carry = 100 + Double(sequence * 7 % 30)
                let metrics: [MetricKey: Domain.Measurement] = try [
                    .carry: Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional),
                    .ballSpeed: Domain.Measurement(key: .ballSpeed, value: 40 + Double(sequence), provenance: .measured, quality: .valid),
                ]
                let shot = try Shot(
                    id: UUID(), sessionID: session.id, sequence: sequence, mode: session.mode, swingHandedness: .right, clubSnapshot: club,
                    calibrationID: calibration.id, impactTimeUTC: Date(), metrics: metrics,
                    environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
                    versions: ShotVersions(pipeline: "demo", flight: "demo", deviceProfile: "demo-fixture"), isSynthetic: true
                )
                let ledger = try LedgerEntry(
                    acceptedShotID: shot.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: shot.impactTimeUTC
                )
                return await commit(shot, ledger: ledger)
            } catch {
                return false
            }
        }
    }

    extension PracticeView {
        @ViewBuilder var demoButton: some View {
            if store.state.isArmed {
                Button { Task { _ = await store.addDemoShot() } } label: {
                    Text(verbatim: "Demo shot").frame(minWidth: 100, minHeight: Spacing.minTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("practice.demoShot")
            }
        }
    }
#endif
