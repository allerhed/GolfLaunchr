import Domain
import Foundation

/// Verified launch inputs. SI units; azimuth is positive to the right of the target line. Spin is optional because it is not
/// measured by default: a missing spin is never replaced by a club-table value (spec F06).
public struct LaunchInputs: Equatable, Sendable {
    public let ballSpeedMps: Double
    public let verticalLaunchRad: Double
    public let horizontalLaunchRad: Double
    /// Backspin magnitude in rad/s, or nil if unknown.
    public let backspinRadPerSec: Double?

    public init(ballSpeedMps: Double, verticalLaunchRad: Double, horizontalLaunchRad: Double = 0, backspinRadPerSec: Double? = nil)
        throws(FlightError) {
        guard ballSpeedMps.isFinite, ballSpeedMps > 0, ballSpeedMps <= 120 else { throw .invalidInput("ballSpeed") }
        guard verticalLaunchRad.isFinite, verticalLaunchRad > 0, verticalLaunchRad < .pi / 2 else { throw .invalidInput("verticalLaunch") }
        guard horizontalLaunchRad.isFinite, abs(horizontalLaunchRad) < .pi / 2 else { throw .invalidInput("horizontalLaunch") }
        if let backspinRadPerSec {
            guard backspinRadPerSec.isFinite, backspinRadPerSec >= 0 else { throw .invalidInput("backspin") }
        }
        self.ballSpeedMps = ballSpeedMps
        self.verticalLaunchRad = verticalLaunchRad
        self.horizontalLaunchRad = horizontalLaunchRad
        self.backspinRadPerSec = backspinRadPerSec
    }
}

public enum FlightError: Error, Equatable {
    case invalidInput(String)
    case didNotLand
}

/// How the result must be read.
public enum FlightAssumption: String, Codable, Sendable {
    /// No spin was supplied, so lift is zero: carry is a lower bound, not an estimate of the real flight.
    case spinUnknownNoLift
    /// Spin axis is not modelled (it is unavailable): no curvature is produced.
    case noSpinAxisCurvature
    /// Total distance is not produced: there is no validated surface/runout model.
    case noRunoutModel
}

public struct FlightResult: Equatable, Sendable {
    public let modelVersion: String
    public let environment: Environment
    public let airDensity: Double
    public let carryM: Double
    public let apexM: Double
    public let flightTimeS: Double
    /// Landing offset from the target line, right positive, from the launch azimuth only.
    public let lateralLandingM: Double
    public let landingAngleRad: Double
    public let assumptions: [FlightAssumption]
    /// True when the carry is only a lower bound (spin unknown).
    public var isLowerBound: Bool {
        assumptions.contains(.spinUnknownNoLift)
    }

    /// The results as stored metrics: estimated, provisional, never measured. A lower-bound carry is not stored as a carry.
    public func measurements() throws(ContractError) -> [MetricKey: Domain.Measurement] {
        var out: [MetricKey: Domain.Measurement] = [:]
        out[.apex] = try Domain.Measurement(key: .apex, value: apexM, provenance: .estimated, quality: .provisional)
        out[.lateralLanding] = try Domain.Measurement(
            key: .lateralLanding,
            value: lateralLandingM,
            provenance: .estimated,
            quality: .provisional
        )
        out[.carry] = isLowerBound
            ? Domain.Measurement.unavailable(.carry, failure: .unsupportedMetric)
            : try Domain.Measurement(key: .carry, value: carryM, provenance: .estimated, quality: .provisional)
        out[.totalDistance] = Domain.Measurement.unavailable(.totalDistance, failure: .unsupportedMetric)
        return out
    }
}

/// Point-mass ball flight with quadratic drag and Magnus lift, integrated with RK4. UNVALIDATED: coefficients are a generic
/// published-form approximation, not fitted to this app's data. Nothing here may be marketed before gate G2.
public enum FlightModel {
    public static let version = "flight-0.1-unvalidated"
    static let mass = 0.04593 // kg (USGA max)
    static let radius = 0.02135 // m
    static let gravity = 9.80665
    static let dragCoefficient = 0.25
    static let step = 0.001 // s

    /// Lift coefficient from the spin parameter S = r*omega/v: a saturating power law, capped at 0.30.
    static func liftCoefficient(spin: Double, speed: Double) -> Double {
        guard spin > 0, speed > 0 else { return 0 }
        return min(0.30, 0.40 * pow(radius * spin / speed, 0.4))
    }

