import Foundation

/// One CSV row per saved clip (garage or bay sessions), written next to the clips so they can be paired with the reference launch
/// monitor's own export, block by block and in order. Missing values are empty cells, never zero.
public enum SessionLog {
    public static let fileName = "session-log.csv"

    public static let columns = [
        "createdUTC", "block", "seq", "kind", "club", "ball", "golfer", "handedness", "preset", "exposureS", "iso", "distanceM",
        "heightM", "lighting", "location", "trigger", "reference", "frames", "missingFrames", "complete", "notes", "clip",
    ]

    public static var header: String {
        columns.joined(separator: ",")
    }

    public static func row(_ manifest: CaptureManifest, clipStem: String, exposurePreset: String) -> String {
        let shot = manifest.shot
        let setup = manifest.setup
        let exposure = manifest.exposureSetting
        let utc = ISO8601DateFormatter().string(from: manifest.createdUTC)
        let values: [String?] = [
            utc, shot?.block, shot?.sequenceInBlock.map(String.init), shot?.recordingKind, shot?.club, shot?.ball, shot?.golferID,
            setup?.handedness, exposurePreset, exposure?.appliedDurationSeconds.map(number), exposure?.appliedISO.map(number),
            setup?.distanceToBallM.map(number), setup?.cameraHeightM.map(number), shot?.lighting, shot?.location, shot?.trigger,
            manifest.reference?.instrument, String(manifest.timing.frameCount), String(manifest.timing.missingFrames),
            manifest.isComplete ? "true" : "false", shot?.outcomeNotes, clipStem,
        ]
        return values.map { quote($0 ?? "") }.joined(separator: ",")
    }

    /// Plain decimal with a full stop, whatever the phone's region (read by tools): 800, 1, 0.0005.
    static func number(_ value: Double) -> String {
        let text = String(value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    static func quote(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// RFC 4180 split of one row (quoted fields may contain commas, quotes and line breaks). Used by tests and tools.
    public static func split(_ row: String) -> [String] {
        var fields: [String] = [], current = "", inQuotes = false
        var chars = Array(row)[...]
        while let c = chars.popFirst() {
            if inQuotes {
                if c == "\"" {
                    if chars.first == "\"" {
                        current.append("\"")
                        chars.removeFirst()
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        fields.append(current)
        return fields
    }

    /// Appends one row, writing the header first if the file is new.
    public static func append(_ row: String, to file: URL) throws {
        let line = row + "\n"
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } else {
            try Data((header + "\n" + line).utf8).write(to: file, options: .atomic)
        }
    }
}
