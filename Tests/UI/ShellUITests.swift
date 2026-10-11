import XCTest

final class ShellUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app
            .launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings"] +
            extra
        app.launch()
        return app
    }

    func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        // Portrait: tab bar button. Landscape: rail button. Both carry the nav.<tab> identifier.
        app.buttons["nav.\(name)"].firstMatch
    }

    func testPortraitTabBarNavigatesAllThreeTabsEnglish() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["home.title"].exists)
        app.tabBars.buttons["Bag"].tap()
        XCTAssertTrue(app.staticTexts["Your clubs will appear here."].waitForExistence(timeout: 3))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Your trends will appear here."].waitForExistence(timeout: 3))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["home.subtitle"].waitForExistence(timeout: 3))
    }

    func testPortraitSwedishLabels() {
        let app = launch("sv")
        XCTAssertTrue(app.tabBars.buttons["Hem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Framsteg"].exists)
        app.tabBars.buttons["Bag"].tap()
        XCTAssertTrue(app.staticTexts["Dina klubbor visas här."].waitForExistence(timeout: 3))
    }

    func testLandscapeShowsRailNotTabBarAndRotationKeepsSelection() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Your trends will appear here."].waitForExistence(timeout: 3))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.home"].waitForExistence(timeout: 5), "rail should appear in landscape")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "no bottom tab bar in landscape")
        XCTAssertTrue(app.staticTexts["Your trends will appear here."].exists, "rotation must keep the selected tab")
        XCTAssertTrue(app.buttons["nav.progress"].isSelected)

        app.buttons["nav.bag"].tap()
        XCTAssertTrue(app.staticTexts["Your clubs will appear here."].waitForExistence(timeout: 3))

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your clubs will appear here."].exists, "selection survives rotating back")
    }

    func testRailTargetsAreAtLeast44Points() {
        let app = launch("en")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.home"].waitForExistence(timeout: 5))
        for id in ["nav.home", "nav.bag", "nav.progress", "nav.settings"] {
            let frame = app.buttons[id].frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, id)
            XCTAssertGreaterThanOrEqual(frame.height, 44, id)
        }
    }

    func testUnitsChangeUpdatesExamplesEnglish() {
        let app = launch("en")
        app.buttons["nav.settings"].firstMatch.tap()
        let distance = app.staticTexts["settings.example.distance"]
        XCTAssertTrue(distance.waitForExistence(timeout: 5))
        XCTAssertEqual(distance.label, "100\u{00A0}m") // GB region default: metres
        app.buttons["settings.distance"].tap()
        app.buttons["Yards (yd)"].tap()
        XCTAssertEqual(app.staticTexts["settings.example.distance"].label, "109\u{00A0}yd")
        app.buttons["settings.speed"].tap()
        app.buttons["Miles per hour (mph)"].tap()
        XCTAssertEqual(app.staticTexts["settings.example.speed"].label, "67.1\u{00A0}mph")
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    func testSwedishDecimalCommaInExamples() {
        let app = launch("sv")
        app.buttons["nav.settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["settings.example.speed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["settings.example.speed"].label, "108,0\u{00A0}km/h") // 30 m/s, region default for sv_SE
        app.buttons["settings.speed"].tap()
        app.buttons["Miles i timmen (mph)"].tap()
        XCTAssertEqual(app.staticTexts["settings.example.speed"].label, "67,1\u{00A0}mph")
        XCTAssertEqual(app.staticTexts["settings.example.distance"].label, "100\u{00A0}m")
    }

    func testSettingsPersistAcrossRelaunch() {
        var app = launch("en")
        app.buttons["nav.settings"].firstMatch.tap()
        app.buttons["settings.distance"].tap()
        app.buttons["Yards (yd)"].tap()
        app.terminate()
        let again = XCUIApplication()
        again.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB"] // no reset
        again.launch()
        again.buttons["nav.settings"].firstMatch.tap()
        XCTAssertEqual(again.staticTexts["settings.example.distance"].label, "109\u{00A0}yd")
        app = again
    }

    func testLargestAccessibilityTextKeepsPrimaryNavigationUsable() {
        let app = launch("en", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Bag"].isHittable)
        app.buttons["nav.settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.done"].isHittable)
        app.buttons["settings.done"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.bag"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.bag"].isHittable)
        app.buttons["nav.bag"].tap()
        XCTAssertTrue(app.staticTexts["Your clubs will appear here."].waitForExistence(timeout: 3))
    }
}

/// Visual review aid, not an assertion test: writes PNGs when TEST_RUNNER_SCREENSHOT_DIR is set. Skipped in normal runs.
final class ShellScreenshotTests: XCTestCase {
    func shot(_ name: String) throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { throw XCTSkip("no SCREENSHOT_DIR") }
        Thread.sleep(forTimeInterval: 0.8)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    func run(_ lang: String, style: String, orientation: UIDeviceOrientation) throws {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings"]
        app.launch()
        let o = orientation.isLandscape ? "land" : "port"
        if orientation.isLandscape {
            _ = app.buttons["nav.home"].waitForExistence(timeout: 5)
        } else {
            _ = app.tabBars.firstMatch.waitForExistence(timeout: 5)
        }
        if style == "dark" {
            try openSettingsAndPick(app, "Dark", "Mörkt", lang)
        }
        try shot("\(lang)-\(style)-\(o)-home")
        if orientation.isLandscape {
            app.buttons["nav.bag"].tap()
        } else {
            app.tabBars.buttons.element(boundBy: 1).tap()
        }
        try shot("\(lang)-\(style)-\(o)-bag")
        app.buttons["nav.settings"].firstMatch.tap()
        _ = app.buttons["settings.done"].waitForExistence(timeout: 5)
        try shot("\(lang)-\(style)-\(o)-settings")
        XCUIDevice.shared.orientation = .portrait
    }

    func openSettingsAndPick(_ app: XCUIApplication, _ en: String, _ sv: String, _ lang: String) throws {
        app.buttons["nav.settings"].firstMatch.tap()
        _ = app.buttons["settings.done"].waitForExistence(timeout: 5)
        app.buttons[lang == "sv" ? sv : en].firstMatch.tap()
        app.buttons["settings.done"].tap()
    }

    func testEnLightPortrait() throws {
        try run("en", style: "light", orientation: .portrait)
    }

    func testSvDarkPortrait() throws {
        try run("sv", style: "dark", orientation: .portrait)
    }

    func testEnLightLandscape() throws {
        try run("en", style: "light", orientation: .landscapeLeft)
    }

    func testSvDarkLandscape() throws {
        try run("sv", style: "dark", orientation: .landscapeLeft)
    }
}
