import Foundation

/// What the platform reports about the device. Gathered by the app; the decision below is pure and testable.
public struct DeviceFacts: Equatable, Sendable {
    public let modelIdentifier: String
    public let osMajorVersion: Int
    public let freeStorageBytes: Int64
    public let formats: [CaptureFormatDescriptor]

    public init(modelIdentifier: String, osMajorVersion: Int, freeStorageBytes: Int64, formats: [CaptureFormatDescriptor]) {
        self.modelIdentifier = modelIdentifier
        self.osMajorVersion = osMajorVersion
        self.freeStorageBytes = freeStorageBytes
        self.formats = formats
    }
}

public enum CapabilityStatus: String, Codable, Sendable {
    case supported, experimental, unsupported
}

/// Why a device got its status. Blocking reasons make it Unsupported; the others are explanations or warnings.
public enum CapabilityReason: String, Codable, Sendable {
    case osTooOld, noCamera, noHighFrameRate, storageCritical // blocking
    case belowValidatedFrameRate, noValidatedProfile, storageLow // not blocking

    public var isBlocking: Bool {
        switch self {
        case .osTooOld, .noCamera, .noHighFrameRate, .storageCritical: true
        case .belowValidatedFrameRate, .noValidatedProfile, .storageLow: false
        }
    }
}

public struct CapabilityReport: Equatable, Sendable {
    public let status: CapabilityStatus
    public let reasons: [CapabilityReason]
    /// The format capture would start from; nil if Unsupported.
    public let bestFormatID: String?
}

/// Capability qualification (F01): Supported only for an explicitly validated device model, never inferred from specs.
public enum CapabilityQualifier {
    public static let minimumOS = 18
    public static let validatedFrameRate = 240.0
    public static let criticalStorageBytes: Int64 = 2_000_000_000
    public static let lowStorageBytes: Int64 = 10_000_000_000

    /// - Parameter validatedModels: device model identifiers that passed G1/G2. Empty until gate evidence exists.
    public static func qualify(_ facts: DeviceFacts, validatedModels: Set<String> = []) -> CapabilityReport {
        var reasons: [CapabilityReason] = []
        if facts.osMajorVersion < minimumOS {
            reasons.append(.osTooOld)
        }
        var best: CaptureFormatDescriptor?
        if facts.formats.isEmpty {
            reasons.append(.noCamera)
        } else if let candidates = try? FormatCatalog.candidates(from: facts.formats) {
            best = candidates.first
        } else {
            reasons.append(.noHighFrameRate)
        }
        if facts.freeStorageBytes < criticalStorageBytes {
            reasons.append(.storageCritical)
        }
        if reasons.contains(where: \.isBlocking) {
            return CapabilityReport(status: .unsupported, reasons: reasons, bestFormatID: nil)
        }
        // Not blocking: the profile reason reads first, then a storage warning. Only the profile reasons stop it being Supported.
        var notes: [CapabilityReason] = []
        if !validatedModels.contains(facts.modelIdentifier) {
            notes.append(.noValidatedProfile)
        } else if (best?.maxFrameRate ?? 0) < validatedFrameRate {
            notes.append(.belowValidatedFrameRate)
        }
        let supported = notes.isEmpty
        if facts.freeStorageBytes < lowStorageBytes {
            notes.append(.storageLow)
        }
        return CapabilityReport(status: supported ? .supported : .experimental, reasons: notes, bestFormatID: best?.id)
    }
}
