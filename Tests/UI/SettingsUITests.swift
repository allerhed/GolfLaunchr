import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String = "en", reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestFakeVoice"]
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

    func openSettings(_ app: XCUIApplication) {
        let button = app.buttons["nav.settings"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0)
    }

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func pick(_ app: XCUIApplication, picker id: String, option: String) {
        let picker = app.buttons[id].firstMatch
        app.reveal(picker)
        picker.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "option \(option)")
        item.tap()
    }

    /// The language changes at once, in the open screen and on Home, and is remembered; System goes back to the device language.
    func testLanguageSwitchesLiveAndPersists() {
        let app = launch("en")
        openSettings(app)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
        pick(app, picker: "settings.language", option: "Svenska")
        shot("settings-sv-switched-from-en")
        XCTAssertTrue(app.staticTexts["Inställningar"].waitForExistence(timeout: 5), "the open Settings screen switched language")
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.staticTexts["Redo för rangen?"].waitForExistence(timeout: 5), "Home is Swedish without a relaunch")
        app.terminate()
        let again = launch("en", reset: false)
        XCTAssertTrue(again.staticTexts["Redo för rangen?"].waitForExistence(timeout: 10), "the choice survived a relaunch")
        openSettings(again)
        pick(again, picker: "settings.language", option: "System")
        again.buttons["settings.done"].tap()
        XCTAssertTrue(again.staticTexts["Ready for the range?"].waitForExistence(timeout: 5), "System follows the device (English here)")
    }

    func testSwingSideChoiceIsRememberedAndSettable() {
        let app = launch("en")
        openSettings(app)
        pick(app, picker: "settings.handedness", option: "Left-handed")
        app.buttons["settings.done"].tap()
        app.terminate()
        let again = launch("en", reset: false)
        openSettings(again)
        let picker = again.buttons["settings.handedness"].firstMatch
        again.reveal(picker)
        XCTAssertTrue(picker.label.contains("Left-handed") || (picker.value as? String)?.contains("Left-handed") == true, picker.label)
    }

    /// Manual atmosphere is range-checked, never silently replaced, and accepts the Swedish decimal comma.
    func testManualAtmosphereIsValidated() {
        let app = launch("sv")
        openSettings(app)
        let segmented = app.segmentedControls["settings.atmosphere"]
        app.reveal(segmented)
        segmented.buttons["Manuell"].tap()
        XCTAssertTrue(any(app, "settings.atmosphere.problem.missingPressure").waitForExistence(timeout: 5))
        XCTAssertTrue(any(app, "settings.atmosphere.problem.missingTemperature").exists)
        let pressure = app.textFields["settings.atmosphere.pressure"]
        app.reveal(pressure)
        pressure.tap()
        pressure.typeText("250")
        XCTAssertTrue(any(app, "settings.atmosphere.problem.pressureOutOfRange").waitForExistence(timeout: 5))
        XCTAssertFalse(any(app, "settings.atmosphere.problem.missingPressure").exists)
        pressure.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue)
        pressure.typeText("1013,5") // Swedish decimal comma
        XCTAssertFalse(any(app, "settings.atmosphere.problem.pressureOutOfRange").exists)
        let temperature = app.textFields["settings.atmosphere.temperature"]
        app.reveal(temperature)
        temperature.tap()
        temperature.typeText("12,5")
        XCTAssertFalse(any(app, "settings.atmosphere.problem.missingTemperature").exists)
        XCTAssertFalse(any(app, "settings.atmosphere.stale").exists, "just entered: not stale")
        shot("settings-sv-atmosphere")
    }

    func testPrivacyStatementIsShown() {
        let app = launch("en")
        openSettings(app)
        let text = any(app, "settings.privacy.text")
        app.reveal(text)
        XCTAssertTrue(text.label.contains("stay on this iPhone"))
    }
}
