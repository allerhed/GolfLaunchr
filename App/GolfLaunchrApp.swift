import Domain
import Persistence
import SwiftUI

@main
struct GolfLaunchrApp: App {
    @State private var navigation = AppNavigation()
    @State private var settings: SettingsStore
    @State private var bagStore: BagStore

    init() {
        let arguments = CommandLine.arguments
        // Test-only launch arguments: UI tests start from default settings and a throwaway database.
        _settings = State(initialValue: SettingsStore(resetting: arguments.contains("-uiTestResetSettings")))
        let testFile = arguments.firstIndex(of: "-uiTestStoreFile").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        _bagStore = State(initialValue: Self.makeBagStore(testFile: testFile))
    }

    private static func makeBagStore(testFile: String?) -> BagStore {
        do {
            let url = try testFile.map { URL(fileURLWithPath: $0) } ?? defaultStoreURL()
            return try BagStore(repository: SQLiteStore(url: url), seedName: BagSeedNames.localized)
        } catch {
            // A store that cannot be opened is reported, never replaced by a new empty one.
            return BagStore(repository: nil, failureMessage: "\(error)", seedName: BagSeedNames.localized)
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
        }
    }
}
