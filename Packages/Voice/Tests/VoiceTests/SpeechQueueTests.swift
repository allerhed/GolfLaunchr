import Foundation
import Testing
@testable import Voice

struct SpeechQueueTests {
    @Test func theFirstItemSpeaksAtOnceAndAnotherWaitsAsOnlyOnePending() {
        var q = SpeechQueue()
        guard case let .speak(first) = q.enqueue("one", kind: .result) else { Issue.record("should speak"); return }
        #expect(q.current == first)
        #expect(q.enqueue("two", kind: .result) == .none && q.pending?.text == "two")
    }

    /// F07: replace obsolete unspoken results instead of reciting a backlog.
    @Test func aNewerResultReplacesAnUnspokenOne() {
        var q = SpeechQueue()
        _ = q.enqueue("one", kind: .result)
        _ = q.enqueue("two", kind: .result)
        _ = q.enqueue("three", kind: .result)
        #expect(q.pending?.text == "three")
        guard case let .speak(next) = q.finished(q.current?.id ?? UUID()) else { Issue.record("should speak"); return }
        #expect(next.text == "three" && q.pending == nil)
        #expect(q.finished(next.id) == .none && q.current == nil)
    }

    @Test func aPromptNeverDisplacesAPendingResultButAResultDisplacesAPrompt() {
        var q = SpeechQueue()
        _ = q.enqueue("busy", kind: .result)
        _ = q.enqueue("result", kind: .result)
        _ = q.enqueue("ready", kind: .prompt)
        #expect(q.pending?.text == "result")
        var p = SpeechQueue()
        _ = p.enqueue("busy", kind: .result)
        _ = p.enqueue("ready", kind: .prompt)
        _ = p.enqueue("result", kind: .result)
        #expect(p.pending?.text == "result")
    }

    @Test func muteStopsSpeechDropsEverythingAndStaysSilent() {
        var q = SpeechQueue()
        _ = q.enqueue("one", kind: .result)
        _ = q.enqueue("two", kind: .result)
        #expect(q.setMuted(true) == .stopCurrent && q.current == nil && q.pending == nil)
        #expect(q.enqueue("three", kind: .result) == .none && q.pending == nil && q.current == nil)
        #expect(q.setMuted(false) == .none)
        if case .speak = q.enqueue("four", kind: .result) {} else {
            Issue.record("unmuted queue should speak")
        }
    }

    /// Hold keeps new speech from starting during the next strike's capture window; what was queued is kept.
    @Test func holdDelaysStartsAndReleaseSpeaksThePendingItem() {
        var q = SpeechQueue()
        q.hold()
        #expect(q.enqueue("result", kind: .result) == .none && q.pending?.text == "result")
        guard case let .speak(item) = q.release() else { Issue.record("release should speak"); return }
        #expect(item.text == "result" && q.release() == .none)
    }

    @Test func holdDoesNotCutOffSpeechAlreadyRunning() {
        var q = SpeechQueue()
        _ = q.enqueue("running", kind: .prompt)
        q.hold()
        #expect(q.current?.text == "running")
        _ = q.enqueue("later", kind: .result)
        #expect(q.finished(q.current?.id ?? UUID()) == .none) // held: the next one waits
        #expect(q.pending?.text == "later")
    }

    @Test func finishingAnUnknownItemChangesNothing() {
        var q = SpeechQueue()
        _ = q.enqueue("one", kind: .result)
        #expect(q.finished(UUID()) == .none && q.current?.text == "one")
    }

    @Test func clearStopsAndEmpties() {
        var q = SpeechQueue()
        _ = q.enqueue("one", kind: .result)
        _ = q.enqueue("two", kind: .result)
        #expect(q.clear() == .stopCurrent && q.current == nil && q.pending == nil)
        #expect(q.clear() == .none)
    }
}
