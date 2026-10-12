import Domain
import Formatting
import Foundation

/// The metrics that can be spoken, in the one stable order they are always spoken in (F07).
public enum SpokenMetric: String, CaseIterable, Codable, Sendable {
    case carry, ballSpeed, verticalLaunch

    var key: MetricKey {
        switch self {
        case .carry: .carry
        case .ballSpeed: .ballSpeed
        case .verticalLaunch: .verticalLaunch
        }
    }
}

public struct VoicePreferences: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var metrics: Set<SpokenMetric>

    public init(enabled: Bool, metrics: Set<SpokenMetric>) {
        self.enabled = enabled
        self.metrics = metrics
    }

    public static let `default` = VoicePreferences(enabled: true, metrics: [.carry, .ballSpeed])

    /// Selected metrics in speaking order, whatever order they were chosen in.
    public var orderedMetrics: [SpokenMetric] {
        SpokenMetric.allCases.filter(metrics.contains)
    }
}

public enum SpokenPrompt: String, CaseIterable, Sendable {
    case ready, reposition
}

enum SpeechLanguage {
    case english, swedish

    init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "sv" ? .swedish : .english
    }
}

/// Builds the words that are spoken, from stored SI values and the display units, with the same number formatting as the screens.
/// Pure and deterministic: the same words are shown as text (accessibility) and given to the speech synthesiser.
public struct SpokenFeedback: Sendable {
    private let formatter: MetricFormatter
    private let language: SpeechLanguage

    public init(units: DisplayUnits, locale: Locale) {
        formatter = MetricFormatter(units: units, locale: locale)
        language = SpeechLanguage(locale: locale)
    }

    /// nil when voice is off or nothing is selected.
    public func result(for shot: Shot, preferences: VoicePreferences) -> String? {
        guard preferences.enabled else { return nil }
        let parts = preferences.orderedMetrics.map { sentence(for: $0, in: shot) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    public func prompt(_ prompt: SpokenPrompt) -> String {
        switch (prompt, language) {
        case (.ready, .english): "Ready."
        case (.ready, .swedish): "Redo."
        case (.reposition, .english): "Please reposition the phone."
        case (.reposition, .swedish): "Flytta telefonen."
        }
    }

    /// A fixed sample for the Settings preview, in the chosen units. Not a measurement.
    public func preview(preferences: VoicePreferences) -> String {
        let sample = preferences.orderedMetrics.map { metric -> String in
            let name = self.name(metric)
            let value: Double = switch metric {
            case .carry: 150
            case .ballSpeed: 55
            case .verticalLaunch: 0.2
            }
            let qualifier = metric == .carry ? qualified(name, .estimated) : name
            return "\(qualifier): \(spoken(value, metric))."
        }
        return sample.joined(separator: " ")
    }

    // MARK: words

    private func sentence(for metric: SpokenMetric, in shot: Shot) -> String {
        let name = name(metric)
        guard let m = shot.metrics[metric.key], m.provenance != .unavailable, m.quality != .invalid, let value = m.value, value.isFinite
        else {
            return language == .swedish ? "\(name) inte tillgänglig." : "\(name) unavailable."
        }
        return "\(qualified(name, m.provenance)): \(spoken(value, metric))."
    }

    private func qualified(_ name: String, _ provenance: Provenance) -> String {
        switch (provenance, language) {
        case (.estimated, .english): "Estimated \(name.lowercasedFirst)"
        case (.derived, .english): "Derived \(name.lowercasedFirst)"
        case (.estimated, .swedish): "Beräknad \(name.lowercasedFirst)"
        case (.derived, .swedish): "Härledd \(name.lowercasedFirst)"
        default: name // measured: no qualifier
        }
    }

    private func name(_ metric: SpokenMetric) -> String {
        switch (metric, language) {
        case (.carry, .english): "Carry"
        case (.ballSpeed, .english): "Ball speed"
        case (.verticalLaunch, .english): "Vertical launch angle"
        case (.carry, .swedish): "Flyglängd"
        case (.ballSpeed, .swedish): "Bollhastighet"
        case (.verticalLaunch, .swedish): "Vertikal utgångsvinkel"
        }
    }

    private func spoken(_ si: Double, _ metric: SpokenMetric) -> String {
        guard let shown = formatter.format(si, for: metric.key) else { return "" }
        return "\(shown.number) \(unitWords(metric, singular: shown.number == "1"))"
    }

    private func unitWords(_ metric: SpokenMetric, singular: Bool) -> String {
        language == .english ? englishUnit(metric, singular: singular) : swedishUnit(metric, singular: singular)
    }

    private func englishUnit(_ metric: SpokenMetric, singular: Bool) -> String {
        switch metric {
        case .carry:
            switch formatter.units.distance {
            case .metres: singular ? "metre" : "metres"
            case .yards: singular ? "yard" : "yards"
            }
        case .ballSpeed:
            switch formatter.units.speed {
            case .metresPerSecond: "metres per second"
            case .kilometresPerHour: "kilometres per hour"
            case .milesPerHour: "miles per hour"
            }
        case .verticalLaunch: singular ? "degree" : "degrees"
        }
    }

    private func swedishUnit(_ metric: SpokenMetric, singular: Bool) -> String {
        switch metric {
        case .carry: formatter.units.distance == .metres ? "meter" : "yards"
        case .ballSpeed:
            switch formatter.units.speed {
            case .metresPerSecond: "meter per sekund"
            case .kilometresPerHour: "kilometer i timmen"
            case .milesPerHour: "miles i timmen"
            }
        case .verticalLaunch: singular ? "grad" : "grader"
        }
    }
}

private extension String {
    /// "Ball speed" -> "ball speed" for use after a qualifier ("Estimated ball speed").
    var lowercasedFirst: String {
        prefix(1).lowercased() + dropFirst()
    }
}
