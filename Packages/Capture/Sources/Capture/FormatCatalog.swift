import Foundation

public enum LensKind: String, Codable, Sendable {
    case wide, ultraWide, telephoto, other
}

/// Platform-neutral description of a camera format, so selection logic runs against fixtures in tests.
public struct CaptureFormatDescriptor: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let lens: LensKind
    public let width: Int
    public let height: Int
    public let maxFrameRate: Double
    /// Horizontal field of view as reported by the platform; nil if unknown. Never guessed.
    public let fieldOfViewDegrees: Double?
    public let isVideoBinned: Bool

    public init(
        id: String,
        lens: LensKind,
        width: Int,
        height: Int,
        maxFrameRate: Double,
        fieldOfViewDegrees: Double?,
        isVideoBinned: Bool = false
    ) {
        self.id = id
        self.lens = lens
        self.width = width
        self.height = height
        self.maxFrameRate = maxFrameRate
        self.fieldOfViewDegrees = fieldOfViewDegrees
        self.isVideoBinned = isVideoBinned
    }

    public var pixels: Int {
        width * height
    }
}

public enum FormatRejection: String, Codable, Sendable, Equatable {
    case frameRateTooLow
    case unusableResolution
}

public enum FormatSelectionError: Error, Equatable, Sendable {
    /// No format reaches the minimum frame rate: the device profile is unsupported for capture.
    case noHighFrameRateFormat
    case noFormatsReported
}

/// Chooses spike candidates (spec G1 plan section 3): high frame rate only, ranked by usefulness for trajectory evidence.
public enum FormatCatalog {
    public static let minimumFrameRate = 120.0
    public static let minimumHeight = 540

    public static func rejection(_ format: CaptureFormatDescriptor, minimumFrameRate: Double = minimumFrameRate) -> FormatRejection? {
        if format.maxFrameRate < minimumFrameRate {
            return .frameRateTooLow
        }
        if format.height < minimumHeight {
            return .unusableResolution
        }
        return nil
    }

    /// Ranking: higher frame rate, then wider field of view (more frames with the ball in view), then more pixels.
    /// Unknown field of view ranks after known. Ties break on id so the order is deterministic.
    public static func candidates(
        from formats: [CaptureFormatDescriptor],
        minimumFrameRate: Double = minimumFrameRate
    ) throws(FormatSelectionError) -> [CaptureFormatDescriptor] {
        guard !formats.isEmpty else { throw .noFormatsReported }
        let usable = formats.filter { rejection($0, minimumFrameRate: minimumFrameRate) == nil }
        guard !usable.isEmpty else { throw .noHighFrameRateFormat }
        return usable.sorted { a, b in
            if a.maxFrameRate != b.maxFrameRate {
                return a.maxFrameRate > b.maxFrameRate
            }
            let fa = a.fieldOfViewDegrees ?? -1, fb = b.fieldOfViewDegrees ?? -1
            if fa != fb {
                return fa > fb
            }
            if a.pixels != b.pixels {
                return a.pixels > b.pixels
            }
            return a.id < b.id
        }
    }
}
