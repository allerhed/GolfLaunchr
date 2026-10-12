import Domain
import Persistence
import SwiftUI

@main
struct GolfLaunchrApp: App {
    @State private var navigation = AppNavigation()
    @State private var settings: SettingsStore
    @State private var bagStore: BagStore
    @State private var historyStore: HistoryStore

    init() {
        let arguments = CommandLine.arguments
        // Test-only launch arguments: UI tests start from default settings and a throwaway database.
        _settings = State(initialValue: SettingsStore(resetting: arguments.contains("-uiTestResetSettings")))
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
    }

    /// One database serves the bag and the history. A database that cannot be opened is reported, never replaced by a new empty one.
    private static func makeStores(testFile: String?, seedDemo: Bool) -> (bag: BagStore, history: HistoryStore) {
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
            return (
                BagStore(repository: store, seedName: BagSeedNames.localized),
                HistoryStore(backend: store, prepare: prepare)
            )
        } catch {
            return (
                BagStore(repository: nil, failureMessage: "\(error)", seedName: BagSeedNames.localized),
                HistoryStore(backend: nil, failureMessage: "\(error)")
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
        }
    }
}
