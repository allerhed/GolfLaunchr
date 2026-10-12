import Domain
import Formatting
import Foundation
@testable import GolfLaunchr
import Modes
import PersistenceTestSupport
import Testing
import Voice

/// Keeps what was said and lets a test finish an utterance when it chooses (a real voice takes time).
private final class ManualSynthesizer: SpeechSynthesizing, @unchecked Sendable {
    var onFinished: (@Sendable (UUID) -> Void)?
    private(set) var spoken: [(id: UUID, text: String)] = []
    private(set) var stops = 0

    func speak(_ text: String, languageCode _: String, id: UUID) {
        spoken.append((id, text))
    }

    func stop() {
        stops += 1
    }

    func finishCurrent() {
        if let last = spoken.last {
            onFinished?(last.id)
        }
    }
}

@MainActor
struct VoiceControllerTests {
    private func settings() -> SettingsStore {
        guard let defaults = UserDefaults(suiteName: "voice-tests-\(UUID().uuidString)") else { preconditionFailure("suite") }
        return SettingsStore(defaults: defaults)
    }

    private func controller(_ settings: SettingsStore, _ synth: ManualSynthesizer) -> VoiceController {
        VoiceController(settings: settings, synthesizer: synth, locale: { Locale(identifier: "en") })
    }

    private func shot(carry: Double = 130) throws -> Shot {
        try Shot(
            id: UUID(), sessionID: UUID(), sequence: 1, mode: .practice, swingHandedness: .right,
            clubSnapshot: ClubSnapshot(id: UUID(), name: "7i", loftRad: nil), calibrationID: UUID(), impactTimeUTC: Date(),
            metrics: [
                .carry: Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional),
                .ballSpeed: Domain.Measurement(key: .ballSpeed, value: 45, provenance: .measured, quality: .valid),
            ],
            environment: Environment(pressurePa: 1, temperatureK: 1, source: .standard),
            versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t")
        )
    }

    @Test func aResultIsSpokenInTheChosenUnitsAndAlsoShownAsText() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        try voice.announce(shot())
        #expect(synth.spoken.map(\.text) == ["Estimated carry: 130 metres. Ball speed: 162.0 kilometres per hour."])
        #expect(voice.caption == synth.spoken.first?.text)
    }

    @Test func changingUnitsChangesTheSpokenValueButNotTheStoredShot() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        let stored = try shot()
        s.units = DisplayUnits(distance: .yards, speed: .milesPerHour)
        voice.announce(stored)
        #expect(synth.spoken.first?.text == "Estimated carry: 142 yards. Ball speed: 100.7 miles per hour.")
        #expect(stored.value(.carry) == 130)
    }

    /// F07: silent mode never blocks capture; the text still appears.
    @Test func mutedSpeaksNothingButKeepsTheCaption() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        s.voice.enabled = false
        voice.apply(s.voice)
        voice.prompt(.ready)
        try voice.announce(shot())
        #expect(synth.spoken.isEmpty && voice.caption != nil && voice.isMuted)
    }

    @Test func mutingWhileSpeakingStopsTheVoice() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        try voice.announce(shot())
        s.voice.enabled = false
        voice.apply(s.voice)
        #expect(synth.stops == 1)
    }

    @Test func aBurstOfResultsSpeaksTheFirstAndOnlyTheLatestWaiting() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        for carry in [100.0, 110, 120, 130] {
            try voice.announce(shot(carry: carry))
        }
        #expect(synth.spoken.count == 1)
        synth.finishCurrent()
        // finishing is delivered on the main actor; give it a turn
        #expect(voice.caption?.contains("130") == true)
    }

    @Test func armingSpeaksReadyThenHoldsUntilTheShotIsAccepted() async throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = controller(s, synth)
        let store = InMemoryStore(allowsSynthetic: true)
        let clubs = ["Driver", "7 iron"].enumerated().compactMap { try? Club(name: $1, category: .iron, loftRad: nil, sortOrder: $0) }
        let practice = await PracticeStore.start(.standard, bag: Bag(clubs: clubs), settings: s, backend: store, voice: voice)
        let p = try #require(practice)
        #expect(p.arm(setupReady: false) == .blocked(.setupNotReady) && synth.spoken.isEmpty) // blocked: no prompt
        #expect(p.arm(setupReady: true) == .armed && synth.spoken.map(\.text) == ["Ready."])
        voice.prompt(.reposition) // still speaking and held while armed: waits
        #expect(synth.spoken.count == 1)
        p.togglePause() // pausing disarms: stops what is being said and forgets what waited
        #expect(synth.stops == 1)
        synth.finishCurrent()
        await Task.yield()
        #expect(synth.spoken.count == 1) // the waiting reposition prompt was dropped, not spoken later
    }

    @Test func voicePreferencesPersistAcrossRelaunch() {
        guard let defaults = UserDefaults(suiteName: "voice-prefs-\(UUID().uuidString)") else { preconditionFailure("suite") }
        let first = SettingsStore(defaults: defaults)
        #expect(first.voice == .default)
        first.voice = VoicePreferences(enabled: false, metrics: [.verticalLaunch, .carry])
        let second = SettingsStore(defaults: defaults)
        #expect(second.voice == VoicePreferences(enabled: false, metrics: [.carry, .verticalLaunch]))
        #expect(SettingsStore(defaults: defaults, resetting: true).voice == .default)
    }

    @Test func swedishSpeechUsesTheAppLanguage() throws {
        let s = settings(), synth = ManualSynthesizer()
        let voice = VoiceController(settings: s, synthesizer: synth, locale: { Locale(identifier: "sv") })
        try voice.announce(shot())
        #expect(synth.spoken.first?.text == "Beräknad flyglängd: 130 meter. Bollhastighet: 162,0 kilometer i timmen.")
    }
}
