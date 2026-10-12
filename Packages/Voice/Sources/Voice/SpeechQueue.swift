import Foundation

public enum SpeechKind: Sendable {
    case prompt, result
}

public struct SpeechItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let kind: SpeechKind
}

public enum SpeechAction: Equatable, Sendable {
    case none
    case speak(SpeechItem)
    case stopCurrent
}

/// Bounded speech queue (F07): at most one item speaking and one waiting. A newer result replaces an unspoken one, so a fast
/// session never recites a backlog. Mute drops everything; hold keeps new speech from starting while the next strike is captured.
public struct SpeechQueue: Sendable {
    public private(set) var current: SpeechItem?
    public private(set) var pending: SpeechItem?
    public private(set) var isMuted = false
    public private(set) var isHeld = false

    public init() {}

    public mutating func enqueue(_ text: String, kind: SpeechKind) -> SpeechAction {
        guard !isMuted else { return .none }
        let item = SpeechItem(id: UUID(), text: text, kind: kind)
        if current == nil, !isHeld {
            current = item
            return .speak(item)
        }
        switch (pending?.kind, kind) {
        case (.result?, .prompt): break // a result still to be spoken is worth more than a prompt
        default: pending = item
        }
        return .none
    }

    public mutating func finished(_ id: UUID) -> SpeechAction {
        guard current?.id == id else { return .none }
        current = nil
        return startPending()
    }

    public mutating func hold() {
        isHeld = true
    }

    public mutating func release() -> SpeechAction {
        isHeld = false
        return current == nil ? startPending() : .none
    }

    public mutating func setMuted(_ muted: Bool) -> SpeechAction {
        isMuted = muted
        return muted ? clear() : .none
    }

    public mutating func clear() -> SpeechAction {
        let wasSpeaking = current != nil
        current = nil
        pending = nil
        return wasSpeaking ? .stopCurrent : .none
    }

    private mutating func startPending() -> SpeechAction {
        guard !isHeld, !isMuted, let next = pending else { return .none }
        pending = nil
        current = next
        return .speak(next)
    }
}
