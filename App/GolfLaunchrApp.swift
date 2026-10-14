import Allowance
import Capture
import Domain
import Persistence
import SwiftUI
import Voice

@main
struct GolfLaunchrApp: App {
    @State private var navigation = AppNavigation()
    @State private var settings: SettingsStore
    @State private var bagStore: BagStore
    @State private var historyStore: HistoryStore
    @State private var onboarding: OnboardingStore
    @State private var setupLauncher: SetupLauncher
    @State private var practiceLauncher: PracticeLauncher
    @State private var voice: VoiceController
    @State private var analysis: AnalysisStore
    @State private var allowance: AllowanceStore
    @State private var commerce: CommerceStore
    @State private var privacy: PrivacyStore

    init() {
        let arguments = CommandLine.arguments
        // Test-only launch arguments: UI tests start from default settings and a throwaway database.
        let resetting = arguments.contains("-uiTestResetSettings")
        let settingsStore = SettingsStore(resetting: resetting)
        // UI tests skip onboarding unless they ask for it, so the other screens can be tested directly.
        if resetting, !arguments.contains("-uiTestShowOnboarding") {
            settingsStore.onboardingCompleted = true
        }
        _settings = State(initialValue: settingsStore)
        _onboarding = State(initialValue: Self.makeOnboarding(settingsStore, arguments: arguments))
        let launcher = Self.makeSetupLauncher(settingsStore, arguments: arguments)
        _setupLauncher = State(initialValue: launcher)
        let testFile = arguments.firstIndex(of: "-uiTestStoreFile").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        // Demo data can be requested in Debug builds only: the flag is not even parsed in Release.
        #if DEBUG
            let seedDemo = arguments.contains("-uiTestSeedHistory")
        #else
            let seedDemo = false
        #endif
        let stores = Self.makeStores(testFile: testFile, seedDemo: seedDemo)
        _bagStore = State(initialValue: stores.bag)
        _historyStore = State(initialValue: stores.history)
        let allowanceStore = AllowanceStore(backend: stores.backend, defaults: Self.allowanceDefaults(arguments))
        #if DEBUG
            allowanceStore.extraEntries = Self.debugLedger(arguments)
        #endif
        let commerceStore = CommerceStore(store: Self.makeStore(arguments), defaults: Self.commerceDefaults(arguments))
        allowanceStore.entitlement = { commerceStore.activeEntitlement }
        _commerce = State(initialValue: commerceStore)
        let analysisStore = AnalysisStore(history: stores.history, bag: stores.bag, defaults: Self.analysisDefaults(arguments))
        _analysis = State(initialValue: analysisStore)
        _privacy = State(initialValue: PrivacyStore(
            backend: stores.backend, media: Self.makeMedia(testFile: testFile),
            afterDeletion: {
                await stores.history.refresh()
                await stores.bag.reloadAfterDeletion()
                analysisStore.resetAfterDeletion()
                await allowanceStore.refresh()
            }
        ))
        _allowance = State(initialValue: allowanceStore)
        let voiceController = VoiceController(
            settings: settingsStore, synthesizer: Self.makeSynthesizer(arguments), locale: { settingsStore.effectiveLocale }
        )
        _voice = State(initialValue: voiceController)
        _practiceLauncher = State(initialValue: PracticeLauncher(
            bagStore: stores.bag, settings: settingsStore, backend: stores.backend, voice: voiceController,
            makeSetup: { launcher.makeModel() }
        ))
    }

    /// Setup screen model factory. Debug builds started with `-uiTestSetupScene <scene>` use a fake scene instead of the camera, and
    /// `-uiTestSetupCalibrated` starts with a valid calibration.
    private static func makeSetupLauncher(_ settings: SettingsStore, arguments: [String]) -> SetupLauncher {
        var observer: any EnvironmentObserving = LiveEnvironmentObserver()
        var inspector: any DeviceInspecting = LiveDeviceInspector()
        var calibration = CalibrationState.none
        #if DEBUG
            if let index = arguments.firstIndex(of: "-uiTestSetupScene"), arguments.indices.contains(index + 1) {
                observer = FakeEnvironmentObserver(scene: arguments[index + 1])
                inspector = FakeDeviceInspector(hasCamera: true)
            }
            if arguments.contains("-uiTestSetupCalibrated") {
                calibration = .valid
            }
        #endif
        return SetupLauncher {
            SetupModel(
                settings: settings, observer: observer, capability: CapabilityQualifier.qualify(inspector.facts()).status,
                calibration: calibration
            )
        }
    }

    /// The system voice; Debug builds started with `-uiTestFakeVoice` use a silent recorder.
    private static func makeSynthesizer(_ arguments: [String]) -> any SpeechSynthesizing {
        #if DEBUG
            if arguments.contains("-uiTestFakeVoice") {
                return RecordingSynthesizer()
            }
        #endif
        return SystemSpeechSynthesizer()
    }

