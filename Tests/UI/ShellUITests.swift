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
        XCTAssertTrue(app.otherElements["bag.list"].waitForExistence(timeout: 5) || app.collectionViews["bag.list"]
            .waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(
            app.segmentedControls["progress.section"].waitForExistence(timeout: 5),
            "the Progress tab shows its Sessions/Trends switch"
        )
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["home.subtitle"].waitForExistence(timeout: 3))
    }

    func testPortraitSwedishLabels() {
        let app = launch("sv")
        XCTAssertTrue(app.tabBars.buttons["Hem"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Framsteg"].exists)
        app.tabBars.buttons["Bag"].tap()
        XCTAssertTrue(app.navigationBars["Min bag"].waitForExistence(timeout: 5))
    }

    func testLandscapeShowsRailNotTabBarAndRotationKeepsSelection() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(
            app.segmentedControls["progress.section"].waitForExistence(timeout: 5),
            "the Progress tab shows its Sessions/Trends switch"
        )

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.home"].waitForExistence(timeout: 5), "rail should appear in landscape")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "no bottom tab bar in landscape")
        XCTAssertTrue(app.segmentedControls["progress.section"].exists, "rotation must keep the selected tab")
        XCTAssertTrue(app.buttons["nav.progress"].isSelected)

        app.buttons["nav.bag"].tap()
        XCTAssertTrue(app.otherElements["bag.list"].waitForExistence(timeout: 5) || app.collectionViews["bag.list"]
            .waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["bag.list"].exists || app.collectionViews["bag.list"].exists, "selection survives rotating back")
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
        XCTAssertTrue(app.otherElements["bag.list"].waitForExistence(timeout: 5) || app.collectionViews["bag.list"]
            .waitForExistence(timeout: 5))
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
            // Pick the theme in portrait, where the longer Settings form is easy to scroll; then go back to the wanted orientation.
            XCUIDevice.shared.orientation = .portrait
            _ = app.tabBars.firstMatch.waitForExistence(timeout: 8)
            try openSettingsAndPick(app, "Dark", "Mörkt", lang)
            XCUIDevice.shared.orientation = orientation
            if orientation.isLandscape {
                _ = app.buttons["nav.home"].waitForExistence(timeout: 8)
            }
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
        let option = app.buttons[lang == "sv" ? sv : en].firstMatch
        app.reveal(option)
        option.tap()
        app.buttons["settings.done"].tap()
    }

    /// Visual check of the app icon on the simulator home screen.
    func testHomeScreenIcon() throws {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        _ = springboard.icons["GolfLaunchr"].waitForExistence(timeout: 5)
        try shot("home-screen-icon")
    }

    func testBagScreens() throws {
        for (lang, dark, orientation) in [("en", false, UIDeviceOrientation.portrait), ("sv", true, .landscapeLeft)] {
            XCUIDevice.shared.orientation = orientation
            let app = XCUIApplication()
            let store = NSTemporaryDirectory() + "shot-\(UUID().uuidString)/store.sqlite"
            app.launchArguments = [
                "-AppleLanguages",
                "(\(lang))",
                "-AppleLocale",
                lang == "sv" ? "sv_SE" : "en_GB",
                "-uiTestResetSettings",
                "-uiTestStoreFile",
                store
            ]
            app.launch()
            let o = orientation.isLandscape ? "land" : "port"
            if orientation.isLandscape {
                app.buttons["nav.bag"].tap()
            } else {
                app.tabBars.buttons.element(boundBy: 1).tap()
            }
            _ = app.buttons["bag.add"].waitForExistence(timeout: 8)
            if dark {
                app.buttons["nav.settings"].firstMatch.tap()
                let dark = app.buttons[lang == "sv" ? "Mörkt" : "Dark"].firstMatch
                app.reveal(dark)
                dark.tap()
                app.buttons["settings.done"].tap()
            }
            try shot("bag-\(lang)-\(o)-list")
            app.buttons["bag.add"].tap()
            let name = app.textFields["clubEdit.name"]
            _ = name.waitForExistence(timeout: 5)
            name.tap()
            name.typeText(lang == "sv" ? "Min wedge" : "Test wedge")
            app.textFields["clubEdit.loft"].tap()
            app.textFields["clubEdit.loft"].typeText(lang == "sv" ? "56,5" : "56.5")
            try shot("bag-\(lang)-\(o)-editor")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testHistoryScreens() throws {
        for (lang, dark, orientation) in [("en", false, UIDeviceOrientation.portrait), ("sv", true, .landscapeLeft)] {
            XCUIDevice.shared.orientation = orientation
            let app = XCUIApplication()
            let store = NSTemporaryDirectory() + "shot-\(UUID().uuidString)/store.sqlite"
            app.launchArguments = [
                "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
                "-uiTestStoreFile", store, "-uiTestSeedHistory",
            ]
            app.launch()
            let o = orientation.isLandscape ? "land" : "port"
            if orientation.isLandscape {
                app.buttons["nav.progress"].tap()
            } else {
                app.tabBars.buttons.element(boundBy: 2).tap()
            }
            _ = app.collectionViews["history.list"].waitForExistence(timeout: 8)
            if dark {
                app.buttons["nav.settings"].firstMatch.tap()
                let dark = app.buttons[lang == "sv" ? "Mörkt" : "Dark"].firstMatch
                app.reveal(dark)
                dark.tap()
                app.buttons["settings.done"].tap()
            }
            try shot("history-\(lang)-\(o)-list")
            app.cells.element(boundBy: 0).tap()
            _ = app.staticTexts["session.summary.included"].waitForExistence(timeout: 5)
            try shot("history-\(lang)-\(o)-session")
            if !orientation.isLandscape {
                app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shot 4")).firstMatch.tap()
                _ = app.buttons["shotDetail.done"].waitForExistence(timeout: 5)
                try shot("history-\(lang)-\(o)-shot")
            }
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testHarnessScreens() throws {
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB", "-uiTestResetSettings"]
            app.launch()
            app.buttons["nav.settings"].firstMatch.tap()
            app.buttons["settings.openHarness"].tap()
            _ = app.staticTexts["harness.banner"].waitForExistence(timeout: 5)
            try shot("harness-\(orientation.isLandscape ? "land" : "port")")
            app.terminate()
        }
        XCUIDevice.shared.orientation = .portrait
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

/// Debug capture harness (G1). The simulator has no camera, so this covers layout, labelling and the no-camera state only.
/// Capture itself is NOT RUN here: it needs a physical iPhone.
final class HarnessUITests: XCTestCase {
    func open() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_GB", "-uiTestResetSettings"]
        app.launch()
        app.buttons["nav.settings"].firstMatch.tap()
        let entry = app.buttons["settings.openHarness"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Debug builds expose the harness entry")
        entry.tap()
        return app
    }

    func testHarnessIsLabelledAndHandlesNoCamera() {
        let app = open()
        XCTAssertTrue(app.staticTexts["harness.banner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["harness.banner"].label.contains("Not shipped"))
        XCTAssertTrue(app.navigationBars["DEBUG HARNESS"].exists)
        XCTAssertTrue(app.staticTexts["harness.phase"].label.contains("No camera"))
        // The garage session fields (block, recording kind, next block) are part of the harness form. Drag inside the harness form
        // itself (lower part of the screen): the Settings list behind the full-screen harness is still in the hierarchy.
        func scrollForm() {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        let nextBlock = app.buttons["harness.nextBlock"]
        for _ in 0 ..< 10 where !nextBlock.exists {
            scrollForm()
        } // lazy form: scroll the row into the hierarchy
        XCTAssertTrue(nextBlock.exists, "session fields for garage/bay recording")
        let start = app.buttons["harness.start"]
        for _ in 0 ..< 12 where !start.exists {
            scrollForm()
        }
        XCTAssertTrue(start.exists)
        XCTAssertFalse(start.isEnabled, "cannot start without a camera format")
        XCTAssertTrue(app.staticTexts["harness.previewState"].exists)
    }

    func testHarnessClosesBackToSettingsAndWorksInLandscape() {
        let app = open()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["harness.banner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["harness.close"].isHittable)
        app.buttons["harness.close"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
    }
}
