import Foundation

/// Locale-aware parsing of typed numbers (T19: Swedish decimal comma).
public enum NumberInput {
    /// Returns nil for empty, non-numeric, NaN or infinite input.
    /// Rule: spaces and the locale's group separator are ignored; the locale's decimal separator is the decimal point;
    /// a single "." or "," that is not the locale's group separator is also accepted as the decimal point
    /// (so "56.5" works in Swedish, while "1,234" in English is 1234).
    public static func parse(_ text: String, locale: Locale) -> Double? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\u{2212}", with: "-") // Swedish typographic minus
        s = s.filter { !$0.isWhitespace }
        guard !s.isEmpty else { return nil }
        let decimal = locale.decimalSeparator ?? "."
        let group = locale.groupingSeparator.map { $0.filter { !$0.isWhitespace } } ?? ""
        if s.contains(decimal) {
            if !group.isEmpty, group != decimal {
                s = s.replacingOccurrences(of: group, with: "")
            }
            s = s.replacingOccurrences(of: decimal, with: ".")
        } else {
            let others = [".", ","].filter { $0 != group && s.contains($0) }
            if let other = others.first, s.filter({ String($0) == other }).count == 1 {
                s = s.replacingOccurrences(of: other, with: ".")
            } else if !group.isEmpty {
                s = s.replacingOccurrences(of: group, with: "")
            }
        }
        guard let value = Double(s), value.isFinite else { return nil }
        return value
    }
}
