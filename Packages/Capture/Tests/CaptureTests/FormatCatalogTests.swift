@testable import Capture
import Testing

struct FormatCatalogTests {
    @Test func slowFormatsAreRejectedAndHighRateOnesRankedByRateThenFieldOfView() throws {
        let list = [
            format("30", fps: 30),
            format("120-wide", fps: 120, fov: 63),
            format("240-narrow", fps: 240, fov: 40, lens: .telephoto),
            format("240-wide", fps: 240, fov: 63),
            format("240-ultra", fps: 240, fov: 100, w: 1280, h: 720, lens: .ultraWide),
        ]
        let ranked = try FormatCatalog.candidates(from: list).map(\.id)
        #expect(ranked == ["240-ultra", "240-wide", "240-narrow", "120-wide"])
    }

    @Test func unknownFieldOfViewRanksAfterKnown() throws {
        let ranked = try FormatCatalog.candidates(from: [format("b", fps: 240, fov: nil), format("a", fps: 240, fov: 30)]).map(\.id)
        #expect(ranked == ["a", "b"])
    }

    @Test func tiesAreDeterministic() throws {
        let a = [format("x", fps: 240), format("y", fps: 240)]
        #expect(try FormatCatalog.candidates(from: a).map(\.id) == FormatCatalog.candidates(from: a.reversed()).map(\.id))
    }

    @Test func noHighRateFormatIsATypedUnsupportedResult() {
        #expect(throws: FormatSelectionError.noHighFrameRateFormat) { try FormatCatalog.candidates(from: [
            format("30", fps: 30),
            format("60", fps: 60)
        ]) }
        #expect(throws: FormatSelectionError.noFormatsReported) { try FormatCatalog.candidates(from: []) }
    }

    @Test func rejectionReasons() {
        #expect(FormatCatalog.rejection(format("a", fps: 60)) == .frameRateTooLow)
        #expect(FormatCatalog.rejection(format("b", fps: 240, w: 320, h: 240)) == .unusableResolution)
        #expect(FormatCatalog.rejection(format("c", fps: 120)) == nil) // boundary: exactly the minimum is accepted
        #expect(FormatCatalog.rejection(format("d", fps: 119.99)) == .frameRateTooLow)
    }
}
