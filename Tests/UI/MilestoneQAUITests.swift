import XCTest

/// 4.9 milestone QA: every built screen in English and Swedish, portrait and landscape. Each screen is captured for comparison with
/// the mockups (SCREENSHOT_DIR) and checked automatically for raw localisation keys and text running past the screen edges.
final class MilestoneQAUITests: XCTestCase {
    var storeFile = ""
    var problems: [String] = []

    override func setUp() {
        continueAfterFailure = true
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
        problems = []
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestFakeVoice", "-uiTestSetupScene", "good",
            "-uiTestSetupCalibrated", "-uiTestNoOrientationLock", "-uiTestFakeCamera", "authorized",
        ] + extra
        app.launch()
        return app
    }

    /// Captures the screen, then looks for raw keys ("home.title") and texts that cross the screen edge.
    func check(_ tag: String, _ name: String, _ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.8)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(tag)-\(name).png"))
        }
        let screen = app.windows.firstMatch.frame
        let raw = try? NSRegularExpression(pattern: "^[a-z][a-zA-Z0-9]*(\\.[a-zA-Z0-9]+)+$")
        for text in app.staticTexts.allElementsBoundByIndex where text.exists {
            let label = text.label
            if label.isEmpty {
                continue
            }
            if raw?.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)) != nil {
                problems.append("\(tag) \(name): raw key '\(label)'")
            }
            let f = text.frame
            if f.width > 0, f.maxX > screen.maxX + 1 || f.minX < screen.minX - 1 {
                problems.append("\(tag) \(name): '\(label)' crosses the screen edge")
            }
        }
    }

    func go(_ app: XCUIApplication, _ tab: String, index: Int) {
        let rail = app.buttons["nav.\(tab)"].firstMatch
        if rail.exists, rail.isHittable {
            rail.tap()
        } else {
            app.tabBars.buttons.element(boundBy: index).tap()
        }
    }

    func walk(_ lang: String, landscape: Bool) {
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        let tag = "\(lang)-\(landscape ? "land" : "port")"
        let app = launch(lang)
        XCTAssertTrue(app.buttons["nav.settings"].firstMatch.waitForExistence(timeout: 15), "\(tag) no shell")
        check(tag, "01-home", app)
        go(app, "bag", index: 1)
        check(tag, "02-bag", app)
        go(app, "progress", index: 2)
        check(tag, "03-progress", app)
        let cell = app.cells.element(boundBy: 0)
        if cell.waitForExistence(timeout: 5) {
            cell.tap()
            _ = app.buttons["session.analyse"].waitForExistence(timeout: 8)
            check(tag, "04-session", app)
            let shotRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'session.shotRow.'")).firstMatch
            if shotRow.exists {
                shotRow.tap()
                check(tag, "05-shot", app)
                app.buttons["shotDetail.done"].tap()
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
        } else {
            problems.append("\(tag): no seeded session")
        }
        walkAnalysis(tag, app)
        walkSettingsSetupPractice(tag, landscape: landscape, app)
        XCTAssertEqual(problems, [], "\(tag) milestone QA findings")
    }

    func walkAnalysis(_ tag: String, _ app: XCUIApplication) {
        go(app, "progress", index: 2)
        let section = app.segmentedControls["progress.section"].buttons.element(boundBy: 1)
        if section.waitForExistence(timeout: 5) {
            section.tap()
            let names = ["06-averages", "07-gapping", "08-dispersion"]
            for (index, name) in names.enumerated() {
                app.segmentedControls["analysis.tab"].buttons.element(boundBy: index).tap()
                check(tag, name, app)
            }
            app.segmentedControls["analysis.tab"].buttons.element(boundBy: 0).tap()
            let card = app.buttons["analysis.card.0"].firstMatch
            if card.waitForExistence(timeout: 5) {
                card.tap()
                check(tag, "09-profile", app)
                app.navigationBars.buttons.element(boundBy: 0).tap()
            }
            let chip = app.buttons["analysis.chip.clubs"]
            if chip.waitForExistence(timeout: 3) {
                chip.tap()
                if app.buttons["filter.apply"].waitForExistence(timeout: 5) {
                    check(tag, "10-filter", app)
                    app.buttons["filter.cancel"].tap()
                }
            }
        } else {
            problems.append("\(tag): no analysis section")
        }
    }

    func walkSettingsSetupPractice(_ tag: String, landscape: Bool, _ app: XCUIApplication) {
        app.buttons["nav.settings"].firstMatch.tap()
        _ = app.buttons["settings.done"].waitForExistence(timeout: 6)
        check(tag, "11-settings", app)
        app.swipeUp()
        check(tag, "12-settings-more", app)
        app.buttons["settings.done"].tap()
        go(app, "home", index: 0)
        let setup = app.buttons["home.setup"]
        if setup.waitForExistence(timeout: 5) {
            setup.tap()
            _ = app.buttons["setup.ready"].waitForExistence(timeout: 8)
            check(tag, "13-setup", app)
            app.buttons["setup.close"].tap()
        }
        let start = app.buttons["home.start"]
        if start.waitForExistence(timeout: 5) {
            for _ in 0 ..< 3 where start.frame.minY < 60 {
                app.swipeDown()
            }
            start.tap()
            let reached = app.descendants(matching: .any)["practice.capture"].waitForExistence(timeout: 10)
            if landscape {
                XCTAssertTrue(reached, "\(tag) the capture screen did not open")
            }
            check(tag, "14-practice", app)
        }
    }

    func testEnglishPortrait() {
        walk("en", landscape: false)
    }

    func testEnglishLandscape() {
        walk("en", landscape: true)
    }

    func testSwedishPortrait() {
        walk("sv", landscape: false)
    }

    func testSwedishLandscape() {
        walk("sv", landscape: true)
    }

    func testOnboardingBothLanguagesAndOrientations() {
        for lang in ["en", "sv"] {
            for landscape in [false, true] {
                XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
                let tag = "\(lang)-\(landscape ? "land" : "port")"
                let app = launch(lang, extra: ["-uiTestShowOnboarding"])
                XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 15), "\(tag) onboarding")
                check(tag, "00-welcome", app)
                app.terminate()
            }
        }
        XCTAssertEqual(problems, [], "onboarding findings")
    }
}
