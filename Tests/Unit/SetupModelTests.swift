import Capture
import Domain
import Foundation
@testable import GolfLaunchr
import Testing

private struct StubObserver: EnvironmentObserving {
    let observations: [SetupObservation]
    func start() -> AsyncStream<SetupObservation> {
        AsyncStream { continuation in
            observations.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func stop() {}
}

private let goodScene = SetupObservation(
    meanLuma: 0.45, clippedFraction: 0.01, motionScore: 0.3, flickerIndex: 0.004, exposureSeconds: 1.0 / 2000
)

@MainActor
struct SetupModelTests {
    private func settings(handedness: SwingHandedness? = .right) -> SettingsStore {
        guard let defaults = UserDefaults(suiteName: "setup-tests-\(UUID().uuidString)") else { preconditionFailure("suite") }
        let store = SettingsStore(defaults: defaults)
        store.swingHandedness = handedness
        return store
    }

    private func model(
        _ settings: SettingsStore,
        scene: [SetupObservation] = [goodScene],
        calibration: CalibrationState = .none,
        capability: CapabilityStatus = .experimental
    ) -> SetupModel {
        SetupModel(settings: settings, observer: StubObserver(observations: scene), capability: capability, calibration: calibration)
    }

    private func settle(_ model: SetupModel) async {
        model.startObserving()
        for _ in 0 ..< 50 where model.observation == SetupObservation() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func liveObservationsDriveTheReadinessAndTheChecklist() async {
        let m = model(settings(), calibration: .valid)
        #expect(m.readiness.blockers == [.cameraNotRunning]) // nothing measured yet
        await settle(m)
        #expect(m.readiness.canArm && m.rows.allSatisfy { $0.state != .problem })
    }

    @Test func aMovingPictureBlocksArmingWithTheReason() async {
        var moving = goodScene
        moving.motionScore = 15
        let m = model(settings(), scene: [moving], calibration: .valid)
        await settle(m)
        #expect(m.readiness.blockers == [.deviceMoving] && !m.readiness.canArm)
    }

    @Test func modeArmsWithoutCalibrationButNeverScores() async {
        let m = model(settings())
        await settle(m)
        #expect(m.readiness.blockers == [.notCalibrated])
        m.mode = .test
        #expect(m.readiness.canArm && !m.readiness.canScore)
    }

    @Test func changingSideWhileCalibratedAsksFirstAndThenForcesRecalibration() async {
        let s = settings(handedness: .right)
        let m = model(s, calibration: .valid)
        m.choose(.left)
        #expect(m.needsHandednessConfirmation && s.swingHandedness == .right && m.state.calibration == .valid) // nothing changed yet
        m.cancelHandednessChange()
        #expect(!m.needsHandednessConfirmation && s.swingHandedness == .right)
        m.choose(.left)
        m.confirmHandednessChange()
        #expect(s.swingHandedness == .left && m.state.calibration == .lost)
        await settle(m)
        #expect(m.readiness.blockers == [.calibrationLost])
    }

    @Test func withoutACalibrationTheSideChangesAtOnceAndIsPersisted() {
        let s = settings(handedness: nil)
        let m = model(s)
        #expect(m.readiness.blockers.contains(.handednessMissing))
        m.choose(.left)
        #expect(s.swingHandedness == .left && !m.needsHandednessConfirmation)
    }

    @Test func theFirstChoiceOfASideWithACalibrationPresentIsNotAChange() {
        let s = settings(handedness: nil)
        let m = model(s, calibration: .valid)
        m.choose(.right)
        #expect(!m.needsHandednessConfirmation && s.swingHandedness == .right && m.state.calibration == .valid)
    }

    @Test func anUnsupportedDeviceCannotArmEvenInATest() async {
        let m = model(settings(), capability: .unsupported)
        m.mode = .test
        await settle(m)
        #expect(m.readiness.blockers == [.unsupportedDevice] && !m.readiness.canArm)
    }

    @Test func noObservationsMeansCameraNotRunningAndStopIsSafe() {
        let m = model(settings(), scene: [SetupObservation()])
        m.startObserving()
        m.stopObserving()
        m.stopObserving()
        #expect(m.readiness.blockers.contains(.cameraNotRunning))
    }
}

/// Every reason, action, warning, check and state shown on the setup screen exists in both languages (a missing key would show the
/// raw key name to the user).
struct SetupStringsTests {
    private func bundle(_ lang: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"), let b = Bundle(path: path) else {
            preconditionFailure("no \(lang).lproj")
        }
        return b
    }

    private var keys: [String] {
        SetupBlocker.allCases.flatMap { [$0.reasonKey, $0.actionKey] } + SetupWarning.allCases.map(\.reasonKey)
            + SetupCheck.allCases.map { "setup.check.\($0.rawValue)" } + ["good", "check", "problem", "unknown"].map { "setup.state.\($0)" }
            + [
                "setup.title",
                "setup.subtitle",
                "setup.ready",
                "setup.blocked.title",
                "setup.test.button",
                "setup.test.exit",
                "setup.test.banner"
            ]
    }

    @Test(arguments: ["en", "sv"])
    func everyKeyIsTranslated(lang: String) {
        let b = bundle(lang)
        let missing = keys.filter { b.localizedString(forKey: $0, value: "MISSING", table: nil) == "MISSING" }
        #expect(missing.isEmpty, "missing in \(lang): \(missing)")
    }

    @Test func swedishDiffersFromEnglishForTheBlockers() {
        let en = bundle("en"), sv = bundle("sv")
        for blocker in SetupBlocker.allCases {
            #expect(en.localizedString(forKey: blocker.reasonKey, value: nil, table: nil)
                != sv.localizedString(forKey: blocker.reasonKey, value: nil, table: nil))
        }
    }
}
