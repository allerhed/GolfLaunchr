import Foundation

/// Typed validation failure for the persisted/exchanged data contracts (spec section 6).
/// Decoding maps these to `DecodingError.dataCorrupted`, so bad input never becomes a silent zero.
public enum ContractError: Error, Equatable, Sendable {
    case nonFiniteValue(String)
    case negativeValue(String)
    case unitMismatch(metric: String, unit: String)
    case valueProvenanceMismatch(metric: String)
    case uncertaintyInvalid(metric: String)
    case invalidSequence(Int)
    case invalidEnvironment
    case invalidCoordinateConvention(String)
    case invalidName
    case invalidDateOrder
    case invalidCalibration(String)
    case invalidCreditCost(Int)
    case unknownValue(field: String, value: String)
}

extension ContractError {
    /// Wraps a validation failure so Codable decoding reports it at the right path.
    func asDecodingError(_ codingPath: [any CodingKey]) -> DecodingError {
        .dataCorrupted(.init(codingPath: codingPath, debugDescription: "\(self)"))
    }
}

/// Shared JSON configuration for the exchange contract: UTC ISO-8601 with millisecond precision, stable key order.
public enum ContractJSON {
    public static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.formatter(fractional: true).string(from: date))
        }
        return enc
    }

    public static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.formatter(fractional: true).date(from: text) ?? Self.formatter(fractional: false).date(from: text) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO-8601 UTC date: \(text)"))
        }
        return dec
    }

    private static func formatter(fractional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }
}
