import XCTest

final class VoiceUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestStoreFile", storeFile,
            "-uiTestSeedHistory", "-uiTestSetupScene", "good", "-uiTestSetupCalibrated", "-uiTestNoOrientationLock", "-uiTestFakeVoice",
        ]
        if reset {
            args.append("-uiTestResetSettings")
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

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func tap(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "missing \(id)")
        button.tap()
    }

    func openSettings(_ app: XCUIApplication) {
        let b = app.buttons["nav.settings"].firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 10))
        b.tap()
        XCTAssertTrue(app.switches["settings.voice.enabled"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0) // let the sheet finish presenting before touching its rows
    }

    /// Taps the switch itself (the right end of the row): a tap in the middle of the row only hits its label.
    func toggle(_ element: XCUIElement) {
        XCUIApplication().reveal(element)
        XCTAssertTrue(element.waitForExistence(timeout: 8), "switch missing")
        let before = isOn(element)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        for _ in 0 ..< 30 where isOn(element) == before {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    func isOn(_ element: XCUIElement) -> Bool {
        if !element.isHittable {
            XCUIApplication().reveal(element)
        }
        return (element.value as? String) == "1"
    }

    /// Defaults are Carry + Ball speed; choices persist across a relaunch; muting disables the rest.
    func testVoicePreferencesPersistAndMuteDisablesTheMetrics() {
        let app = launch("en")
        openSettings(app)
        XCTAssertTrue(isOn(app.switches["settings.voice.enabled"]))
        XCTAssertTrue(isOn(app.switches["settings.voice.carry"]) && isOn(app.switches["settings.voice.ballSpeed"]))
        XCTAssertFalse(isOn(app.switches["settings.voice.verticalLaunch"]))
        shot("voice-en-settings")
        toggle(app.switches["settings.voice.ballSpeed"])
        toggle(app.switches["settings.voice.verticalLaunch"])
        XCTAssertFalse(isOn(app.switches["settings.voice.ballSpeed"]))
        XCTAssertTrue(isOn(app.switches["settings.voice.verticalLaunch"]))
        app.terminate()
        let again = launch("en", reset: false)
        openSettings(again)
        XCTAssertFalse(isOn(again.switches["settings.voice.ballSpeed"]), "choice persisted")
        XCTAssertTrue(isOn(again.switches["settings.voice.verticalLaunch"]))
        toggle(again.switches["settings.voice.enabled"])
        again.reveal(again.buttons["settings.voice.preview"])
        XCTAssertFalse(again.switches["settings.voice.carry"].isEnabled, "metrics are disabled while voice is off")
        XCTAssertFalse(again.buttons["settings.voice.preview"].isEnabled)
    }

    /// A shot's words always appear on screen: the selected metrics in the fixed order, in the app language.
    func runSpokenCaption(_ lang: String, expect: [String], absent: String) {
        let app = launch(lang)
        openSettings(app)
        if lang == "en" {
            toggle(app.switches["settings.voice.ballSpeed"])
        } // leave only Carry selected
        tap(app, "settings.done")
        XCUIDevice.shared.orientation = .landscapeLeft
        tap(app, "home.start")
        XCTAssertTrue(any(app, "practice.capture").waitForExistence(timeout: 8))
        tap(app, "practice.setup")
        tap(app, "setup.handedness.right")
        tap(app, "setup.close")
        tap(app, "practice.arm")
        tap(app, "practice.demoShot")
        let caption = any(app, "practice.spoken")
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        for part in expect {
            XCTAssertTrue(caption.label.contains(part), "\(caption.label) should contain \(part)")
        }
        XCTAssertFalse(caption.label.contains(absent), caption.label)
        shot("voice-\(lang)-caption")
    }

    func testCaptionEnglishShowsOnlySelectedMetricsWithEstimateQualifier() {
        runSpokenCaption("en", expect: ["Estimated carry:", "metres"], absent: "Ball speed")
    }

    func testCaptionSwedishUsesSwedishWords() {
        runSpokenCaption("sv", expect: ["Beräknad flyglängd:", "meter", "Bollhastighet:", "kilometer i timmen"], absent: "Carry")
    }
}