    public static func compute(_ inputs: LaunchInputs, environment: Environment) throws(FlightError) -> FlightResult {
        let rho = Atmosphere.density(environment)
        let area = Double.pi * radius * radius
        let spin = inputs.backspinRadPerSec
        let cosV = cos(inputs.verticalLaunchRad), sinV = sin(inputs.verticalLaunchRad)
        let cosH = cos(inputs.horizontalLaunchRad), sinH = sin(inputs.horizontalLaunchRad)
        // x forward (target line), y up, z right.
        var s = State(
            x: 0,
            y: 0,
            z: 0,
            vx: inputs.ballSpeedMps * cosV * cosH,
            vy: inputs.ballSpeedMps * sinV,
            vz: inputs.ballSpeedMps * cosV * sinH
        )
        let dirX = cosH, dirZ = sinH // horizontal launch direction d
        // Backspin axis a = d x up: horizontal, perpendicular to the launch direction, fixed in space (no decay, no tilt).
        let a = cross(Vec3(x: dirX, y: 0, z: dirZ), Vec3(x: 0, y: 1, z: 0)) // d x y

        func accel(_ s: State) -> Vec3 {
            let v = (s.vx * s.vx + s.vy * s.vy + s.vz * s.vz).squareRoot()
            var f = Vec3(
                x: -0.5 * rho * area * dragCoefficient * v * s.vx,
                y: -0.5 * rho * area * dragCoefficient * v * s.vy,
                z: -0.5 * rho * area * dragCoefficient * v * s.vz
            )
            if let spin, v > 0 {
                let cl = liftCoefficient(spin: spin, speed: v)
                let m = cross(a, Vec3(x: s.vx / v, y: s.vy / v, z: s.vz / v)) // a x v-hat: perpendicular to velocity and to the axis
                let n = (m.x * m.x + m.y * m.y + m.z * m.z).squareRoot()
                if n > 1e-12 {
                    let k = 0.5 * rho * area * cl * v * v / n
                    f = Vec3(x: f.x + k * m.x, y: f.y + k * m.y, z: f.z + k * m.z)
                }
            }
            return Vec3(x: f.x / mass, y: f.y / mass - gravity, z: f.z / mass)
        }

        var apex = 0.0, t = 0.0
        for _ in 0 ..< 60000 { // 60 s cap
            let next = rk4(s, dt: step, accel: accel)
            t += step
            apex = max(apex, next.y)
            if next.y <= 0, s.y > 0 || t > step {
                let f = s.y / (s.y - next.y) // linear interpolation to the ground crossing
                let hx = s.x + f * (next.x - s.x), hz = s.z + f * (next.z - s.z)
                let vyLand = s.vy + f * (next.vy - s.vy), vhLand = (pow(s.vx + f * (next.vx - s.vx), 2) + pow(
                    s.vz + f * (next.vz - s.vz),
                    2
                )).squareRoot()
                var assumptions: [FlightAssumption] = [.noSpinAxisCurvature, .noRunoutModel]
                if spin == nil {
                    assumptions.insert(.spinUnknownNoLift, at: 0)
                }
                return FlightResult(
                    modelVersion: version, environment: environment, airDensity: rho, carryM: hx, apexM: apex,
                    flightTimeS: t - step + f * step, lateralLandingM: hz, landingAngleRad: atan2(-vyLand, vhLand), assumptions: assumptions
                )
            }
            s = next
        }
        throw .didNotLand
    }

    struct Vec3 {
        var x, y, z: Double
    }

    struct State {
        var x, y, z, vx, vy, vz: Double
    }

    private static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x)
    }

    private static func rk4(_ s: State, dt: Double, accel: (State) -> Vec3) -> State {
        func deriv(_ s: State) -> State {
            let a = accel(s)
            return State(x: s.vx, y: s.vy, z: s.vz, vx: a.x, vy: a.y, vz: a.z)
        }
        func add(_ s: State, _ d: State, _ h: Double) -> State {
            State(x: s.x + h * d.x, y: s.y + h * d.y, z: s.z + h * d.z, vx: s.vx + h * d.vx, vy: s.vy + h * d.vy, vz: s.vz + h * d.vz)
        }
        let k1 = deriv(s), k2 = deriv(add(s, k1, dt / 2)), k3 = deriv(add(s, k2, dt / 2)), k4 = deriv(add(s, k3, dt))
        func comb(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            (a + 2 * b + 2 * c + d) / 6
        }
        return State(
            x: s.x + dt * comb(k1.x, k2.x, k3.x, k4.x), y: s.y + dt * comb(k1.y, k2.y, k3.y, k4.y), z: s.z + dt * comb(
                k1.z,
                k2.z,
                k3.z,
                k4.z
            ),
            vx: s.vx + dt * comb(k1.vx, k2.vx, k3.vx, k4.vx), vy: s.vy + dt * comb(k1.vy, k2.vy, k3.vy, k4.vy),
            vz: s.vz + dt * comb(k1.vz, k2.vz, k3.vz, k4.vz)
        )
    }
}
