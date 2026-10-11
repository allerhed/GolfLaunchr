import Foundation

/// Descriptive statistics per spec F10a. Pure functions over SI values; non-finite values are omitted, never zero-filled.
public enum Statistics {
    public static func clean(_ xs: [Double?]) -> [Double] {
        xs.compactMap(\.self).filter(\.isFinite)
    }

    public static func mean(_ xs: [Double]) -> Double? {
        xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count)
    }

    /// Sample standard deviation (n-1). Unavailable (nil) for fewer than two samples.
    public static func sampleStandardDeviation(_ xs: [Double]) -> Double? {
        guard xs.count >= 2, let m = mean(xs) else { return nil }
        let ss = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (ss / Double(xs.count - 1)).squareRoot()
    }

    /// Linear-interpolation quantile (p in 0...1), the "type 7" definition.
    public static func quantile(_ xs: [Double], _ p: Double) -> Double? {
        guard !xs.isEmpty, (0 ... 1).contains(p) else { return nil }
        let s = xs.sorted()
        let h = Double(s.count - 1) * p
        let lo = Int(h.rounded(.down)), hi = Int(h.rounded(.up))
        return s[lo] + (h - Double(lo)) * (s[hi] - s[lo])
    }

    public static func median(_ xs: [Double]) -> Double? {
        quantile(xs, 0.5)
    }
}
