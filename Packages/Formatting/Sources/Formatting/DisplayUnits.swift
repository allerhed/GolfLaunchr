import Domain
import Foundation

public enum DistanceUnit: String, Codable, Sendable, CaseIterable {
    case metres, yards

    var metresPerUnit: Double {
        switch self {
        case .metres: 1
        case .yards: 0.9144
        }
    }

    public var symbol: String {
        switch self {
        case .metres: "m"
        case .yards: "yd"
        }
    }
}

public enum SpeedUnit: String, Codable, Sendable, CaseIterable {
    case metresPerSecond, kilometresPerHour, milesPerHour

    var metresPerSecondPerUnit: Double {
        switch self {
        case .metresPerSecond: 1
        case .kilometresPerHour: 1 / 3.6
        case .milesPerHour: 0.44704
        }
    }

    public var symbol: String {
        switch self {
        case .metresPerSecond: "m/s"
        case .kilometresPerHour: "km/h"
        case .milesPerHour: "mph"
        }
    }
}

/// User-chosen display units. Language and units are separate settings (F25); storage is always SI.
/// Angles are always degrees and spin always rpm on screen.
public struct DisplayUnits: Codable, Sendable, Equatable {
    public var distance: DistanceUnit
    public var speed: SpeedUnit

    public init(distance: DistanceUnit, speed: SpeedUnit) {
        self.distance = distance
        self.speed = speed
    }

    /// Regional default (not language based): US gets yards and mph, everywhere else metres and km/h.
    public static func defaults(for locale: Locale) -> DisplayUnits {
        locale.region == .unitedStates ? DisplayUnits(distance: .yards, speed: .milesPerHour) : DisplayUnits(
            distance: .metres,
            speed: .kilometresPerHour
        )
    }
}

/// Pure SI <-> display conversion. Display rounding happens only in `MetricFormatter`, never here.
public enum UnitConversion {
    public static func display(_ si: Double, for key: MetricKey, units: DisplayUnits) -> Double {
        switch key.unit {
        case .metres: si / units.distance.metresPerUnit
        case .metresPerSecond: si / units.speed.metresPerSecondPerUnit
        case .radians: si * 180 / .pi
        case .radiansPerSecond: si * 60 / (2 * .pi)
        case .dimensionless: si
        }
    }

    public static func si(_ shown: Double, for key: MetricKey, units: DisplayUnits) -> Double {
        switch key.unit {
        case .metres: shown * units.distance.metresPerUnit
        case .metresPerSecond: shown * units.speed.metresPerSecondPerUnit
        case .radians: shown * .pi / 180
        case .radiansPerSecond: shown * 2 * .pi / 60
        case .dimensionless: shown
        }
    }

    public static func symbol(for key: MetricKey, units: DisplayUnits) -> String {
        switch key.unit {
        case .metres: units.distance.symbol
        case .metresPerSecond: units.speed.symbol
        case .radians: "°"
        case .radiansPerSecond: "rpm"
        case .dimensionless: ""
        }
    }
}
