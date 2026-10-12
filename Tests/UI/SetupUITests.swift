import XCTest

final class SetupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, scene: String, calibrated: Bool = false, handedness: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestSetupScene", scene,
        ]
        if calibrated {
            args.append("-uiTestSetupCalibrated")
        }
        app.launchArguments = args
        app.launch()
        if handedness {
            // Onboarding is skipped by the reset flag, so choose the swing side in the setup screen itself.
        }
        return app
    }

    func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        Thread.sleep(forTimeInterval: 0.6)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func openSetup(_ app: XCUIApplication) {
        let button = app.buttons["home.setup"]
        if !button.waitForExistence(timeout: 8), app.buttons["nav.home"].exists {
            app.buttons["nav.home"].tap()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        button.tap()
        XCTAssertTrue(app.buttons["setup.ready"].waitForExistence(timeout: 8))
    }

    func has(_ app: XCUIApplication, _ id: String) -> Bool {
        app.descendants(matching: .any)[id].waitForExistence(timeout: 4)
    }

    /// Good scene, calibrated, side chosen: every check is Good and Ready is enabled.
    func testGoodSceneIsReady() {
        let app = launch("en", scene: "good", calibrated: true)
        openSetup(app)
        app.buttons["setup.handedness.right"].tap()
        XCTAssertTrue(has(app, "setup.check.stable.good") && has(app, "setup.check.light.good") && has(app, "setup.check.shutter.good"))
        XCTAssertTrue(has(app, "setup.check.flicker.good"))
        XCTAssertTrue(app.buttons["setup.ready"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["setup.blocker.deviceMoving"].exists)
        shot("setup-en-port-ready")
    }

    /// Each unsuitable scene blocks arming and names its reason and the action to take (en and sv).
    func testEachProblemBlocksWithReasonAndAction() {
        for (lang, scene, blocker, reasonText, actionText) in [
            ("en", "dark", "tooDark", "It is too dark.", "Add light or move to a brighter spot."),
            ("sv", "moving", "deviceMoving", "Bilden rör sig.", "Fäst telefonen på ett stabilt stativ"),
            ("en", "flicker", "flickerLikely", "The light flickers.", "steady light"),
            ("en", "none", "cameraNotRunning", "The camera is not delivering images yet.", "camera access"),
        ] {
            let app = launch(lang, scene: scene, calibrated: true)
            openSetup(app)
            app.buttons["setup.handedness.right"].tap()
            let item = app.descendants(matching: .any)["setup.blocker.\(blocker)"]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(scene): blocker missing")
            XCTAssertTrue(item.label.contains(reasonText), "\(scene): reason '\(item.label)'")
            XCTAssertTrue(item.label.contains(actionText), "\(scene): action '\(item.label)'")
            XCTAssertFalse(app.buttons["setup.ready"].isEnabled, "\(scene): must not arm")
            shot("setup-\(lang)-\(scene)")
            app.terminate()
        }
    }

    /// Test setup: arming allowed without calibration, a visible banner, and it can be left again.
    func testTestSetupArmsWithoutCalibrationAndIsLabelled() {
        let app = launch("en", scene: "good")
        openSetup(app)
        app.buttons["setup.handedness.left"].tap()
        XCTAssertTrue(has(app, "setup.blocker.notCalibrated"))
        XCTAssertFalse(app.buttons["setup.ready"].isEnabled)
        app.buttons["setup.test.toggle"].tap()
        XCTAssertTrue(has(app, "setup.testBanner"))
        XCTAssertTrue(app.buttons["setup.ready"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["setup.blocker.notCalibrated"].exists)
        shot("setup-en-port-test")
        app.buttons["setup.test.toggle"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["setup.testBanner"].exists)
        XCTAssertFalse(app.buttons["setup.ready"].isEnabled)
    }

    /// Switching swing side while calibrated asks first; Cancel keeps everything, Change forces recalibration. The diagram mirrors.
    func testChangingSideWhileCalibratedNeedsConfirmation() {
        let app = launch("en", scene: "good", calibrated: true)
        openSetup(app)
        app.buttons["setup.handedness.right"].tap()
        let diagram = app.descendants(matching: .any)["setup.diagram"]
        let rightLabel = diagram.label
        XCTAssertTrue(rightLabel.contains("golfer stands above"))
        app.buttons["setup.handedness.left"].tap()
        let change = app.buttons["Change and recalibrate"]
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        shot("setup-en-port-confirm")
        // The confirmation is a popover on this iOS: tapping outside is Cancel.
        app.otherElements["PopoverDismissRegion"].firstMatch.tap()
        XCTAssertFalse(change.waitForExistence(timeout: 1))
        XCTAssertEqual(diagram.label, rightLabel) // nothing changed
        XCTAssertTrue(app.buttons["setup.ready"].isEnabled)
        app.buttons["setup.handedness.left"].tap()
        app.buttons["Change and recalibrate"].tap()
        XCTAssertTrue(has(app, "setup.blocker.calibrationLost"))
        XCTAssertFalse(app.buttons["setup.ready"].isEnabled)
        XCTAssertTrue(diagram.label.contains("golfer stands below"), "diagram mirrored for the left-handed setup")
        shot("setup-en-port-lost")
    }

    /// Swedish landscape renders and stays usable.
    func testSwedishLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("sv", scene: "good", calibrated: true)
        openSetup(app)
        app.buttons["setup.handedness.left"].tap()
        XCTAssertTrue(has(app, "setup.check.stable.good"))
        shot("setup-sv-land-ready")
        XCTAssertTrue(app.buttons["setup.ready"].isEnabled)
    }
}
