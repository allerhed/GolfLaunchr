import Domain
import Foundation

public enum SetupMode: String, Sendable {
    /// Placement practice: may arm, never produces a scored shot or spends credit (F02).
    case test
    case scored
}

public enum CalibrationState: String, Sendable {
    case none, valid
    /// Was valid, then invalidated (phone moved, format or handedness changed).
    case lost
}

public struct SetupContext: Equatable, Sendable {
    public let mode: SetupMode
    public let capability: CapabilityStatus
    public let handedness: SwingHandedness?
    public let calibration: CalibrationState

    public init(mode: SetupMode, capability: CapabilityStatus, handedness: SwingHandedness?, calibration: CalibrationState) {
        self.mode = mode
        self.capability = capability
        self.handedness = handedness
        self.calibration = calibration
    }
}

/// Why capture cannot be armed. Every blocker has a reason and an action (localisation keys derive from the case name).
public enum SetupBlocker: String, CaseIterable, Sendable {
    case unsupportedDevice, handednessMissing, notCalibrated, calibrationLost
    case cameraNotRunning, deviceMoving, tooDark, overexposed, flickerLikely, exposureTooLong

    public var reasonKey: String {
        "setup.blocker.\(rawValue).reason"
    }

    public var actionKey: String {
        "setup.blocker.\(rawValue).action"
    }
}

public enum SetupWarning: String, CaseIterable, Sendable {
    case flickerPossible, flickerNotChecked, exposureLong

    public var reasonKey: String {
        "setup.warning.\(rawValue).reason"
    }
}

public struct SetupReadinessResult: Equatable, Sendable {
    public let blockers: [SetupBlocker]
    public let warnings: [SetupWarning]
    public let mode: SetupMode

    public var canArm: Bool {
        blockers.isEmpty
    }

    /// A test setup never scores, however good the scene.
    public var canScore: Bool {
        canArm && mode == .scored
    }
}

/// Thresholds are provisional research defaults: G1 (real bay light, real clips) must set them. They live in one place.
public enum SetupThresholds {
    public static let darkBelow = 0.12
    public static let clippedAbove = 0.20
    public static let movingAbove = 4.0
    public static let flickerLikelyAbove = 0.05
    public static let flickerPossibleAbove = 0.02
    public static let exposureBlockAbove = 1.0 / 500
    public static let exposureWarnAbove = 1.0 / 1000
}

public enum SetupReadiness {
    public static func evaluate(_ o: SetupObservation, _ context: SetupContext) -> SetupReadinessResult {
        var blockers = contextBlockers(context)
        var warnings: [SetupWarning] = []
        if o.meanLuma == nil || o.motionScore == nil {
            blockers.append(.cameraNotRunning) // nothing measured yet is never "good"
        } else {
            let scene = sceneFindings(o)
            blockers.append(contentsOf: scene.blockers)
            warnings = scene.warnings
        }
        return SetupReadinessResult(blockers: blockers, warnings: warnings, mode: context.mode)
    }

    private static func contextBlockers(_ context: SetupContext) -> [SetupBlocker] {
        var blockers: [SetupBlocker] = []
        if context.capability == .unsupported {
            blockers.append(.unsupportedDevice)
        }
        if context.handedness == nil {
            blockers.append(.handednessMissing)
        }
        if context.mode == .scored {
            switch context.calibration {
            case .none: blockers.append(.notCalibrated)
            case .lost: blockers.append(.calibrationLost)
            case .valid: break
            }
        }
        return blockers
    }

    private static func sceneFindings(_ o: SetupObservation) -> (blockers: [SetupBlocker], warnings: [SetupWarning]) {
        var blockers: [SetupBlocker] = []
        var warnings: [SetupWarning] = []
        if (o.motionScore ?? 0) > SetupThresholds.movingAbove {
            blockers.append(.deviceMoving)
        }
        if (o.meanLuma ?? 1) < SetupThresholds.darkBelow {
            blockers.append(.tooDark)
        }
        if (o.clippedFraction ?? 0) > SetupThresholds.clippedAbove {
            blockers.append(.overexposed)
        }
        if let flicker = o.flickerIndex {
            if flicker > SetupThresholds.flickerLikelyAbove {
                blockers.append(.flickerLikely)
            } else if flicker > SetupThresholds.flickerPossibleAbove {
                warnings.append(.flickerPossible)
            }
        } else {
            warnings.append(.flickerNotChecked)
        }
        if let exposure = o.exposureSeconds {
            if exposure > SetupThresholds.exposureBlockAbove {
                blockers.append(.exposureTooLong)
            } else if exposure > SetupThresholds.exposureWarnAbove {
                warnings.append(.exposureLong)
            }
        }
        return (blockers, warnings)
    }
}

public enum HandednessChange: Equatable, Sendable {
    case unchanged, applied, needsConfirmation
}

/// Handedness and calibration travel together: a calibration made for one swing side is not valid for the other, so changing the side
/// while calibrated needs explicit confirmation and then forces recalibration (F02).
public struct SetupState: Equatable, Sendable {
    public private(set) var handedness: SwingHandedness?
    public private(set) var calibration: CalibrationState
    public private(set) var pendingHandedness: SwingHandedness?

    public init(handedness: SwingHandedness?, calibration: CalibrationState) {
        self.handedness = handedness
        self.calibration = calibration
    }

    public mutating func requestHandedness(_ new: SwingHandedness) -> HandednessChange {
        guard new != handedness else { return .unchanged }
        if calibration == .valid, handedness != nil { // choosing a side for the first time is not a change
            pendingHandedness = new
            return .needsConfirmation
        }
        handedness = new
        return .applied
    }

    public mutating func confirmHandednessChange() {
        guard let pending = pendingHandedness else { return }
        handedness = pending
        pendingHandedness = nil
        invalidateCalibration()
    }

    public mutating func cancelHandednessChange() {
        pendingHandedness = nil
    }

    /// Movement, a format change or a handedness change lose a calibration. Nothing here can create one.
    public mutating func invalidateCalibration() {
        if calibration == .valid {
            calibration = .lost
        }
    }
}