    #if DEBUG
        /// `-uiTestAllowanceSpent <n>` adds n spent introductory credits in memory (Debug builds only), to reach the exhausted state.
        private static func debugLedger(_ arguments: [String]) -> [LedgerEntry] {
            guard let index = arguments.firstIndex(of: "-uiTestAllowanceSpent"), arguments.indices.contains(index + 1),
                  let count = Int(arguments[index + 1]) else { return [] }
            return (0 ..< count).compactMap { _ in
                try? LedgerEntry(
                    acceptedShotID: UUID(),
                    allowanceKind: .introductory,
                    periodID: "intro",
                    creditCost: 1,
                    committedAt: Date()
                )
            }
        }
    #endif

    /// StoreKit 2; Debug builds started with `-uiTestStore <scenario>` use a scripted store (no purchase, no network).
    private static func makeStore(_ arguments: [String]) -> any StoreProviding {
        #if DEBUG
            if let index = arguments.firstIndex(of: "-uiTestStore"), arguments.indices.contains(index + 1),
               let scenario = ScriptedStore.Scenario(rawValue: arguments[index + 1]) {
                return ScriptedStore(scenario)
            }
        #endif
        return LiveStore()
    }

    private static func commerceDefaults(_ arguments: [String]) -> UserDefaults {
        if arguments.contains("-uiTestResetSettings") {
            UserDefaults.standard.removeObject(forKey: CommerceStore.entitlementKey)
        }
        return .standard
    }

    /// Media (clips, images) live beside the database; UI tests keep theirs next to the throwaway database.
    private static func makeMedia(testFile: String?) -> MediaDirectory? {
        let root: URL? = if let testFile {
            URL(fileURLWithPath: testFile).deletingLastPathComponent().appendingPathComponent("media-files", isDirectory: true)
        } else {
            try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("GolfLaunchr", isDirectory: true).appendingPathComponent("Media", isDirectory: true)
        }
        return root.flatMap { try? MediaDirectory(root: $0) }
    }

    /// The device-local allowance state; UI tests that reset settings also start a fresh allowance.
    private static func allowanceDefaults(_ arguments: [String]) -> UserDefaults {
        if arguments.contains("-uiTestResetSettings") {
            UserDefaults.standard.removeObject(forKey: AllowanceStore.stateKey)
        }
        return .standard
    }

    /// Applied analysis filters persist in the normal defaults; UI tests that reset settings also reset them.
    private static func analysisDefaults(_ arguments: [String]) -> UserDefaults {
        if arguments.contains("-uiTestResetSettings") {
            UserDefaults.standard.removeObject(forKey: "analysis.filter")
        }
        return .standard
    }

    /// Live camera services; Debug builds started with `-uiTestFakeCamera authorized|denied|none` use doubles (no system prompt).
    private static func makeOnboarding(_ settings: SettingsStore, arguments: [String]) -> OnboardingStore {
        #if DEBUG
            if let index = arguments.firstIndex(of: "-uiTestFakeCamera"), arguments.indices.contains(index + 1) {
                let mode = arguments[index + 1]
                return OnboardingStore(
                    settings: settings, camera: FakeCameraAccess(result: mode == "denied" ? .denied : .authorized),
                    inspector: FakeDeviceInspector(hasCamera: mode != "none")
                )
            }
        #endif
        return OnboardingStore(settings: settings, camera: LiveCameraAccess(), inspector: LiveDeviceInspector())
    }

    private struct AppStores {
        let bag: BagStore
        let history: HistoryStore
        let backend: SQLiteStore?
    }

    /// One database serves the bag and the history. A database that cannot be opened is reported, never replaced by a new empty one.
    private static func makeStores(testFile: String?, seedDemo: Bool) -> AppStores {
        do {
            let url = try testFile.map { URL(fileURLWithPath: $0) } ?? defaultStoreURL()
            // Synthetic (demo) shots are accepted only in Debug builds started with the test launch argument.
            #if DEBUG
                let allowDemo = seedDemo && testFile != nil
            #else
                let allowDemo = false
            #endif
            let store = try SQLiteStore(url: url, allowsSynthetic: allowDemo)
            var prepare: (() async -> Void)?
            #if DEBUG
                if allowDemo {
                    prepare = { await HistoryFixtures.seedIfEmpty(store) }
                }
            #endif
            return AppStores(
                bag: BagStore(repository: store, seedName: BagSeedNames.localized),
                history: HistoryStore(backend: store, prepare: prepare), backend: store
            )
        } catch {
            return AppStores(
                bag: BagStore(repository: nil, failureMessage: "\(error)", seedName: BagSeedNames.localized),
                history: HistoryStore(backend: nil, failureMessage: "\(error)"), backend: nil
            )
        }
    }

    private static func defaultStoreURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("GolfLaunchr", isDirectory: true).appendingPathComponent("golflaunchr.sqlite")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .environment(settings)
                .environment(bagStore)
                .environment(historyStore)
                .environment(onboarding)
                .environment(setupLauncher)
                .environment(practiceLauncher)
                .environment(voice)
                .environment(analysis)
                .environment(allowance)
                .environment(commerce)
                .environment(privacy)
        }
    }
}
