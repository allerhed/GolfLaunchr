import Domain
import Formatting
import Foundation
import Observation
import SwiftUI
import Voice

/// Spoken feedback for the practice screen: builds the words, keeps the bounded queue, and drives the synthesiser. The words are
/// also kept as `caption` so the same text is always visible (F07). Silence never affects capture.
@MainActor @Observable
final class VoiceController {
    private var queue = SpeechQueue()
    private let synthesizer: any SpeechSynthesizing
    private let settings: SettingsStore
    private let localeProvider: () -> Locale
    /// The last result sentence, shown on screen whether or not it was spoken.
    private(set) var caption: String?

    init(settings: SettingsStore, synthesizer: any SpeechSynthesizing, locale: @escaping () -> Locale = VoiceController.appLocale) {
        self.settings = settings
        self.synthesizer = synthesizer
        localeProvider = locale
        synthesizer.onFinished = { [weak self] id in
            Task { @MainActor in self?.finished(id) }
        }
        apply(settings.voice)
    }

    /// The language the app is showing (en or sv), which is also the speech language.
    nonisolated static func appLocale() -> Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
    }

    private var feedback: SpokenFeedback {
        SpokenFeedback(units: settings.units, locale: localeProvider())
    }

    var isMuted: Bool {
        !settings.voice.enabled
    }

    /// Call after the preferences changed (mute toggled).
    func apply(_ preferences: VoicePreferences) {
        perform(queue.setMuted(!preferences.enabled))
    }

    func announce(_ shot: Shot) {
        guard let text = SpokenFeedback(units: settings.units, locale: localeProvider())
            .result(for: shot, preferences: VoicePreferences(enabled: true, metrics: settings.voice.metrics))
        else { return }
        caption = text
        guard settings.voice.enabled else { return }
        perform(queue.release())
        perform(queue.enqueue(text, kind: .result))
    }

    func prompt(_ prompt: SpokenPrompt) {
        guard settings.voice.enabled else { return }
        perform(queue.enqueue(feedback.prompt(prompt), kind: .prompt))
    }

    /// Armed: no new speech starts until the shot is accepted (or the session pauses/ends).
    func hold() {
        queue.hold()
    }

    func releaseHold() {
        perform(queue.release())
    }

    /// Stops speaking, forgets what was waiting and lifts any hold (pause, end).
    func stop() {
        perform(queue.clear())
        perform(queue.release())
    }

    func preview() {
        guard settings.voice.enabled else { return }
        perform(queue.enqueue(feedback.preview(preferences: settings.voice), kind: .prompt))
    }

    private func finished(_ id: UUID) {
        perform(queue.finished(id))
    }

    private func perform(_ action: SpeechAction) {
        switch action {
        case .none: break
        case .stopCurrent: synthesizer.stop()
        case let .speak(item): synthesizer.speak(item.text, languageCode: localeProvider().identifier, id: item.id)
        }
    }
}

extension SpokenMetric {
    var titleKey: LocalizedStringKey {
        switch self {
        case .carry: MetricKey.carry.titleKey
        case .ballSpeed: MetricKey.ballSpeed.titleKey
        case .verticalLaunch: MetricKey.verticalLaunch.titleKey
        }
    }
}
