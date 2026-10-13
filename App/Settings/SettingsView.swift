import Domain
import Flight
import Formatting
import SwiftUI
import Voice

struct SettingsView: View {
    @SwiftUI.Environment(SettingsStore.self) private var settings
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(VoiceController.self) private var voiceController
    @State private var pressureText = ""
    @State private var temperatureText = ""
    #if CAPTURE_HARNESS
        @State private var showingHarness = false
    #endif

    private var languageSection: some View {
        @Bindable var settings = settings
        return Section {
            Picker("settings.language", selection: Binding(
                get: { settings.language },
                set: { new in
                    settings.language = new
                    voiceController.stop() // stale speech in the old language is dropped
                }
            )) {
                Text("settings.language.system").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "Svenska").tag(AppLanguage.swedish)
            }
            .accessibilityIdentifier("settings.language")
        } header: {
            Text("settings.language", comment: "Section header: app language")
        } footer: {
            Text("settings.language.footer", comment: "Language changes the app and speech, nothing else")
        }
        .listRowBackground(Tokens.surface.color)
    }

    private var handednessSection: some View {
        Section {
            Picker("setup.handedness", selection: Binding(
                get: { settings.swingHandedness },
                set: { settings.swingHandedness = $0 }
            )) {
                Text("settings.handedness.unset").tag(SwingHandedness?.none)
                Text("onboarding.handedness.right").tag(SwingHandedness?.some(.right))
                Text("onboarding.handedness.left").tag(SwingHandedness?.some(.left))
            }
            .accessibilityIdentifier("settings.handedness")
        } header: {
            Text("setup.handedness", comment: "Section header: swing handedness")
        } footer: {
            Text("settings.handedness.footer", comment: "Changing swing side needs a new calibration")
        }
        .listRowBackground(Tokens.surface.color)
    }

    private var atmosphereSection: some View {
        @Bindable var settings = settings
        return Section {
            Picker("settings.atmosphere", selection: Binding(
                get: { settings.atmosphere.mode },
                set: { settings.atmosphere.mode = $0 }
            )) {
                Text("settings.atmosphere.standard").tag(AtmosphereSetting.Mode.standard)
                Text("settings.atmosphere.manual").tag(AtmosphereSetting.Mode.manual)
            }
            .adaptiveSegmented()
            .accessibilityIdentifier("settings.atmosphere")
            if settings.atmosphere.mode == .manual {
                numberField("settings.atmosphere.pressure", text: $pressureText, id: "settings.atmosphere.pressure") { value in
                    settings.atmosphere.pressureHPa = value
                    settings.atmosphere.enteredAt = Date()
                }
                numberField("settings.atmosphere.temperature", text: $temperatureText, id: "settings.atmosphere.temperature") { value in
                    settings.atmosphere.temperatureC = value
                    settings.atmosphere.enteredAt = Date()
                }
                ForEach(settings.atmosphere.problems(), id: \.rawValue) { problem in
                    Label { Text(problem.titleKey) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .foregroundStyle(Tokens.textPrimary.color)
                        .accessibilityIdentifier("settings.atmosphere.problem.\(problem.rawValue)")
                }
                if case .manual(_, true) = settings.atmosphere.resolve(now: Date()) {
                    Label { Text("settings.atmosphere.stale") } icon: { Image(systemName: "clock.badge.exclamationmark") }
                        .accessibilityIdentifier("settings.atmosphere.stale")
                }
            }
            Text("settings.atmosphere.ambient", comment: "No automatic barometer reading yet")
                .font(.footnote).foregroundStyle(Tokens.textSecondary.color)
        } header: {
            Text("settings.atmosphere", comment: "Section header: air pressure and temperature")
        } footer: {
            Text("settings.atmosphere.footer", comment: "Use absolute pressure; distances are estimates")
        }
        .listRowBackground(Tokens.surface.color)
        .onAppear { loadFieldTexts() }
    }

    private func numberField(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        id: String,
        commit: @escaping (Double?) -> Void
    ) -> some View {
        LabeledContent {
            TextField("", text: text)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .onChange(of: text.wrappedValue) { _, new in
                    commit(NumberInput.parse(new, locale: locale))
                }
                .accessibilityIdentifier(id)
        } label: {
            Text(title)
        }
        .frame(minHeight: Spacing.minTarget)
    }

    private func loadFieldTexts() {
        if let p = settings.atmosphere.pressureHPa {
            pressureText = formatter.number(p, fractionDigits: 1)
        }
        if let t = settings.atmosphere.temperatureC {
            temperatureText = formatter.number(t, fractionDigits: 1)
        }
    }

    private var privacySection: some View {
        Section {
            Label { Text("settings.privacy.text") } icon: { Image(systemName: "lock.iphone") }
                .accessibilityIdentifier("settings.privacy.text")
        } header: {
            Text("settings.privacy", comment: "Section header: privacy")
        }
        .listRowBackground(Tokens.surface.color)
    }

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
                languageSection
                handednessSection
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
                    .adaptiveSegmented()
                    .accessibilityIdentifier("settings.appearance")
                } header: {
                    Text("settings.appearance", comment: "Section header for light/dark theme")
                }
                .listRowBackground(Tokens.surface.color)
                voiceSection
                atmosphereSection
                privacySection
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("settings.form")
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
