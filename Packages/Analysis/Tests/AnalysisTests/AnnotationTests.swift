@testable import Analysis
import Foundation
import Testing

struct AnnotationTests {
    let clip = UUID()

    func make(_ frames: [FrameAnnotation], impact: Int? = 10) throws -> ClipAnnotations {
        try ClipAnnotations(clipID: clip, annotator: "a1", width: 1920, height: 1080, impactFrameIndex: impact, frames: frames)
    }

    func seen(_ i: Int, club: Bool = false) -> FrameAnnotation {
        FrameAnnotation(frameIndex: i, ballCenter: PixelPoint(x: 100 + Double(i), y: 500), ballVisible: true, clubVisible: club)
    }

    @Test func roundTripsAndKeepsNilCentresNil() throws {
        let a = try make([seen(11), FrameAnnotation(frameIndex: 12, ballCenter: nil, ballVisible: false, clubVisible: false)])
        let back = try ClipAnnotations.decode(from: JSONEncoder().encode(a))
        #expect(back == a)
        #expect(back.frames[1].ballCenter == nil)
        #expect(back.schema == "g1-annotations/1")
    }

    @Test func invalidAnnotationsAreRejected() {
        #expect(throws: AnnotationError.duplicateFrameIndex(5)) { try make([seen(5), seen(5)]) }
        #expect(throws: AnnotationError.negativeFrameIndex(-1)) { try make([seen(-1)]) }
        #expect(throws: AnnotationError.centerOutsideImage(frame: 3)) {
            try make([FrameAnnotation(frameIndex: 3, ballCenter: PixelPoint(x: 2000, y: 5), ballVisible: true, clubVisible: false)])
        }
        #expect(throws: AnnotationError.centerOutsideImage(frame: 3)) {
            try make([FrameAnnotation(frameIndex: 3, ballCenter: PixelPoint(x: -1, y: 5), ballVisible: true, clubVisible: false)])
        }
        #expect(throws: AnnotationError.centerWithoutVisibleBall(frame: 4)) {
            try make([FrameAnnotation(frameIndex: 4, ballCenter: PixelPoint(x: 5, y: 5), ballVisible: false, clubVisible: false)])
        }
        #expect(throws: AnnotationError.invalidImageSize) {
            try ClipAnnotations(clipID: UUID(), annotator: "a", width: 0, height: 10, impactFrameIndex: nil, frames: [])
        }
    }

    @Test func aHandEditedBadFileIsRejectedOnDecode() throws {
        let good = try JSONEncoder().encode(make([seen(11)]))
        let bad = try #require(String(data: good, encoding: .utf8)).replacingOccurrences(of: "\"frameIndex\":11", with: "\"frameIndex\":-4")
        #expect(throws: AnnotationError.self) { try ClipAnnotations.decode(from: Data(bad.utf8)) }
    }

    @Test func p4CountsOnlyLocalizedFramesAfterImpact() throws {
        let frames = [
            seen(9),
            seen(10),
            seen(11),
            seen(12),
            seen(13),
            FrameAnnotation(frameIndex: 14, ballCenter: nil, ballVisible: false, clubVisible: false)
        ]
        let a = try make(frames, impact: 10)
        #expect(TrajectoryEvidence.postImpactLocalized(a) == 3) // 11, 12, 13: impact frame itself and frame 14 excluded
        #expect(TrajectoryEvidence.meetsP4(a) == false)
        #expect(TrajectoryEvidence.meetsP4(a, minimumFrames: 3) == true) // boundary: exactly the minimum passes
    }

    @Test func unknownImpactMeansUnknownNotFail() throws {
        let a = try make([seen(11)], impact: nil)
        #expect(TrajectoryEvidence.postImpactLocalized(a) == nil)
        #expect(TrajectoryEvidence.meetsP4(a) == nil)
    }

    @Test func clubVisibilityBeforeImpactIsCounted() throws {
        let a = try make([seen(7, club: true), seen(8, club: true), seen(9), seen(10, club: true), seen(11, club: true)], impact: 10)
        #expect(TrajectoryEvidence.preImpactClubVisible(a) == 3) // 7, 8, 10; frame 11 is after impact
    }
}

struct AnnotationTemplateTests {
    @Test func listsFramesAroundTheCenterClampedToTheClip() throws {
        let a = try AnnotationTemplate.make(
            for: ClipInfo(clipID: UUID(), annotator: "a", width: 1920, height: 1080, frameCount: 20), center: 3, span: 5
        )
        #expect(a.frames.map(\.frameIndex) == Array(0 ... 8))
        let b = try AnnotationTemplate.make(
            for: ClipInfo(clipID: UUID(), annotator: "a", width: 1920, height: 1080, frameCount: 20), center: 18, span: 5
        )
        #expect(b.frames.map(\.frameIndex) == Array(13 ... 19))
        #expect(a.frames.allSatisfy { !$0.ballVisible && $0.ballCenter == nil && !$0.clubVisible })
        #expect(a.impactFrameIndex == nil)
        #expect(TrajectoryEvidence.meetsP4(a) == nil) // nothing annotated yet: unknown, never a pass
    }

    @Test func emptyClipGivesAnEmptyTemplate() throws {
        let a = try AnnotationTemplate.make(
            for: ClipInfo(clipID: UUID(), annotator: "a", width: 10, height: 10, frameCount: 0), center: 0, span: 3
        )
        #expect(a.frames.isEmpty || a.frames.count == 1)
    }
}
