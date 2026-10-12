import Foundation

public enum ClubValidationError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLong
    case duplicateActiveName
    case loftNotFinite
    case loftOutOfRange
    case unknownClub
    /// The club is archived: it cannot be edited or archived again.
    case archived
    /// The club is active: there is nothing to restore.
    case notArchived
}

/// Loft rule (F08: "custom loft rejects non-finite and nonsensical values"). Degrees in, radians out.
/// 1...70 degrees is a documented product decision (see DECISIONS.md); a putter's loft may simply be left unset.
public enum LoftRule {
    public static let minDegrees = 1.0
    public static let maxDegrees = 70.0

    /// nil means "not set" and is always valid. Returns the loft in radians.
    public static func validate(degrees: Double?) throws(ClubValidationError) -> Double? {
        guard let degrees else { return nil }
        guard degrees.isFinite else { throw .loftNotFinite }
        guard degrees >= minDegrees, degrees <= maxDegrees else { throw .loftOutOfRange }
        return degrees * .pi / 180
    }
}

public enum ClubName {
    public static let maxLength = 40

    /// Trimmed name, 1...40 characters.
    public static func normalized(_ raw: String) throws(ClubValidationError) -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw .emptyName }
        guard name.count <= maxLength else { throw .nameTooLong }
        return name
    }

    /// Case- and diacritic-insensitive comparison ("Jarn 7" equals "Järn 7").
    public static func matches(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == .orderedSame
    }
}
