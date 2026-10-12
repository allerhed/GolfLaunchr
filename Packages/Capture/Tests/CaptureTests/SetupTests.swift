@testable import Capture
import Domain
import Foundation
import Testing

private func grid(_ value: UInt8, columns: Int = 4, rows: Int = 4) -> LumaGrid {
    guard let g = LumaGrid(columns: columns, rows: rows, values: Array(repeating: value, count: columns * rows)) else {
        preconditionFailure("grid")
    }
    return g
}

private func grid(_ values: [UInt8]) -> LumaGrid {
    guard let g = LumaGrid(columns: values.count, rows: 1, values: values) else { preconditionFailure("grid") }
    return g
}

struct SetupMonitorTests {
    /// A steady, well-lit, non-flickering scene at 240 fps for one second.
    @Test func aSteadySceneIsStableWellLitAndNotFlickering() throws {
        var monitor = SetupMonitor()
        for n in 0 ..< 240 {
            monitor.add(grid(120), at: Double(n) / 240)
        }
        let o = monitor.observation(exposureSeconds: 1.0 / 1000)
        #expect(o.motionScore == 0 && o.flickerIndex == 0)
        #expect(try abs(#require(o.meanLuma) - 120.0 / 255) < 1e-9 && o.clippedFraction == 0)
    }

    @Test func movementRaisesTheMotionScore() {
        var monitor = SetupMonitor()
        for n in 0 ..< 240 {
            monitor.add(grid(n.isMultiple(of: 2) ? 60 : 160), at: Double(n) / 240)
        }
        #expect((monitor.observation(exposureSeconds: nil).motionScore ?? 0) > 50)
    }

    @Test func clippedPixelsAreCounted() {
        var monitor = SetupMonitor()
        for n in 0 ..< 10 {
            monitor.add(grid([255, 255, 100, 100]), at: Double(n) / 240)
        }
        #expect(monitor.observation(exposureSeconds: nil).clippedFraction == 0.5)
    }

    /// Mains flicker shows as periodic brightness change in an otherwise still scene.
    @Test func brightnessRippleIsReportedAsFlickerIndex() {
        var monitor = SetupMonitor()
        for n in 0 ..< 240 {
            let t = Double(n) / 240
            let level = 120 + 20 * sin(2 * .pi * 100 * t) // 100 Hz ripple, +/-17% of the mean
            monitor.add(grid(UInt8(level.rounded())), at: t)
        }
        #expect((monitor.observation(exposureSeconds: nil).flickerIndex ?? 0) > 0.08)
    }

    @Test func tooFewFramesOrTooSlowAFrameRateIsUnknownNotGood() {
        var few = SetupMonitor()
        few.add(grid(100), at: 0)
        #expect(few.observation(exposureSeconds: nil).meanLuma != nil)
        #expect(few.observation(exposureSeconds: nil).motionScore == nil && few.observation(exposureSeconds: nil).flickerIndex == nil)
        var slow = SetupMonitor() // 30 fps cannot show 100 Hz flicker
        for n in 0 ..< 60 {
            slow.add(grid(100), at: Double(n) / 30)
        }
        #expect(slow.observation(exposureSeconds: nil).flickerIndex == nil && slow.observation(exposureSeconds: nil).motionScore != nil)
        #expect(SetupMonitor().observation(exposureSeconds: nil) == SetupObservation())
    }

    @Test func onlyTheLatestSecondCounts() {
        var monitor = SetupMonitor()
        for n in 0 ..< 240 {
            monitor.add(grid(n.isMultiple(of: 2) ? 0 : 255), at: Double(n) / 240)
        } // shaking
        for n in 240 ..< 720 {
            monitor.add(grid(100), at: Double(n) / 240)
        } // then still for 2 s
        #expect(monitor.observation(exposureSeconds: nil).motionScore == 0)
    }
}

struct SetupReadinessTests {
    func good() -> SetupObservation {
        SetupObservation(meanLuma: 0.45, clippedFraction: 0.01, motionScore: 0.5, flickerIndex: 0.005, exposureSeconds: 1.0 / 2000)
    }

