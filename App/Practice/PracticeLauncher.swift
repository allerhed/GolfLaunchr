import Domain
import Modes
import Observation
import Persistence

/// Starts a practice session and presents the practice screen; one at a time.
@MainActor @Observable
final class PracticeLauncher {
    private let bagStore: BagStore
    private let settings: SettingsStore
    private let backend: (any PersistenceStore)?
    private let makeSetup: @MainActor () -> SetupModel
    private let voice: VoiceController?
    var store: PracticeStore?
    private(set) var setupModel: SetupModel?
    private(set) var failed = false
    private var isStarting = false

    init(
        bagStore: BagStore,
        settings: SettingsStore,
        backend: (any PersistenceStore)?,
        voice: VoiceController? = nil,
        makeSetup: @escaping @MainActor () -> SetupModel
    ) {
        self.makeSetup = makeSetup
        self.voice = voice
        self.bagStore = bagStore
        self.settings = settings
        self.backend = backend
    }

    var isAvailable: Bool {
        backend != nil
    }

    func start(_ mode: PracticeMode) async {
        guard !isStarting, store == nil, let backend else { return }
        isStarting = true
        defer { isStarting = false }
        await bagStore.load()
        failed = false
        guard !bagStore.bag.active.isEmpty,
              let started = await PracticeStore.start(mode, bag: bagStore.bag, settings: settings, backend: backend, voice: voice)
        else {
            failed = true
            return
        }
        setupModel = makeSetup()
        store = started
    }

    /// Run once at launch: sessions cut short by a crash or kill are closed with the shots they have (empty ones are dropped).
    func recoverInterrupted() async {
        guard let backend else { return }
        _ = try? await SessionLifecycle(sessions: backend, shots: backend).recoverInterrupted()
    }
}
