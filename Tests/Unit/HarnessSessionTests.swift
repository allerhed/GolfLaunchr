#if CAPTURE_HARNESS
    import Foundation
    @testable import GolfLaunchr
    import Testing

    /// Garage/bay session numbering in the DEBUG capture harness.
    @MainActor
    struct HarnessSessionTests {
        @Test func nextBlockCountsUp() {
            #expect(HarnessView.nextBlock(after: "B1") == "B2")
            #expect(HarnessView.nextBlock(after: "B9") == "B10")
            #expect(HarnessView.nextBlock(after: "garage-12") == "garage-13")
            #expect(HarnessView.nextBlock(after: "warmup") == "warmup-2")
        }

        @Test func numbersRunPerBlockAndKindIndependently() {
            let model = HarnessModel()
            let block = "T-\(UUID().uuidString.prefix(6))" // a block no log has seen
            #expect(model.nextSequence(block: block, kind: .strike) == 1)
            #expect(model.nextSequence(block: block, kind: .strike) == 2)
            #expect(model.nextSequence(block: block, kind: .negative) == 1, "negatives have their own numbers")
            #expect(model.nextSequence(block: block + "x", kind: .strike) == 1, "a new block starts at 1")
            #expect(model.nextSequence(block: block, kind: .strike) == 3)
        }

        @Test func theOverlayShowsTheNumberTheNextClipWillGet() {
            let model = HarnessModel()
            model.block = "T-\(UUID().uuidString.prefix(6))"
            model.recordingKind = .strike
            #expect(model.upcomingSequence == 1)
            _ = model.nextSequence(block: model.block, kind: .strike)
            #expect(model.upcomingSequence == 2)
        }
    }
#endif
