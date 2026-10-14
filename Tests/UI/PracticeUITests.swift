import XCTest

final class PracticeUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, lockOrientation: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestSetupScene", "good", "-uiTestSetupCalibrated",
        ]
        if !lockOrientation {
            args.append("-uiTestNoOrientationLock")
        }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        Thread.sleep(forTimeInterval: 0.6)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// The confirmation's destructive button (the screen's own End button has the same text but an identifier).
    func confirmButton(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != 'practice.end'", title)).firstMatch
    }

    func tap(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "missing \(id)")
        button.tap()
    }

    /// Home shows the real modes as buttons and the others as labelled "coming soon" tiles.
    func testHomeOffersPracticeQuickShotAndLabelsTheRest() {
        let app = launch("en")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.quickshot"].exists)
        XCTAssertTrue(app.buttons["home.mode.target"].exists, "the target drill is available")
        for mode in ["ladder", "virtual"] {
            let tile = any(app, "home.mode.\(mode)")
            XCTAssertTrue(tile.exists)
            XCTAssertTrue(tile.label.contains("Coming soon"), "\(mode): \(tile.label)")
            XCTAssertFalse(app.buttons["home.mode.\(mode)"].exists, "unavailable modes are not buttons")
        }
        shot("home-en-port")
    }

    func testHomeSwedish() {
        let app = launch("sv")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.start"].label.contains("Starta träning"))
        XCTAssertTrue(any(app, "home.mode.ladder").label.contains("Kommer snart"))
        shot("home-sv-port")
    }

    /// Capture is landscape only: in portrait nothing is shown but a rotate prompt and End.
    func testPortraitShowsTheRotateGate() {
        let app = launch("en")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 10))
        let before = any(app, "home.latest").label // the seeded demo history
        tap(app, "home.start")
        XCTAssertTrue(any(app, "practice.rotateGate").waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["practice.arm"].exists)
        shot("practice-en-port-gate")
        tap(app, "practice.end")
        XCTAssertTrue(confirmButton(app, "End session").waitForExistence(timeout: 5)) // confirmation, in this OS a popover
        confirmButton(app, "End session").tap()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 8))
        XCTAssertEqual(any(app, "home.latest").label, before, "a session without shots is not saved")
    }

    /// The whole session: blocked until the swing side is chosen, arm, a club change applies to the next shot, two shots, pause,
    /// end; the session then shows on Home and in Progress.
    func testSessionFlowEnglishLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("en")
        tap(app, "home.start")
        XCTAssertTrue(any(app, "practice.capture").waitForExistence(timeout: 8))
        let blocked = any(app, "practice.blocked")
        XCTAssertTrue(blocked.waitForExistence(timeout: 5))
        XCTAssertTrue(blocked.label.contains("Swing side is not chosen"), blocked.label)
        XCTAssertFalse(app.buttons["practice.arm"].isEnabled)
        shot("practice-en-land-blocked")
        tap(app, "practice.setup")
        tap(app, "setup.handedness.right")
        tap(app, "setup.close")
        XCTAssertTrue(app.buttons["practice.arm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["practice.arm"].isEnabled)
        app.buttons["practice.arm"].tap()
        XCTAssertEqual(any(app, "practice.status").label, "Armed")
        // Club change while armed: noted, and it applies to the NEXT shot.
        app.buttons["practice.club"].tap()
        XCTAssertTrue(app.buttons["7 iron"].waitForExistence(timeout: 5))
        app.buttons["7 iron"].tap()
        XCTAssertTrue(any(app, "practice.club.nextShot").waitForExistence(timeout: 5))
        shot("practice-en-land-armed")
        tap(app, "practice.demoShot")
        XCTAssertTrue(any(app, "practice.shotCount").label.contains("1"))
        XCTAssertEqual(any(app, "practice.status").label, "Not armed")
        XCTAssertFalse(any(app, "practice.club.nextShot").exists)
        XCTAssertTrue(any(app, "practice.card.carry").label.contains("Estimated"), "carry stays labelled Estimated")
        tap(app, "practice.arm")
        tap(app, "practice.demoShot")
        XCTAssertTrue(any(app, "practice.shotCount").label.contains("2"))
        shot("practice-en-land-2shots")
        tap(app, "practice.pause")
        XCTAssertEqual(any(app, "practice.status").label, "Paused")
        XCTAssertFalse(app.buttons["practice.arm"].isEnabled, "no arming while paused")
        tap(app, "practice.pause")
        tap(app, "practice.end")
        XCTAssertTrue(confirmButton(app, "End session").waitForExistence(timeout: 5))
        confirmButton(app, "End session").tap()
        XCUIDevice.shared.orientation = .portrait
        let latest = any(app, "home.latest")
        XCTAssertTrue(latest.waitForExistence(timeout: 10))
        XCTAssertTrue(latest.label.contains("2 shots"), latest.label)
        shot("home-en-after-session")
    }

    func testSessionFlowSwedishLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("sv")
        tap(app, "home.quickshot")
        XCTAssertTrue(any(app, "practice.capture").waitForExistence(timeout: 8))
        shot("practice-sv-land")
        XCTAssertTrue(any(app, "practice.blocked").label.contains("Svingsida är inte vald"))
        tap(app, "practice.end")
        XCTAssertTrue(confirmButton(app, "Avsluta passet").waitForExistence(timeout: 5))
    }
}
