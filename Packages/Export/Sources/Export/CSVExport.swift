import Domain
import Foundation

/// Flat CSV, one row per shot, SI values only. A missing metric is an empty cell, never 0 (spec F17).
public enum CSVExport {
    static func unitSuffix(_ unit: MetricUnit) -> String {
        switch unit {
        case .metresPerSecond: "mps"
        case .radians: "rad"
        case .radiansPerSecond: "radps"
        case .metres: "m"
        case .dimensionless: "ratio"
        }
    }

    static let metricFields = ["", "_provenance", "_quality", "_uncertainty95", "_failure"]

    public static func header(options: ExportOptions) -> [String] {
        var cols = [
            "shot_id", "session_id", "sequence", "mode", "handedness", "club_id", "club_name", "club_loft_rad", "impact_time_utc",
            "included", "synthetic", "pressure_pa", "temperature_k", "conditions_source", "pipeline_version", "flight_version"
        ]
        if options.includeDeviceIdentifiers {
            cols.append("device_profile")
        }
        for key in MetricKey.allCases {
            let base = "\(key.rawValue)_\(unitSuffix(key.unit))"
            cols.append(base)
            cols.append(contentsOf: metricFields.dropFirst().map { "\(key.rawValue)\($0)" })
        }
        return cols
    }

    public static func string(_ snapshot: ExportSnapshot, options: ExportOptions, now _: Date) -> String {
        let filtered = snapshot.filtered(options)
        var lines = [header(options: options).map(escape).joined(separator: ",")]
        let formatter = ContractJSON.encoder() // dates use the contract encoding for consistency with JSON
        for shot in JSONExport.ordered(filtered.shots) {
            var cells: [String] = [
                shot.id.uuidString, shot.sessionID.uuidString, String(shot.sequence), shot.mode.rawValue, shot.swingHandedness.rawValue,
                shot.clubSnapshot.id.uuidString, text(shot.clubSnapshot.name), number(shot.clubSnapshot.loftRad),
                date(shot.impactTimeUTC, formatter), shot.included ? "true" : "false", shot.isSynthetic ? "true" : "false",
                number(shot.environment.pressurePa), number(shot.environment.temperatureK), shot.environment.source.rawValue,
                text(shot.versions.pipeline), text(shot.versions.flight)
            ]
            if options.includeDeviceIdentifiers {
                cells.append(text(shot.versions.deviceProfile))
            }
            for key in MetricKey.allCases {
                let m = shot.metrics[key]
                cells.append(number(m?.value))
                cells.append(m?.provenance.rawValue ?? "")
                cells.append(m?.quality.rawValue ?? "")
                cells.append(number(m?.uncertainty95))
                cells.append(m?.failure?.rawValue ?? "")
            }
            lines.append(cells.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Shortest decimal that reads back to the identical Double; locale independent. nil -> empty cell.
    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        return "\(value)"
    }

    /// Free text: formula-leading values are neutralised with a leading apostrophe, then quoted if needed.
    static func text(_ value: String) -> String {
        escape(value)
    }

    static func escape(_ raw: String) -> String {
        var value = raw
        if let first = value.unicodeScalars.first, ["=", "+", "-", "@", "\t", "\r"].contains(Character(first)) {
            value = "'" + value
        }
        if value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func date(_ d: Date, _: JSONEncoder) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }
}
