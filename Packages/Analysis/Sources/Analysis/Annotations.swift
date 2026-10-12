import Foundation

public struct PixelPoint: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct FrameAnnotation: Codable, Sendable, Equatable {
    public let frameIndex: Int
    /// Ball centre in pixels (origin top-left). nil when the ball is not visible or cannot be localised.
    public let ballCenter: PixelPoint?
    public let ballVisible: Bool
    public let clubVisible: Bool

    public init(frameIndex: Int, ballCenter: PixelPoint?, ballVisible: Bool, clubVisible: Bool) {
        self.frameIndex = frameIndex
        self.ballCenter = ballCenter
        self.ballVisible = ballVisible
        self.clubVisible = clubVisible
    }
}

public enum AnnotationError: Error, Equatable {
    case negativeFrameIndex(Int)
    case duplicateFrameIndex(Int)
    case centerOutsideImage(frame: Int)
    case centerWithoutVisibleBall(frame: Int)
    case invalidImageSize
    case unknownSchema(String)
}

/// Human ground truth for criterion P4 (G1 plan section 6). Schema `g1-annotations/1`.
public struct ClipAnnotations: Codable, Sendable, Equatable {
    public static let schema = "g1-annotations/1"

    public let schema: String
    public let clipID: UUID
    /// Pseudonymous id of the person who annotated.
    public let annotator: String
    public let width: Int
    public let height: Int
    /// Index (in decoded frame order) of the first frame after the club contacts the ball. nil until marked.
    public let impactFrameIndex: Int?
    public let frames: [FrameAnnotation]

    public init(
        clipID: UUID,
        annotator: String,
        width: Int,
        height: Int,
        impactFrameIndex: Int?,
        frames: [FrameAnnotation]
    ) throws(AnnotationError) {
        schema = Self.schema
        self.clipID = clipID
        self.annotator = annotator
        self.width = width
        self.height = height
        self.impactFrameIndex = impactFrameIndex
        self.frames = frames
        try validate()
    }

    public func validate() throws(AnnotationError) {
        guard schema == Self.schema else { throw .unknownSchema(schema) }
        guard width > 0, height > 0 else { throw .invalidImageSize }
        var seen = Set<Int>()
        for frame in frames {
            guard frame.frameIndex >= 0 else { throw .negativeFrameIndex(frame.frameIndex) }
            guard seen.insert(frame.frameIndex).inserted else { throw .duplicateFrameIndex(frame.frameIndex) }
            if let c = frame.ballCenter {
                guard frame.ballVisible else { throw .centerWithoutVisibleBall(frame: frame.frameIndex) }
                guard c.x >= 0, c.y >= 0, c.x < Double(width), c.y < Double(height), c.x.isFinite, c.y.isFinite else {
                    throw .centerOutsideImage(frame: frame.frameIndex)
                }
            }
        }
    }
}

public extension ClipAnnotations {
    /// Decoding validates, so a hand-edited file with a bad value is rejected instead of silently trusted.
    static func decode(from data: Data) throws -> ClipAnnotations {
        let value = try JSONDecoder().decode(ClipAnnotations.self, from: data)
        try value.validate()
        return value
    }
}

/// Counts annotated evidence for the pass criteria (P4, P7). Frames without an annotation are unknown, not "not visible".
public enum TrajectoryEvidence {
    /// Frames strictly after impact in which the ball centre was localised.
    public static func postImpactLocalized(_ a: ClipAnnotations) -> Int? {
        guard let impact = a.impactFrameIndex else { return nil }
        return a.frames.filter { $0.frameIndex > impact && $0.ballCenter != nil }.count
    }

    /// Frames up to and including impact in which the clubhead is visible (P7: club speed evidence).
    public static func preImpactClubVisible(_ a: ClipAnnotations) -> Int? {
        guard let impact = a.impactFrameIndex else { return nil }
        return a.frames.filter { $0.frameIndex <= impact && $0.clubVisible }.count
    }

    /// P4 for one strike: at least `minimumFrames` post-impact frames with the ball localised.
    public static func meetsP4(_ a: ClipAnnotations, minimumFrames: Int = 4) -> Bool? {
        postImpactLocalized(a).map { $0 >= minimumFrames }
    }
}

public struct ClipInfo: Sendable, Equatable {
    public let clipID: UUID
    public let annotator: String
    public let width: Int
    public let height: Int
    public let frameCount: Int

    public init(clipID: UUID, annotator: String, width: Int, height: Int, frameCount: Int) {
        self.clipID = clipID
        self.annotator = annotator
        self.width = width
        self.height = height
        self.frameCount = frameCount
    }
}

public enum AnnotationTemplate {
    /// A blank annotation file listing the frames around `center` (typically the peak-motion frame) for a person to fill in.
    /// Every frame starts as "ball not visible"; an annotator sets visibility and centre. Impact is left unset.
    public static func make(for clip: ClipInfo, center: Int, span: Int) throws(AnnotationError) -> ClipAnnotations {
        let lower = max(0, center - span), upper = min(max(clip.frameCount - 1, 0), center + span)
        let frames = lower > upper ? [] : (lower ... upper).map {
            FrameAnnotation(frameIndex: $0, ballCenter: nil, ballVisible: false, clubVisible: false)
        }
        return try ClipAnnotations(
            clipID: clip.clipID, annotator: clip.annotator, width: clip.width, height: clip.height, impactFrameIndex: nil, frames: frames
        )
    }
}
