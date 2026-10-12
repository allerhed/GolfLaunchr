import Capture
import Domain
import Foundation
@testable import GolfLaunchr
import Testing

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var requests = 0
    func add() {
        lock.lock(); requests += 1; lock.unlock()
    }

    var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return requests
    }
}

private struct CountingCamera: CameraAccess {
    let counter: CallCounter
    let result: CameraPermission
    func status() -> CameraPermission {
        .notDetermined
    }

    func request() async -> CameraPermission {
        counter.add()
        return result
    }
}

private struct StubInspector: DeviceInspecting {
    let formats: [CaptureFormatDescriptor]
    func facts() -> DeviceFacts {
        DeviceFacts(modelIdentifier: "Test1,1", osMajorVersion: 26, freeStorageBytes: 50_000_000_000, formats: formats)
    }
}

private let fast = CaptureFormatDescriptor(id: "f", lens: .wide, width: 1920, height: 1080, maxFrameRate: 240, fieldOfViewDegrees: 70)

@MainActor
private struct Rig {
    let store: OnboardingStore
    let settings: SettingsStore
    let counter: CallCounter
}

@MainActor
struct OnboardingStoreTests {
    private func suite() -> UserDefaults {
        let name = "onboarding-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { preconditionFailure("suite") }
        return defaults
    }

    private func make(
        defaults: UserDefaults? = nil,
        permission: CameraPermission = .authorized,
        formats: [CaptureFormatDescriptor] = [fast],
        counter: CallCounter = CallCounter()
    ) -> Rig {
        let settings = SettingsStore(defaults: defaults ?? suite())
        let store = OnboardingStore(
            settings: settings, camera: CountingCamera(counter: counter, result: permission), inspector: StubInspector(formats: formats)
        )
        return Rig(store: store, settings: settings, counter: counter)
    }

    @Test func handednessIsRequiredBeforeLeavingThatStepAndIsNeverInferred() {
        let rig = make()
        let store = rig.store
        let settings = rig.settings
        #expect(settings.swingHandedness == nil && !settings.onboardingCompleted)
        store.next(); store.next()
        #expect(store.step == .handedness && !store.canContinue)
        store.next()
        #expect(store.step == .handedness) // blocked
        store.choose(.left)
        #expect(store.canContinue)
        store.next()
        #expect(store.step == .device && settings.swingHandedness == .left)
    }

    @Test func theChoiceIsPersistedAndSurvivesRelaunch() {
        let defaults = suite()
        let rig = make(defaults: defaults)
        let store = rig.store
        store.choose(.left)
        store.finish()
        let relaunched = SettingsStore(defaults: defaults)
        #expect(relaunched.swingHandedness == .left && relaunched.onboardingCompleted)
    }

    @Test func theCameraIsOnlyRequestedWhenTheDeviceCheckIsPressed() async {
        let rig = make()
        let store = rig.store
        let counter = rig.counter
        store.next(); store.choose(.right); store.next(); store.next()
        #expect(counter.requestCount == 0 && store.report == nil) // reaching the device step asks nothing
        await store.checkDevice()
        #expect(counter.requestCount == 1 && store.permission == .authorized)
        #expect(store.report?.status == .experimental) // capable but unvalidated
    }

    @Test func deniedPermissionDoesNotCrashAndStillExplainsTheDevice() async {
        let rig = make(permission: .denied)
        let store = rig.store
        await store.checkDevice()
        #expect(store.permission == .denied && store.report?.status == .experimental)
    }

    @Test func aDeviceWithoutACameraIsUnsupportedYetOnboardingCanFinishForHistory() async {
        let rig = make(formats: [])
        let store = rig.store
        let settings = rig.settings
        await store.checkDevice()
        #expect(store.report?.status == .unsupported && store.report?.reasons == [.noCamera])
        store.finish()
        #expect(settings.onboardingCompleted)
    }

    @Test func skippingNeedsNoHandednessAndLeavesItUnset() {
        let rig = make()
        let store = rig.store
        let settings = rig.settings
        let counter = rig.counter
        store.finish() // "Use history only" on the first screen
        #expect(settings.onboardingCompleted && settings.swingHandedness == nil && counter.requestCount == 0)
    }

    @Test func backNeverLeavesTheFirstStepAndRepeatingKeepsTheChoice() {
        let rig = make()
        let store = rig.store
        let settings = rig.settings
        store.back()
        #expect(store.step == .welcome)
        store.next(); store.next(); store.choose(.right); store.back()
        #expect(store.step == .placement && settings.swingHandedness == .right)
    }

    @Test func resettingForTestsClearsOnboardingAndHandedness() {
        let defaults = suite()
        let first = SettingsStore(defaults: defaults)
        first.swingHandedness = .left
        first.onboardingCompleted = true
        let fresh = SettingsStore(defaults: defaults, resetting: true)
        #expect(fresh.swingHandedness == nil && !fresh.onboardingCompleted)
    }
}
