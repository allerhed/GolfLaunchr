import XCTest

/// F11 on screen: set up the target drill, play it with demo shots (Debug only), read the live score and the summary, find the result
/// in history, and meet the Pro prompt once the introduction is used up.
final class DrillUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, spent: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestFakeVoice", "-uiTestSetupScene", "good",
            "-uiTestSetupCalibrated", "-uiTestNoOrientationLock",
        ]
        if let spent {
            args += ["-uiTestAllowanceSpent", "\(spent)"]
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func openSetup(_ app: XCUIApplication) {
        let tile = app.buttons["home.mode.target"]
        app.reveal(tile)
        XCTAssertTrue(tile.waitForExistence(timeout: 12))
        tile.tap()
        XCTAssertTrue(any(app, "drill.setup.target").waitForExistence(timeout: 8))
    }

    func testSetupShowsTheSpecDefaultsAndExplainsWhyThereIsNoSidewaysSetting() {
        let app = launch("en")
        openSetup(app)
        XCTAssertTrue(plain(any(app, "drill.setup.target").label).contains("100 m"), any(app, "drill.setup.target").label)
        XCTAssertTrue(plain(any(app, "drill.setup.tolerance").label).contains("5 m"), any(app, "drill.setup.tolerance").label)
        XCTAssertTrue(any(app, "drill.setup.attempts").label.contains("10"), any(app, "drill.setup.attempts").label)
        XCTAssertTrue(any(app, "drill.setup.lateral").label.contains("distance only"), any(app, "drill.setup.lateral").label)
        // Restricting to clubs needs at least one chosen.
        let allClubs = app.switches["drill.setup.allClubs"]
        app.reveal(allClubs)
        allClubs.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(any(app, "drill.setup.chooseClub").waitForExistence(timeout: 5), "nothing chosen: a hint, and no start")
        app.buttons["drill.setup.club.0"].tap()
        XCTAssertFalse(any(app, "drill.setup.chooseClub").exists)
        let start = app.buttons["drill.setup.start"]
        app.reveal(start)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isEnabled)
    }

    func testPlayingADrillShowsLiveScoreSummaryAndTheResultInHistory() {
        let app = launch("en")
        openSetup(app)
        app.buttons["drill.setup.target-Increment"].tap() // 105 m
        let attempts = app.buttons["drill.setup.attempts-Decrement"]
        for _ in 0 ..< 8 {
            attempts.tap() // 10 -> 2
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["drill.setup.start"].tap()
        XCTAssertTrue(any(app, "practice.capture").waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["practice.setup"].waitForExistence(timeout: 8))
        app.buttons["practice.setup"].tap()
        app.buttons["setup.handedness.right"].tap()
        app.buttons["setup.close"].tap()
        let panel = any(app, "practice.drill")
        XCTAssertTrue(panel.waitForExistence(timeout: 8))
        XCTAssertTrue(plain(panel.label).contains("Target 105 m"), panel.label)
        XCTAssertTrue(panel.label.contains("Distance only"))
        // Demo shot 1 carries 107 m: inside 105 +- 5. Demo shot 2 carries 114 m: long by 9 m.
        app.buttons["practice.arm"].tap()
        app.buttons["practice.demoShot"].tap()
        // The Label gives its identifier to both its text and its icon: ask for the text.
        let last = app.staticTexts["drill.last"].firstMatch
        XCTAssertTrue(last.waitForExistence(timeout: 8))
        XCTAssertTrue(last.label.contains("Hit"), last.label)
        app.buttons["practice.arm"].tap()
        app.buttons["practice.demoShot"].tap()
        let complete = any(app, "drill.complete")
        XCTAssertTrue(complete.waitForExistence(timeout: 8), "all attempts scored")
        let numbers = any(app, "drill.summary.numbers")
        XCTAssertTrue(numbers.waitForExistence(timeout: 8), "the summary opens by itself")
        XCTAssertTrue(numbers.label.contains("Hits: 1 of 2"), numbers.label)
        XCTAssertTrue(numbers.label.contains("Hit rate: 50"), numbers.label)
        XCTAssertTrue(numbers.label.contains("Missed short: 0, missed long: 1"), numbers.label)
        XCTAssertTrue(plain(any(app, "drill.attempt.2").label).contains("Long by 9 m"), any(app, "drill.attempt.2").label)
        app.buttons["drill.summary.done"].tap()
        app.buttons["practice.end"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'End session' AND identifier != 'practice.end'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCUIDevice.shared.orientation = .portrait
        // History keeps the drill with the configuration it ran with.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let cell = app.cells.element(boundBy: 0)
        XCTAssertTrue(cell.waitForExistence(timeout: 8))
        cell.tap()
        let drill = any(app, "session.drill")
        XCTAssertTrue(drill.waitForExistence(timeout: 8))
    }

    func testSwedishSetup() {
        let app = launch("sv")
        openSetup(app)
        XCTAssertTrue(plain(any(app, "drill.setup.target").label).contains("Målets längd: 100 m"), any(app, "drill.setup.target").label)
        XCTAssertTrue(any(app, "drill.setup.lateral").label.contains("bara på längd"))
        XCTAssertTrue(app.buttons["drill.setup.start"].label.contains("Starta övningen"))
    }

    func testAfterTheIntroductionTheTargetDrillAsksForProFirst() {
        let app = launch("en", spent: 50)
        let tile = app.buttons["home.mode.target"]
        app.reveal(tile)
        XCTAssertTrue(app.descendants(matching: .any)["home.allowance"].firstMatch.waitForExistence(timeout: 12))
        tile.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.alerts.firstMatch.label.contains("Target drill is part of Pro"), app.alerts.firstMatch.label)
        XCTAssertFalse(any(app, "drill.setup.target").exists, "nothing starts without asking")
        app.alerts.firstMatch.buttons["Not now"].tap()
        XCTAssertFalse(any(app, "paywall.root").exists)
    }
}