    func context(
        mode: SetupMode = .scored,
        calibration: CalibrationState = .valid,
        status: CapabilityStatus = .experimental,
        handedness: SwingHandedness? = .right
    ) -> SetupContext {
        SetupContext(mode: mode, capability: status, handedness: handedness, calibration: calibration)
    }

    @Test func everythingGoodArmsAndScores() {
        let r = SetupReadiness.evaluate(good(), context())
        #expect(r.blockers.isEmpty && r.canArm && r.canScore && r.warnings.isEmpty)
    }

    @Test func eachProblemBlocksArmingWithItsOwnReasonAndAction() {
        func blockers(_ o: SetupObservation, _ c: SetupContext? = nil) -> [SetupBlocker] {
            SetupReadiness.evaluate(o, c ?? context()).blockers
        }
        var o = good(); o.motionScore = 20
        #expect(blockers(o) == [.deviceMoving])
        o = good(); o.meanLuma = 0.05
        #expect(blockers(o) == [.tooDark])
        o = good(); o.clippedFraction = 0.4
        #expect(blockers(o) == [.overexposed])
        o = good(); o.flickerIndex = 0.2
        #expect(blockers(o) == [.flickerLikely])
        o = good(); o.exposureSeconds = 1.0 / 200
        #expect(blockers(o) == [.exposureTooLong])
        #expect(blockers(SetupObservation()) == [.cameraNotRunning])
        #expect(blockers(good(), context(calibration: .none)) == [.notCalibrated])
        #expect(blockers(good(), context(calibration: .lost)) == [.calibrationLost])
        #expect(blockers(good(), context(handedness: nil)) == [.handednessMissing])
        #expect(blockers(good(), context(status: .unsupported)) == [.unsupportedDevice])
        for b in SetupBlocker.allCases {
            #expect(!b.actionKey.isEmpty && !b.reasonKey.isEmpty)
        } // reason AND action for each
    }

    /// One frame is not yet evidence of a stable phone: the check is still starting, so arming stays blocked.
    @Test func aSingleFrameIsNotYetReady() {
        let first = SetupObservation(meanLuma: 0.4, clippedFraction: 0, exposureSeconds: 1.0 / 2000)
        #expect(SetupReadiness.evaluate(first, context()).blockers == [.cameraNotRunning])
    }

    @Test func borderlineConditionsWarnButDoNotBlock() {
        var o = good(); o.flickerIndex = 0.03; o.exposureSeconds = 1.0 / 800
        let r = SetupReadiness.evaluate(o, context())
        #expect(r.canArm && Set(r.warnings) == [.flickerPossible, .exposureLong])
        var unknown = good(); unknown.flickerIndex = nil
        #expect(SetupReadiness.evaluate(unknown, context()).warnings == [.flickerNotChecked])
    }

    /// F02: a test setup is for trying placement. It may arm, and it can never produce a scored shot.
    @Test func modeCanArmWithoutCalibrationButNeverScores() {
        let r = SetupReadiness.evaluate(good(), context(mode: .test, calibration: .none))
        #expect(r.canArm && !r.canScore)
        // environment problems still block even a test
        var dark = good(); dark.meanLuma = 0.01
        #expect(!SetupReadiness.evaluate(dark, context(mode: .test, calibration: .none)).canArm)
    }

    @Test func blockersAreListedInAStableOrderAndAllAtOnce() {
        var o = good(); o.meanLuma = 0.01; o.motionScore = 30
        let r = SetupReadiness.evaluate(o, context(calibration: .none))
        #expect(r.blockers == [.notCalibrated, .deviceMoving, .tooDark])
    }
}

struct SetupStateTests {
    @Test func changingHandednessWithACalibrationNeedsConfirmationAndInvalidatesIt() {
        var s = SetupState(handedness: .right, calibration: .valid)
        #expect(s.requestHandedness(.left) == .needsConfirmation)
        #expect(s.handedness == .right && s.calibration == .valid && s.pendingHandedness == .left) // nothing changed yet
        s.cancelHandednessChange()
        #expect(s.pendingHandedness == nil && s.handedness == .right && s.calibration == .valid)
        _ = s.requestHandedness(.left)
        s.confirmHandednessChange()
        #expect(s.handedness == .left && s.calibration == .lost && s.pendingHandedness == nil)
    }

