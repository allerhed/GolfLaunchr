import Domain
@testable import Formatting
import Foundation
import Testing

let en = Locale(identifier: "en_US")
let sv = Locale(identifier: "sv_SE")
let metric = DisplayUnits(distance: .metres, speed: .kilometresPerHour)
let imperial = DisplayUnits(distance: .yards, speed: .milesPerHour)

struct ConversionTests {
    /// T01: SI values survive a display round trip in every unit.
    @Test(arguments: MetricKey.allCases, [metric, imperial, DisplayUnits(distance: .metres, speed: .metresPerSecond)])
    func roundTripIsInvariant(key: MetricKey, units: DisplayUnits) {
        for si in [0.0, 0.001, 1, 45, 130.123456, 12345.6789] {
            let back = UnitConversion.si(UnitConversion.display(si, for: key, units: units), for: key, units: units)
            #expect(abs(back - si) <= 1e-9 * max(1, abs(si)))
        }
    }

    @Test func knownConversions() {
        #expect(abs(UnitConversion.display(100, for: .carry, units: imperial) - 109.36132983) < 1e-6)
        #expect(UnitConversion.display(100, for: .carry, units: metric) == 100)
        #expect(abs(UnitConversion.display(10, for: .ballSpeed, units: metric) - 36) < 1e-12)
        #expect(abs(UnitConversion.display(44.704, for: .ballSpeed, units: imperial) - 100) < 1e-9)
        #expect(abs(UnitConversion.display(.pi, for: .verticalLaunch, units: metric) - 180) < 1e-12)
        // Spec section 5: rad/s x 60 / 2pi
        #expect(abs(UnitConversion.display(628.3185307, for: .spinRate, units: metric) - 6000) < 1e-5)
    }

    @Test func regionalDefaultsDoNotDependOnLanguage() {
        #expect(DisplayUnits.defaults(for: Locale(identifier: "en_US")) == imperial)
        #expect(DisplayUnits.defaults(for: Locale(identifier: "sv_SE")) == metric)
        #expect(DisplayUnits.defaults(for: Locale(identifier: "en_GB")) == metric)
    }
}

struct MetricFormatterTests {
    @Test func swedishUsesDecimalCommaEnglishUsesPoint() throws {
        let svText = try #require(MetricFormatter(units: metric, locale: sv).format(12.5, for: .ballSpeed)) // 12.5 m/s = 45 km/h
        #expect(svText.number == "45,0")
        #expect(svText.unit == "km/h")
        let enText = try #require(MetricFormatter(units: metric, locale: en).format(12.5, for: .ballSpeed))
        #expect(enText.number == "45.0")
    }

    @Test func distanceAndUnitText() {
        let f = MetricFormatter(units: imperial, locale: en)
        #expect(f.format(100, for: .carry)?.text == "109\u{00A0}yd")
        #expect(MetricFormatter(units: metric, locale: sv).format(130.4, for: .carry)?.text == "130\u{00A0}m")
    }

    @Test func spinAnglesAndRatios() {
        let f = MetricFormatter(units: metric, locale: sv)
        #expect(f.format(628.3185307, for: .spinRate)?.unit == "rpm")
        #expect(f.format(628.3185307, for: .spinRate)?.number.filter(\.isNumber) == "6000")
        #expect(f.format(0.3141592654, for: .verticalLaunch)?.text == "18,0\u{00A0}°")
        #expect(f.format(1.5, for: .smashFactor)?.text == "1,50")
    }

    /// Missing metric = unavailable, never 0.
    @Test func unavailableValuesAreNilNeverZero() {
        let f = MetricFormatter(units: metric, locale: en)
        #expect(f.format(nil, for: .clubSpeed) == nil)
        #expect(f.format(.nan, for: .carry) == nil)
        #expect(f.format(.infinity, for: .carry) == nil)
        #expect(f.format(0, for: .carry)?.number == "0") // a real zero is still shown
    }

    @Test func negativeZeroDoesNotShowAsMinusZero() {
        let f = MetricFormatter(units: metric, locale: en)
        #expect(f.format(-0.0, for: .lateralLanding)?.number == "0.0")
    }

    /// Rounding is display-only: two values that display the same stay different underneath.
    @Test func displayRoundingDoesNotTouchInput() {
        let a = 100.4, b = 100.45
        let f = MetricFormatter(units: metric, locale: en)
        #expect(f.format(a, for: .carry)?.number == f.format(b, for: .carry)?.number)
        #expect(a != b)
    }

    @Test func largeNumbersUseLocaleGrouping() throws {
        let sv = try #require(MetricFormatter(units: metric, locale: sv).format(1047.2, for: .spinRate)?.number)
        #expect(sv.contains("\u{00A0}") || sv.contains("\u{202F}") || sv.contains(" "))
        #expect(try #require(MetricFormatter(units: metric, locale: en).format(1047.2, for: .spinRate)?.number).contains(","))
    }
}

struct NumberInputTests {
    @Test func swedishDecimalComma() {
        #expect(NumberInput.parse("56,5", locale: sv) == 56.5)
        #expect(NumberInput.parse("56.5", locale: sv) == 56.5)
        #expect(NumberInput.parse("0,25", locale: sv) == 0.25)
        #expect(NumberInput.parse("-3,5", locale: sv) == -3.5)
        #expect(NumberInput.parse("\u{2212}3,5", locale: sv) == -3.5)
        #expect(NumberInput.parse("1\u{00A0}234,5", locale: sv) == 1234.5)
        #expect(NumberInput.parse(" 7 ", locale: sv) == 7)
    }

    @Test func englishPointAndGrouping() {
        #expect(NumberInput.parse("56.5", locale: en) == 56.5)
        #expect(NumberInput.parse("1,234.5", locale: en) == 1234.5)
        #expect(NumberInput.parse("1,234", locale: en) == 1234)
    }

    @Test(arguments: ["", "   ", "abc", "1,2,3x", "NaN", "inf", "--5", "5.5.5", "12e", ","])
    func garbageIsRejected(text: String) {
        #expect(NumberInput.parse(text, locale: sv) == nil)
        #expect(NumberInput.parse(text, locale: en) == nil)
    }

    @Test func formatThenParseRoundTrips() {
        for locale in [en, sv] {
            let f = MetricFormatter(units: metric, locale: locale)
            let shown = f.number(1234.5, fractionDigits: 1)
            #expect(NumberInput.parse(shown, locale: locale) == 1234.5)
            #expect(NumberInput.parse(f.number(-0.5, fractionDigits: 1), locale: locale) == -0.5)
        }
    }
}
