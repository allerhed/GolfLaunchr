import Flight
import SwiftUI

extension AtmosphereSetting.Problem {
    var titleKey: LocalizedStringKey {
        switch self {
        case .missingPressure: "settings.atmosphere.problem.missingPressure"
        case .missingTemperature: "settings.atmosphere.problem.missingTemperature"
        case .pressureOutOfRange: "settings.atmosphere.problem.pressureOutOfRange"
        case .temperatureOutOfRange: "settings.atmosphere.problem.temperatureOutOfRange"
        }
    }
}
