import Foundation

/// A club's look in plots and rows: a colour slot AND a symbol, so no club is told apart by colour alone (F10a, F22).
public struct ClubStyle: Equatable, Sendable {
    public let colourSlot: Int
    public let symbolIndex: Int

    public static let colourCount = 8
    public static let symbolCount = 6

    /// Style by position in the shown order (bag order): stable for the same selection, and distinct for the first 24 clubs (8 colours x 6
    /// symbols, coprime steps).
    public static func forPosition(_ position: Int) -> ClubStyle {
        let p = max(position, 0)
        return ClubStyle(colourSlot: p % colourCount, symbolIndex: p % symbolCount)
    }
}

/// Two-letter badge for a club name ("7 iron" -> "7I", "Driver" -> "DR"). Display only; the club's id stays the identity.
public enum ClubBadge {
    public static func text(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let words = trimmed.split(separator: " ")
        if words.count >= 2, let first = words.first?.first, let second = words.dropFirst().first?.first {
            return "\(first)\(second)".uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }
}
