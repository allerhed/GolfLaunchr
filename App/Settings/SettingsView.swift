import Formatting
import SwiftUI
import Voice

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(VoiceController.self) private var voiceController
    #if CAPTURE_HARNESS
        @State private var showingHarness = false
    #endif

    private var voiceSection: some View {
        @Bindable var settings = settings
        return Section {
            Toggle("settings.voice.enabled", isOn: Binding(
                get: { settings.voice.enabled },
                set: { settings.voice.enabled = $0; voiceController.apply(settings.voice) }
            ))
            .accessibilityIdentifier("settings.voice.enabled")
            ForEach(SpokenMetric.allCases, id: \.rawValue) { metric in
                Toggle(metric.titleKey, isOn: Binding(
                    get: { settings.voice.metrics.contains(metric) },
                    set: { on in
                        if on {
                            settings.voice.metrics.insert(metric)
                        } else {
                            settings.voice.metrics.remove(metric)
                        }
                    }
                ))
                .disabled(!settings.voice.enabled)
                .accessibilityIdentifier("settings.voice.\(metric.rawValue)")
            }
            Button { voiceController.preview() } label: { Text("settings.voice.preview").frame(minHeight: Spacing.minTarget) }
                .disabled(!settings.voice.enabled || settings.voice.metrics.isEmpty)
                .accessibilityIdentifier("settings.voice.preview")
        } header: {
            Text("settings.voice", comment: "Section header: spoken results")
        } footer: {
            Text("settings.voice.footer", comment: "Explains spoken results never block capture and follow the units")
        }
        .listRowBackground(Tokens.surface.color)
    }

    private var formatter: MetricFormatter {
        MetricFormatter(units: settings.units, locale: locale)
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("settings.distance", selection: $settings.units.distance) {
                        Text("unit.metres").tag(DistanceUnit.metres)
                        Text("unit.yards").tag(DistanceUnit.yards)
                    }
                    .accessibilityIdentifier("settings.distance")
                    Picker("settings.speed", selection: $settings.units.speed) {
                        Text("unit.mps").tag(SpeedUnit.metresPerSecond)
                        Text("unit.kmh").tag(SpeedUnit.kilometresPerHour)
                        Text("unit.mph").tag(SpeedUnit.milesPerHour)
                    }
                    .accessibilityIdentifier("settings.speed")
                    exampleRow(
                        "settings.example.distance",
                        value: formatter.format(100, for: .carry)?.text,
                        id: "settings.example.distance"
                    )
                    exampleRow("settings.example.speed", value: formatter.format(30, for: .ballSpeed)?.text, id: "settings.example.speed")
                } header: {
                    Text("settings.units", comment: "Section header for distance and speed units")
                } footer: {
                    Text("settings.units.footer", comment: "Explains that units only change display")
                }
                .listRowBackground(Tokens.surface.color)
                Section {
                    Picker("settings.appearance", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.titleKey).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance")
                } header: {
                    Text("settings.appearance", comment: "Section header for light/dark theme")
                }
                .listRowBackground(Tokens.surface.color)
                voiceSection
            }
            .scrollContentBackground(.hidden)
            #if CAPTURE_HARNESS
                .safeAreaInset(edge: .bottom) {
                    Button { showingHarness = true } label: { Text(verbatim: "Open capture harness (DEBUG)") }
                        .buttonStyle(.bordered)
                        .padding()
                        .accessibilityIdentifier("settings.openHarness")
                }
                .fullScreenCover(isPresented: $showingHarness) { HarnessView() }
            #endif
                .background(Tokens.background.color)
                .navigationTitle(Text("settings.title", comment: "Settings screen title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("settings.done") { dismiss() }
                            .frame(minHeight: Spacing.minTarget)
                            .accessibilityIdentifier("settings.done")
                    }
                }
        }
        .accessibilityIdentifier("settings.root")
    }

    /// A fixed, labelled example (100 m, 30 m/s) so the effect of a unit choice is visible. Not a measurement.
    private func exampleRow(_ label: LocalizedStringKey, value: String?, id: String) -> some View {
        LabeledContent {
            Text(value ?? "–")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Tokens.textPrimary.color)
                .accessibilityIdentifier(id)
        } label: {
            Text(label)
        }
        .foregroundStyle(Tokens.textSecondary.color)
    }
}
