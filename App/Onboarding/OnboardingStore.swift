import Capture
import Domain
import Foundation
import Observation

/// State of the onboarding flow. Handedness is stored in `SettingsStore` the moment it is chosen. The camera permission is
/// requested only when the person presses "Check camera" (F01: not at launch).
@MainActor @Observable
final class OnboardingStore {
    enum Step: Int, CaseIterable {
        case welcome, placement, handedness, device
    }

    private let settings: SettingsStore
    private let camera: any CameraAccess
    private let inspector: any DeviceInspecting
    private let validatedModels: Set<String>

    var step = Step.welcome
    private(set) var permission: CameraPermission
    private(set) var report: CapabilityReport?
    private(set) var isChecking = false

    init(
        settings: SettingsStore,
        camera: any CameraAccess,
        inspector: any DeviceInspecting,
        validatedModels: Set<String> = []
    ) {
        self.settings = settings
        self.camera = camera
        self.inspector = inspector
        self.validatedModels = validatedModels
        permission = camera.status()
    }

    var canContinue: Bool {
        step != .handedness || settings.swingHandedness != nil
    }

    var isLastStep: Bool {
        step == Step.allCases.last
    }

    func next() {
        guard canContinue, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    func back() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    func choose(_ handedness: SwingHandedness) {
        settings.swingHandedness = handedness
    }

    func checkDevice() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        permission = await camera.request()
        report = CapabilityQualifier.qualify(inspector.facts(), validatedModels: validatedModels)
    }

    /// Finishing and skipping both end onboarding. History never needs the camera.
    func finish() {
        settings.onboardingCompleted = true
    }
}
