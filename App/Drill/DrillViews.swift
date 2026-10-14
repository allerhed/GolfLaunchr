import Domain
import Formatting
import Modes
import SwiftUI

/// Live score on the capture screen: target, attempts, hits, streak and the last result in words and a symbol.
struct DrillPanel: View {
    let result: TargetDrillResult
    @Binding var showingSummary: Bool
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    private var text: DrillText {
        DrillText(units: settings.units, locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("drill.target \(text.distance(result.config.targetCarryM)) \(text.distance(result.config.longitudinalToleranceM))")
                    .font(.subheadline.weight(.semibold))
                Text("drill.progress \(result.scoredCount) \(result.config.attempts)").accessibilityIdentifier("drill.progress")
                HStack(spacing: Spacing.m) {
                    Text("drill.hits \(result.hits)")
                    Text("drill.streak \(result.currentStreak)")
                }
                .font(.footnote)
                if let last = result.attempts.last {
                    let outcome = text.attempt(last, in: result.config)
                    Label { Text(outcome.text) } icon: { Image(systemName: outcome.symbol).accessibilityHidden(true) }
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("drill.last")
                }
                Text("drill.distanceOnly").font(.caption).foregroundStyle(Tokens.textSecondary.color)
                if result.unscoredShotCount > 0 {
                    Text("drill.unscored \(result.unscoredShotCount)").font(.caption).foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("drill.unscored")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("practice.drill")
            if result.isComplete {
                Text("drill.complete").font(.subheadline.weight(.semibold)).accessibilityIdentifier("drill.complete")
            }
            if result.scoredCount > 0 {
                Button { showingSummary = true } label: { Text("drill.viewSummary").frame(minHeight: Spacing.minTarget) }
                    .accessibilityIdentifier("drill.viewSummary")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// The drill result: hits, rate, streak, short/long, average error, every attempt with its signed error. Used right after practice
/// and in history, always from the configuration the session stored.
struct DrillSummaryView: View {
    let result: TargetDrillResult
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.locale) private var locale

    private var text: DrillText {
        DrillText(units: settings.units, locale: locale)
    }

    private var rateText: String {
        result.hitRate.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(locale)) } ?? "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("drill.summary.title").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text("drill.target \(text.distance(result.config.targetCarryM)) \(text.distance(result.config.longitudinalToleranceM))")
                .font(.headline)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("drill.summary.hits \(result.hits) \(result.scoredCount)")
                Text("drill.summary.rate \(rateText)")
                Text("drill.summary.bestStreak \(result.bestStreak)")
                Text("drill.summary.shortLong \(result.shortCount) \(result.longCount)")
                if let mean = result.meanSignedErrorM {
                    Text("drill.summary.meanError \(text.signed(mean))")
                }
                if result.isDistanceOnly {
                    Label { Text("drill.distanceOnly") } icon: { Image(systemName: "info.circle") }
                        .foregroundStyle(Tokens.textSecondary.color)
                }
                if !result.isComplete {
                    Text("drill.summary.incomplete \(result.scoredCount) \(result.config.attempts)")
                        .foregroundStyle(Tokens.textSecondary.color)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("drill.summary.numbers")
            ForEach(result.attempts, id: \.shotID) { attempt in
                let outcome = text.attempt(attempt, in: result.config)
                HStack {
                    Text(verbatim: "\(attempt.number)").frame(width: 28, alignment: .leading)
                    Text(verbatim: text.distance(attempt.carryM))
                    Spacer()
                    Text(verbatim: text.signed(attempt.longitudinalErrorM)).monospacedDigit()
                    Image(systemName: outcome.symbol).accessibilityHidden(true)
                    Text(outcome.text).font(.footnote)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("drill.attempt.\(attempt.number)")
            }
            Text("drill.summary.uncertainty").font(.footnote).foregroundStyle(Tokens.textSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DrillSummarySheet: View {
    let result: TargetDrillResult
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                DrillSummaryView(result: result).padding(Spacing.m)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("settings.done") }.accessibilityIdentifier("drill.summary.done")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Choose the drill: target, tolerance, attempts, clubs. Values are whole units in the golfer's own distance unit; the stored
/// configuration is SI. Sideways tolerance is shown but not offered until sideways landing is validated.
struct DrillSetupSheet: View {
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(BagStore.self) private var bag
    @SwiftUI.Environment(PracticeLauncher.self) private var practice
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.locale) private var locale
    @State private var target = 0.0
    @State private var tolerance = 0.0
    @State private var attempts = TargetDrillConfig.defaultAttempts
    @State private var allClubs = true
    @State private var chosen: Set<UUID> = []
    @State private var loaded = false

    private var units: DisplayUnits {
        settings.units
    }

    private var symbol: String {
        UnitConversion.symbol(for: .carry, units: units)
    }

    private var config: TargetDrillConfig? {
        try? TargetDrillConfig(
            targetCarryM: UnitConversion.si(target, for: .carry, units: units),
            longitudinalToleranceM: UnitConversion.si(tolerance, for: .carry, units: units),
            attempts: attempts, clubIDs: allClubs ? nil : chosen
        )
    }

    private func shown(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(locale)) + "\u{00A0}" + symbol
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $target, in: 5 ... 500, step: 5) { Text("drill.setup.target \(shown(target))") }
                        .accessibilityIdentifier("drill.setup.target")
                    Stepper(value: $tolerance, in: 1 ... 100, step: 1) { Text("drill.setup.tolerance \(shown(tolerance))") }
                        .accessibilityIdentifier("drill.setup.tolerance")
                    Stepper(value: $attempts, in: TargetDrillConfig.attemptRange) { Text("drill.setup.attempts \(attempts)") }
                        .accessibilityIdentifier("drill.setup.attempts")
                    Label { Text("drill.setup.lateral") } icon: { Image(systemName: "info.circle") }
                        .foregroundStyle(Tokens.textSecondary.color)
                        .accessibilityIdentifier("drill.setup.lateral")
                } header: {
                    Text("drill.setup.header").foregroundStyle(Tokens.textSecondary.color)
                }
                .listRowBackground(Tokens.surface.color)
                Section {
                    Toggle("drill.setup.allClubs", isOn: $allClubs).accessibilityIdentifier("drill.setup.allClubs")
                    if !allClubs {
                        if chosen.isEmpty {
                            Text("drill.setup.chooseClub").foregroundStyle(Tokens.textSecondary.color)
                                .accessibilityIdentifier("drill.setup.chooseClub")
                        }
                        ForEach(Array(bag.bag.active.enumerated()), id: \.element.id) { index, club in
                            Button {
                                if chosen.contains(club.id) {
                                    chosen.remove(club.id)
                                } else {
                                    chosen.insert(club.id)
                                }
                            } label: {
                                HStack {
                                    Text(verbatim: club.name)
                                    Spacer()
                                    if chosen.contains(club.id) {
                                        Image(systemName: "checkmark").accessibilityHidden(true)
                                    }
                                }
                                .frame(minHeight: Spacing.minTarget)
                            }
                            .accessibilityIdentifier("drill.setup.club.\(index)")
                            .accessibilityAddTraits(chosen.contains(club.id) ? .isSelected : [])
                        }
                    }
                } header: {
                    Text("drill.setup.clubs").foregroundStyle(Tokens.textSecondary.color)
                }
                .listRowBackground(Tokens.surface.color)
                Section {
                    Button {
                        if let config {
                            Task {
                                await practice.start(.target, drill: config)
                                dismiss()
                            }
                        }
                    } label: { Text("drill.setup.start").frame(maxWidth: .infinity, minHeight: Spacing.minTarget) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(config == nil)
                        .accessibilityIdentifier("drill.setup.start")
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.background.color)
            .navigationTitle(Text("drill.setup.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("privacy.delete.cancel") }.accessibilityIdentifier("drill.setup.cancel")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            target = UnitConversion.display(TargetDrillConfig.defaultTargetM, for: .carry, units: units).rounded()
            tolerance = UnitConversion.display(TargetDrillConfig.defaultLongitudinalToleranceM, for: .carry, units: units).rounded()
        }
    }
}
