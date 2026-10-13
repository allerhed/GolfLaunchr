import Domain
import Foundation

/// One plotted shot: carry (longitudinal) and lateral landing, both SI metres. Estimates, not GPS positions.
public struct DispersionPoint: Equatable, Sendable, Identifiable {
    public var id: UUID {
        shotID
    }

    public let shotID: UUID
    public let clubID: UUID
    public let longitudinalM: Double
    /// nil = lateral unknown: the shot may be plotted by distance only.
    public let lateralM: Double?
}

/// A 1-SD covariance ellipse. Not a coverage interval: it carries no 68%/95% promise.
public struct SpreadEllipse: Equatable, Sendable {
    public let centreLongitudinalM: Double
    public let centreLateralM: Double
    public let semiMajorM: Double
    public let semiMinorM: Double
    /// Rotation of the major axis from the longitudinal axis, radians.
    public let angleRad: Double
}

public enum Dispersion {
    public static func points(_ shots: [Shot], filter: AnalysisFilter, standardiser: Standardiser? = nil) -> [DispersionPoint] {
        shots.compactMap { shot in
            guard let d = ShotSelection.value(filter.distance.key, of: shot, view: filter.conditions, standardiser: standardiser) else {
                return nil
            }
            let lateral = ShotSelection.value(.lateralLanding, of: shot, view: filter.conditions, standardiser: standardiser)
            return DispersionPoint(shotID: shot.id, clubID: shot.clubSnapshot.id, longitudinalM: d, lateralM: lateral)
        }
    }

    /// Shortest axis divided by the longest below which a 2D shape is not drawn.
    public static let minimumAspectRatio = 0.1

    /// Needs at least three points with lateral values that are not (nearly) collinear; otherwise nil and the UI shows dots/1D spread.
    public static func ellipse(_ points: [DispersionPoint]) -> SpreadEllipse? {
        let pts = points.compactMap { p in p.lateralM.map { (x: p.longitudinalM, y: $0) } }
        guard pts.count >= 3 else { return nil }
        let n = Double(pts.count)
        let mx = pts.reduce(0) { $0 + $1.x } / n, my = pts.reduce(0) { $0 + $1.y } / n
        var sxx = 0.0, syy = 0.0, sxy = 0.0
        for p in pts {
            sxx += (p.x - mx) * (p.x - mx)
            syy += (p.y - my) * (p.y - my)
            sxy += (p.x - mx) * (p.y - my)
        }
        sxx /= n - 1; syy /= n - 1; sxy /= n - 1
        let trace = sxx + syy
        let det = sxx * syy - sxy * sxy
        guard trace > 0, det > 1e-9 * trace * trace else { return nil } // collinear or degenerate
        let disc = ((trace * trace) / 4 - det).squareRoot()
        let l1 = trace / 2 + disc, l2 = trace / 2 - disc
        // Almost-collinear points give a sliver that looks like a line and means nothing: show the dots only.
        guard l1 > 0, (l2 / l1).squareRoot() >= minimumAspectRatio else { return nil }
        let angle = 0.5 * atan2(2 * sxy, sxx - syy)
        return SpreadEllipse(
            centreLongitudinalM: mx, centreLateralM: my, semiMajorM: l1.squareRoot(), semiMinorM: l2.squareRoot(), angleRad: angle
        )
    }
}
