import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, camera: String = "authorized", reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestFakeCamera", camera]
        if reset {
            args += ["-uiTestResetSettings", "-uiTestShowOnboarding"]
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        Thread.sleep(forTimeInterval: 0.6)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func tap(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "missing \(id)")
        button.tap()
    }

    /// The whole flow, in one language and orientation, with the human-visible checks at each step.
    func runFlow(_ lang: String, orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let tag = "\(lang)-\(orientation.isLandscape ? "land" : "port")"
        let app = launch(lang)
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.title"].label, lang == "sv" ? "Välkommen till GolfLaunchr" : "Welcome to GolfLaunchr")
        shot("onboarding-\(tag)-1-welcome")
        tap(app, "onboarding.next")
        shot("onboarding-\(tag)-2-placement")
        tap(app, "onboarding.next")
        // Handedness is required: Continue is disabled until one is chosen.
        XCTAssertTrue(app.buttons["onboarding.handedness.left"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.next"].isEnabled)
        XCTAssertTrue(app.staticTexts["onboarding.handedness.required"].exists)
        shot("onboarding-\(tag)-3-handedness-empty")
        app.buttons["onboarding.handedness.left"].tap()
        XCTAssertTrue(app.buttons["onboarding.next"].isEnabled)
        XCTAssertFalse(app.staticTexts["onboarding.handedness.required"].exists)
        XCTAssertEqual(app.buttons["onboarding.handedness.left"].label.contains(lang == "sv" ? "Vänstersving" : "Left-handed"), true)
        shot("onboarding-\(tag)-4-handedness-left")
        tap(app, "onboarding.next")
        // Nothing about the device is shown (or asked) until the person presses Check camera.
        XCTAssertFalse(app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'onboarding.device.status'")).firstMatch
            .exists)
        tap(app, "onboarding.device.check")
        XCTAssertTrue(
            app.staticTexts["onboarding.device.status.experimental"].waitForExistence(timeout: 5)
                || app.otherElements["onboarding.device.status.experimental"].waitForExistence(timeout: 2),
            "capable but unvalidated = Experimental"
        )
        shot("onboarding-\(tag)-5-device")
        tap(app, "onboarding.finish")
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8), "Home after onboarding")
        shot("onboarding-\(tag)-6-home")
        // Relaunch without reset: onboarding is done and is not shown again; the choice persisted.
        app.terminate()
        let again = launch(lang, reset: false)
        XCTAssertTrue(again.staticTexts["home.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(again.buttons["onboarding.next"].exists)
    }

    func testFullFlowEnglishPortrait() {
        runFlow("en", orientation: .portrait)
    }

    func testFullFlowSwedishLandscape() {
        runFlow("sv", orientation: .landscapeLeft)
    }

    /// Denied camera access: explains it, offers Settings, does not crash, and still reports the device.
    func testDeniedCameraOffersSettingsAndStillFinishes() {
        let app = launch("en", camera: "denied")
        tap(app, "onboarding.next")
        tap(app, "onboarding.next")
        app.buttons["onboarding.handedness.right"].tap()
        tap(app, "onboarding.next")
        tap(app, "onboarding.device.check")
        XCTAssertTrue(app.staticTexts["onboarding.device.denied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.device.openSettings"].exists)
        shot("onboarding-denied")
        tap(app, "onboarding.finish")
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8))
    }

    /// A device with no camera is Not supported, but history stays reachable.
    func testUnsupportedDeviceCanStillUseHistory() {
        let app = launch("en", camera: "none")
        tap(app, "onboarding.next")
        tap(app, "onboarding.next")
        app.buttons["onboarding.handedness.right"].tap()
        tap(app, "onboarding.next")
        tap(app, "onboarding.device.check")
        XCTAssertTrue(app.staticTexts["onboarding.device.reason.noCamera"].waitForExistence(timeout: 5))
        shot("onboarding-unsupported")
        tap(app, "onboarding.finish")
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: 2).waitForExistence(timeout: 8)) // Progress tab = history
    }

    /// "Use history only" works from the very first screen, with no handedness chosen and no camera involved.
    func testSkipFromTheFirstScreen() {
        let app = launch("sv")
        tap(app, "onboarding.skip")
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 8))
    }
}
