#if CAPTURE_HARNESS
    import Foundation

    /// Unattended run for measuring steady-state capture behaviour without tapping: DEBUG HARNESS ONLY.
    /// Launch arguments: `-harnessAutorun <seconds> [-harnessExposure auto|1000|2000|4000] [-harnessTrigger manual|motion]
    /// [-harnessSaveEvery <seconds>]`. The run saves a clip every `saveEvery` seconds, writes `autorun-*.json`, then exits.
    struct HarnessAutorunConfig: Equatable {
        var seconds: Double
        var exposure: ExposurePreset
        var trigger: TriggerMode
        var saveEvery: Double
        /// "wide", "ultraWide" or nil for the first ranked format.
        var lens: String?
        /// Encoder hard cap in Mbit/s, nil for none.
        var maxMbit: Int?

        static func parse(_ args: [String]) -> HarnessAutorunConfig? {
            func value(_ flag: String) -> String? {
                guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
                return args[i + 1]
            }
            guard let raw = value("-harnessAutorun"), let seconds = Double(raw), seconds > 0, seconds.isFinite else { return nil }
            let exposure = value("-harnessExposure")
                .flatMap { name in ExposurePreset.allCases.first { $0.rawValue.hasSuffix(name) } } ?? .auto
            let trigger = value("-harnessTrigger").flatMap(TriggerMode.init(rawValue:)) ?? .manual
            let saveEvery = value("-harnessSaveEvery").flatMap(Double.init) ?? 10
            return HarnessAutorunConfig(
                seconds: seconds, exposure: exposure, trigger: trigger, saveEvery: max(saveEvery, 1),
                lens: value("-harnessLens"), maxMbit: value("-harnessMaxMbit").flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
            )
        }

        static var current: HarnessAutorunConfig? {
            parse(CommandLine.arguments)
        }
    }

    /// Result of an autorun, written next to the clips.
    struct AutorunSummary: Codable {
        var startedUTC: Date
        var requestedSeconds: Double
        var format: String
        var exposureMode: String
        var exposurePlan: String?
        var trigger: String
        var frames: Int
        var gapEvents: Int
        var missingFrames: Int
        var droppedByReason: [String: Int]
        var callbackMeanMs: Double?
        var callbackP99Ms: Double?
        var callbackMaxMs: Double
        var callbackOverBudgetFraction: Double?
        var encoderMaxBacklog: Int
        var meanFrameKB: Double?
        var maxFrameKB: Double
        var maxMbitCap: Int?
        var meanMbit: Double?
        var encodeCallMeanMs: Double?
        var encodeCallP99Ms: Double?
        var encodeCallMaxMs: Double
        var worstThermal: String?
        var clipsSaved: Int
        var deviceOrientation: String
        var error: String?
    }
#endif
