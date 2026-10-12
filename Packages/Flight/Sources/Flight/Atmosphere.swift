import Domain
import Foundation

/// Air density from the environment snapshot. Dry-air ideal gas law: rho = p / (R_d * T). Humidity is not modelled (it changes
/// density by well under 1% at golf conditions); this is stated, not hidden.
public enum Atmosphere {
    public static let specificGasConstantDryAir = 287.058 // J/(kg K)
    public static let standardPressurePa = 101_325.0
    public static let standardTemperatureK = 288.15

    /// The declared standard atmosphere at sea level (ISA): 1.2250 kg/m^3.
    public static func standard() throws(ContractError) -> Environment {
        try Environment(pressurePa: standardPressurePa, temperatureK: standardTemperatureK, source: .standard)
    }

    public static func density(_ environment: Environment) -> Double {
        environment.pressurePa / (specificGasConstantDryAir * environment.temperatureK)
    }
}
