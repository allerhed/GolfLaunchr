import AVFoundation
import Foundation

/// Speaks text and reports when an utterance ended (finished or cancelled). A protocol so tests never produce sound.
protocol SpeechSynthesizing: AnyObject {
    var onFinished: (@Sendable (UUID) -> Void)? { get set }
    func speak(_ text: String, languageCode: String, id: UUID)
    func stop()
}

/// The system voice. Ducks other audio while speaking, follows the system route (speaker, headphones, Bluetooth), and stops quietly
/// if the output device disappears (headphones unplugged) instead of suddenly speaking from the loudspeaker.
/// BEHAVIOUR NOT RUN on a device: compile-checked and simulator-checked only.
final class SystemSpeechSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinished: (@Sendable (UUID) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var ids: [ObjectIdentifier: UUID] = [:]
    private let lock = NSLock()

    override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil
        )
    }

    func speak(_ text: String, languageCode: String, id: UUID) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        lock.lock(); ids[ObjectIdentifier(utterance)] = id; lock.unlock()
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    @objc private func routeChanged(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        stop()
    }

    private func ended(_ utterance: AVSpeechUtterance) {
        lock.lock(); let id = ids.removeValue(forKey: ObjectIdentifier(utterance)); let idle = ids.isEmpty; lock.unlock()
        if idle {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        if let id {
            onFinished?(id)
        }
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        ended(utterance)
    }

    func speechSynthesizer(_: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        ended(utterance)
    }
}

#if DEBUG
    /// UI-test double (`-uiTestFakeVoice`): records what would be spoken and finishes at once.
    final class RecordingSynthesizer: SpeechSynthesizing, @unchecked Sendable {
        var onFinished: (@Sendable (UUID) -> Void)?
        private(set) var spoken: [String] = []
        private(set) var stops = 0

        func speak(_ text: String, languageCode _: String, id: UUID) {
            spoken.append(text)
            onFinished?(id)
        }

        func stop() {
            stops += 1
        }
    }
#endif
