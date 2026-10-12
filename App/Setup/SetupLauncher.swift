import Capture
import Foundation
import Observation

/// Opens the setup screen with a fresh `SetupModel` (and so a fresh camera session) each time.
@MainActor @Observable
final class SetupLauncher {
    private let make: () -> SetupModel
    var model: SetupModel?

    init(make: @escaping () -> SetupModel) {
        self.make = make
    }

    func open() {
        model = make()
    }
}
