import Domain
import Foundation

/// A formatted metric split so UI can style number and unit separately.
public struct FormattedMetric: Sendable, Equatable {
    public let number: String
    public let unit: String

    /// "130 m", "6 000 rpm" (locale spacing). Unit-less metrics return just the number.
    public var text: String {
        unit.isEmpty ? number : "\(number)\u{00A0}\(unit)"
    }
}

/// The one formatting layer for screens, accessibility labels and (later) speech (F18). Takes SI values only.
/// Unavailable (nil / non-finite) is never rendered as 0: `format` returns nil and callers show the localised "unavailable" text.
public struct MetricFormatter: Sendable {
    public let units: DisplayUnits
    public let locale: Locale

    public init(units: DisplayUnits, locale: Locale) {
        self.units = units
        self.locale = locale
    }

    public func fractionDigits(for key: MetricKey) -> Int {
        switch key {
        case .carry, .totalDistance, .spinRate: 0
        case .smashFactor: 2
        default: 1
        }
    }

    public func format(_ si: Double?, for key: MetricKey) -> FormattedMetric? {
        guard let si, si.isFinite else { return nil }
        let shown = UnitConversion.display(si, for: key, units: units)
        return FormattedMetric(
            number: number(shown, fractionDigits: fractionDigits(for: key)),
            unit: UnitConversion.symbol(for: key, units: units)
        )
    }

    /// Locale-aware number with fixed fraction digits (Swedish uses a decimal comma). Negative zero is shown as zero.
    public func number(_ value: Double, fractionDigits: Int) -> String {
        let cleaned = value == 0 ? 0 : value
        return cleaned.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
    }
}
