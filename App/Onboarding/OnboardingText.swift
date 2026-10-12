import Capture
import SwiftUI

extension CapabilityStatus {
    var titleKey: LocalizedStringKey {
        switch self {
        case .supported: "capability.supported"
        case .experimental: "capability.experimental"
        case .unsupported: "capability.unsupported"
        }
    }

    var explanationKey: LocalizedStringKey {
        switch self {
        case .supported: "capability.supported.explain"
        case .experimental: "capability.experimental.explain"
        case .unsupported: "capability.unsupported.explain"
        }
    }

    /// Status is never colour-only: each has its own symbol and word.
    var symbol: String {
        switch self {
        case .supported: "checkmark.seal.fill"
        case .experimental: "flask.fill"
        case .unsupported: "xmark.octagon.fill"
        }
    }
}

extension CapabilityReason {
    var titleKey: LocalizedStringKey {
        switch self {
        case .osTooOld: "capability.reason.osTooOld"
        case .noCamera: "capability.reason.noCamera"
        case .noHighFrameRate: "capability.reason.noHighFrameRate"
        case .storageCritical: "capability.reason.storageCritical"
        case .belowValidatedFrameRate: "capability.reason.belowValidatedFrameRate"
        case .noValidatedProfile: "capability.reason.noValidatedProfile"
        case .storageLow: "capability.reason.storageLow"
        }
    }
}