    @Test func withoutACalibrationTheChangeIsImmediate() {
        var s = SetupState(handedness: nil, calibration: .none)
        #expect(s.requestHandedness(.left) == .applied && s.handedness == .left && s.calibration == .none)
        #expect(s.requestHandedness(.left) == .unchanged)
    }

    @Test func choosingASideForTheFirstTimeNeverNeedsConfirmation() {
        var s = SetupState(handedness: nil, calibration: .valid)
        #expect(s.requestHandedness(.right) == .applied && s.handedness == .right && s.calibration == .valid)
    }

    @Test func movementOrAFormatChangeLosesACalibrationButNeverCreatesOne() {
        var s = SetupState(handedness: .right, calibration: .valid)
        s.invalidateCalibration()
        #expect(s.calibration == .lost)
        var none = SetupState(handedness: .right, calibration: .none)
        none.invalidateCalibration()
        #expect(none.calibration == .none)
    }
}

struct SetupChecksTests {
    private func rows(_ o: SetupObservation) -> [SetupCheck: SetupCheckState] {
        let ctx = SetupContext(mode: .test, capability: .experimental, handedness: .right, calibration: .none)
        let result = SetupReadiness.evaluate(o, ctx)
        return Dictionary(uniqueKeysWithValues: SetupChecks.rows(o, result).map { ($0.check, $0.state) })
    }

    @Test func allGood() {
        let r = rows(SetupObservation(
            meanLuma: 0.4,
            clippedFraction: 0,
            motionScore: 0.2,
            flickerIndex: 0.004,
            exposureSeconds: 1.0 / 2000
        ))
        #expect(r.values.allSatisfy { $0 == .good } && r.count == 5)
    }

    @Test func notMeasuredIsUnknownNeverGood() {
        let r = rows(SetupObservation())
        #expect(r[.camera] == .problem && r[.stable] == .unknown && r[.light] == .unknown && r[.shutter] == .unknown && r[.flicker] ==
            .unknown)
        let noFlicker = rows(SetupObservation(meanLuma: 0.4, clippedFraction: 0, motionScore: 0.2, exposureSeconds: 1.0 / 2000))
        #expect(noFlicker[.flicker] == .unknown && noFlicker[.stable] == .good)
    }

    @Test func problemsAndCautionsLandOnTheRightRow() {
        let r = rows(SetupObservation(meanLuma: 0.05, clippedFraction: 0, motionScore: 9, flickerIndex: 0.03, exposureSeconds: 1.0 / 800))
        #expect(r[.stable] == .problem && r[.light] == .problem && r[.flicker] == .check && r[.shutter] == .check)
    }
}

/// Fixture for the sign convention (F02): derived from where the target is relative to the golfer at address.
struct SetupDiagramTests {
    /// Positions on a map with +x = target direction (right on the page) and +y = up on the page.
    private func targetIsOnTheGolfersLeft(golfer: SetupDiagram.Side) -> Bool {
        let ball = (x: 0.0, y: 0.0), golferY = golfer == .top ? 1.0 : -1.0
        let facing = (x: ball.x - 0, y: ball.y - golferY) // the golfer looks at the ball
        let left = (x: -facing.y, y: facing.x) // 90 degrees counter-clockwise of the facing direction
        return left.x > 0 // the target (+x) is on that side
    }

    @Test func rightHandedGolferHasTheTargetOnTheirLeft() {
        #expect(targetIsOnTheGolfersLeft(golfer: SetupDiagram.golferSide(for: .right)))
        #expect(!targetIsOnTheGolfersLeft(golfer: SetupDiagram.golferSide(for: .left)))
    }

    @Test func phoneIsAlwaysOppositeTheGolferAndMirrorsWithHandedness() {
        for h in SwingHandedness.allCases {
            #expect(SetupDiagram.phoneSide(for: h) != SetupDiagram.golferSide(for: h))
        }
        #expect(SetupDiagram.golferSide(for: .right) != SetupDiagram.golferSide(for: .left))
    }
}
