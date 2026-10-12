import Capture
import Domain
import Foundation
import Observation

/// State of the setup screen: the swing side (shared with Settings), the calibration state, the live scene and what follows from them.
@MainActor @Observable
final class SetupModel {
    private let settings: SettingsStore
    private let observer: any EnvironmentObserving
    private let capability: CapabilityStatus
    private var task: Task<Void, Never>?

    private(set) var state: SetupState
    private(set) var observation = SetupObservation()
    var mode = SetupMode.scored

    init(settings: SettingsStore, observer: any EnvironmentObserving, capability: CapabilityStatus, calibration: CalibrationState = .none) {
        self.settings = settings
        self.observer = observer
        self.capability = capability
        state = SetupState(handedness: settings.swingHandedness, calibration: calibration)
    }

    var context: SetupContext {
        SetupContext(mode: mode, capability: capability, handedness: state.handedness, calibration: state.calibration)
    }

    var readiness: SetupReadinessResult {
        SetupReadiness.evaluate(observation, context)
    }

    var rows: [SetupCheckRow] {
        SetupChecks.rows(observation, readiness)
    }

    var needsHandednessConfirmation: Bool {
        state.pendingHandedness != nil
    }

    func startObserving() {
        guard task == nil else { return }
        let stream = observer.start()
        task = Task { [weak self] in
            for await next in stream {
                self?.observation = next
            }
        }
    }

    func stopObserving() {
        observer.stop()
        task?.cancel()
        task = nil
    }

    func choose(_ handedness: SwingHandedness) {
        if state.requestHandedness(handedness) == .applied {
            settings.swingHandedness = handedness
        }
    }

    func confirmHandednessChange() {
        state.confirmHandednessChange()
        settings.swingHandedness = state.handedness
    }

    func cancelHandednessChange() {
        state.cancelHandednessChange()
    }
}
