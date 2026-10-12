import Capture
import SwiftUI

extension SetupCheck {
    var titleKey: LocalizedStringKey {
        switch self {
        case .camera: "setup.check.camera"
        case .stable: "setup.check.stable"
        case .light: "setup.check.light"
        case .shutter: "setup.check.shutter"
        case .flicker: "setup.check.flicker"
        }
    }
}

extension SetupCheckState {
    var titleKey: LocalizedStringKey {
        switch self {
        case .good: "setup.state.good"
        case .check: "setup.state.check"
        case .problem: "setup.state.problem"
        case .unknown: "setup.state.unknown"
        }
    }

    /// Every state has its own symbol: never colour alone.
    var symbol: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .check: "exclamationmark.circle.fill"
        case .problem: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

extension SetupBlocker {
    var reason: LocalizedStringKey {
        LocalizedStringKey(reasonKey)
    }

    var action: LocalizedStringKey {
        LocalizedStringKey(actionKey)
    }
}

extension SetupWarning {
    var reason: LocalizedStringKey {
        LocalizedStringKey(reasonKey)
    }
}
