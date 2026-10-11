import SwiftUI

@main
struct GolfLaunchrApp: App {
    @State private var navigation = AppNavigation()
    @State private var settings: SettingsStore

    init() {
        // Test-only launch argument: UI tests start from default settings.
        _settings = State(initialValue: SettingsStore(resetting: CommandLine.arguments.contains("-uiTestResetSettings")))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .environment(settings)
        }
    }
}
