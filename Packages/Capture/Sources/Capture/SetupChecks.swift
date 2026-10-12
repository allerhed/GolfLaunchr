import Domain
import Foundation

public enum SetupCheck: String, CaseIterable, Sendable {
    case camera, stable, light, shutter, flicker
}

public enum SetupCheckState: String, Sendable {
    case good, check, problem, unknown
}

public struct SetupCheckRow: Equatable, Sendable {
    public let check: SetupCheck
    public let state: SetupCheckState
}

public enum SetupChecks {
    /// One row per live check for the checklist. Not measured is `unknown`, never `good`.
    public static func rows(_ o: SetupObservation, _ result: SetupReadinessResult) -> [SetupCheckRow] {
        let b = Set(result.blockers), w = Set(result.warnings)
        func row(_ check: SetupCheck, _ state: SetupCheckState) -> SetupCheckRow {
            SetupCheckRow(check: check, state: state)
        }
        let started = !b.contains(.cameraNotRunning)
        return [
            row(.camera, started ? .good : .problem),
            row(.stable, !started ? .unknown : b.contains(.deviceMoving) ? .problem : .good),
            row(.light, !started ? .unknown : (b.contains(.tooDark) || b.contains(.overexposed)) ? .problem : .good),
            row(
                .shutter,
                !started || o.exposureSeconds == nil ? .unknown : b.contains(.exposureTooLong) ? .problem
                    : w.contains(.exposureLong) ? .check : .good
            ),
            row(
                .flicker,
                !started || o.flickerIndex == nil ? .unknown : b.contains(.flickerLikely) ? .problem
                    : w.contains(.flickerPossible) ? .check : .good
            ),
        ]
    }
}

/// Top-down diagram geometry (F02): the target line runs left to right with the target on the right; golfer and phone stand on
/// opposite sides of the ball. A right-handed golfer has the target on their LEFT, so they stand on the far (top) side; a left-hander
/// mirrors it. Derived from the address position, not copied from a picture.
public enum SetupDiagram {
    public enum Side: String, Sendable {
        case top, bottom
    }

    public static func golferSide(for handedness: SwingHandedness) -> Side {
        handedness == .right ? .top : .bottom
    }

    public static func phoneSide(for handedness: SwingHandedness) -> Side {
        golferSide(for: handedness) == .top ? .bottom : .top
    }
}
