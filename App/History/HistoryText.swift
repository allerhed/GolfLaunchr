import Analytics
import Domain
import SwiftUI

extension ShotMode {
    var titleKey: LocalizedStringKey {
        switch self {
        case .practice: "mode.practice"
        case .quickShot: "mode.quickShot"
        case .bagMapping: "mode.bagMapping"
        case .target: "mode.target"
        case .ladder: "mode.ladder"
        case .round: "mode.round"
        }
    }
}

extension MetricKey {
    var titleKey: LocalizedStringKey {
        switch self {
        case .ballSpeed: "metric.ballSpeed"
        case .clubSpeed: "metric.clubSpeed"
        case .verticalLaunch: "metric.verticalLaunch"
        case .horizontalLaunch: "metric.horizontalLaunch"
        case .spinRate: "metric.spinRate"
        case .spinAxis: "metric.spinAxis"
        case .carry: "metric.carry"
        case .totalDistance: "metric.totalDistance"
        case .smashFactor: "metric.smashFactor"
        case .attackAngle: "metric.attackAngle"
        case .dynamicLoft: "metric.dynamicLoft"
        case .apex: "metric.apex"
        case .lateralLanding: "metric.lateralLanding"
        }
    }
}

extension Provenance {
    /// Measured / derived / estimated / unavailable are always spelled out (spec F06): colour is never the only signal.
    var titleKey: LocalizedStringKey {
        switch self {
        case .measured: "provenance.measured"
        case .derived: "provenance.derived"
        case .estimated: "provenance.estimated"
        case .unavailable: "provenance.unavailable"
        }
    }
}

extension MetricQuality {
    var titleKey: LocalizedStringKey {
        switch self {
        case .valid: "quality.valid"
        case .provisional: "quality.provisional"
        case .unsupported: "quality.unsupported"
        case .invalid: "quality.invalid"
        }
    }
}

extension MeasurementFailure {
    var titleKey: LocalizedStringKey {
        switch self {
        case .unsupportedProfile: "failure.unsupportedProfile"
        case .calibrationInvalid: "failure.calibrationInvalid"
        case .insufficientLight: "failure.insufficientLight"
        case .blur: "failure.blur"
        case .frameGap: "failure.frameGap"
        case .occlusion: "failure.occlusion"
        case .ambiguousBall: "failure.ambiguousBall"
        case .incompleteTrack: "failure.incompleteTrack"
        case .unsupportedMetric: "failure.unsupportedMetric"
        case .thermalPause: "failure.thermalPause"
        case .storageFailure: "failure.storageFailure"
        case .unknown: "failure.unknown"
        }
    }
}

extension TimeRange {
    var titleKey: LocalizedStringKey {
        switch self {
        case .allTime: "history.range.allTime"
        case .last7Days: "history.range.last7Days"
        case .last30Days: "history.range.last30Days"
        }
    }
}
