import Domain
import Foundation

/// The golfer's atmosphere choice (F18): the declared standard atmosphere or manual absolute pressure and temperature. There is no
/// barometer input yet, so nothing is ever fabricated: an unusable manual entry is reported, not replaced by the standard value.
public struct AtmosphereSetting: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable {
        case standard, manual
    }

    public enum Problem: String, Equatable, Sendable {
        case missingPressure, missingTemperature, pressureOutOfRange, temperatureOutOfRange
    }

    public enum Resolution: Equatable, Sendable {
        case standard(Environment)
        /// `stale`: entered more than 12 hours ago (or without a timestamp), so the values may no longer describe the weather.
        case manual(Environment, stale: Bool)
        case invalid([Problem])
    }

    public static let pressureRangeHPa = 300.0 ... 1100.0
    public static let temperatureRangeC = -30.0 ... 50.0
    public static let staleAfter: TimeInterval = 12 * 3600

    public var mode: Mode
    /// Absolute pressure at the location, never sea-level-adjusted (spec F06).
    public var pressureHPa: Double?
    public var temperatureC: Double?
    public var enteredAt: Date?

    public init(mode: Mode = .standard, pressureHPa: Double? = nil, temperatureC: Double? = nil, enteredAt: Date? = nil) {
        self.mode = mode
        self.pressureHPa = pressureHPa
        self.temperatureC = temperatureC
        self.enteredAt = enteredAt
    }

    public func problems() -> [Problem] {
        guard mode == .manual else { return [] }
        var found: [Problem] = []
        if let p = pressureHPa {
            if !(p.isFinite && Self.pressureRangeHPa.contains(p)) {
                found.append(.pressureOutOfRange)
            }
        } else {
            found.append(.missingPressure)
        }
        if let t = temperatureC {
            if !(t.isFinite && Self.temperatureRangeC.contains(t)) {
                found.append(.temperatureOutOfRange)
            }
        } else {
            found.append(.missingTemperature)
        }
        return found
    }

    public func resolve(now: Date) -> Resolution {
        switch mode {
        case .standard:
            guard let env = try? Atmosphere.standard() else { return .invalid([.missingPressure]) }
            return .standard(env)
        case .manual:
            let found = problems()
            guard found.isEmpty, let p = pressureHPa, let t = temperatureC,
                  let env = try? Environment(pressurePa: p * 100, temperatureK: t + 273.15, source: .manual)
            else { return .invalid(found) }
            let stale = enteredAt.map { now.timeIntervalSince($0) > Self.staleAfter } ?? true
            return .manual(env, stale: stale)
        }
    }
}
