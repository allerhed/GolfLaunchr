import XCTest

/// F25 / F22 layout checks: no raw keys on screen, and nothing runs off the screen at the largest accessibility text size with every
/// localised string doubled in length (`-NSDoubleLocalizedStrings`, a pseudo-localisation).
final class LocalizationUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    func launch(_ lang: String, big: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestFakeVoice", "-uiTestSetupScene", "good",
            "-uiTestNoOrientationLock",
        ]
        if big {
            args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-NSDoubleLocalizedStrings", "YES"]
        }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    let rawKey = try? NSRegularExpression(pattern: "^[a-z][A-Za-z]*(\\.[A-Za-z0-9]+)+$")

    func rawKeys(_ app: XCUIApplication) -> [String] {
        var labels: [String] = []
        for element in app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex {
            labels.append(element.label) // a loop: SwiftFormat would turn a closure into a key path, which the compiler rejects here
        }
        return labels.filter { text in
            rawKey?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }

    /// Elements that stick out past the screen's left or right edge (horizontal scrollers excluded).
    func overflowing(_ app: XCUIApplication) -> [String] {
        let screen = app.windows.firstMatch.frame
        let all = app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex + app.switches.allElementsBoundByIndex
        return all.compactMap { element -> String? in
            guard element.exists, !element.identifier.hasPrefix("analysis.chip") else { return nil }
            let f = element.frame
            guard f.width > 0, f.height > 0, f.minY > screen.minY, f.maxY < screen.maxY else { return nil }
            return (f.minX < screen.minX - 2 || f.maxX > screen.maxX + 2) ?
                "\(element.identifier) '\(element.label)' \(Int(f.minX))-\(Int(f.maxX))" : nil
        }
    }

    func visit(_ name: String, _ app: XCUIApplication, big: Bool) {
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(rawKeys(app), [], "\(name): raw localisation keys on screen")
        if big {
            XCTAssertEqual(overflowing(app), [], "\(name): elements off the screen at the largest text size")
        }
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("l10n-\(name).png"))
        }
    }

    /// Chooses an option of a segmented picker, or of the menu it becomes at accessibility text sizes.
    func select(_ app: XCUIApplication, picker id: String, index: Int, titlePrefix: String) {
        let segment = app.segmentedControls[id].buttons.element(boundBy: index)
        if segment.waitForExistence(timeout: 3) {
            segment.tap()
        } else {
            let menu = app.buttons[id].firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 5), "picker \(id)")
            menu.tap()
            let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", titlePrefix)).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5), "option \(titlePrefix)")
            option.tap()
        }
    }

    func walk(_ lang: String, big: Bool) {
        let tag = "\(lang)-\(big ? "xxxl" : "normal")"
        let app = launch(lang, big: big)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        visit("\(tag)-home", app, big: big)
        app.tabBars.buttons.element(boundBy: 1).tap()
        visit("\(tag)-bag", app, big: big)
        app.tabBars.buttons.element(boundBy: 2).tap()
        visit("\(tag)-progress", app, big: big)
        let analysisTitles = lang == "sv" ? ["Analys", "Genomsnitt", "Längdskillnader", "Spridning"] : [
            "Analysis",
            "Averages",
            "Gapping",
            "Dispersion"
        ]
        select(app, picker: "progress.section", index: 1, titlePrefix: analysisTitles[0])
        for (index, name) in ["averages", "gapping", "dispersion"].enumerated() {
            select(app, picker: "analysis.tab", index: index, titlePrefix: analysisTitles[index + 1])
            visit("\(tag)-analysis-\(name)", app, big: big)
        }
        app.tabBars.buttons.element(boundBy: 0).tap()
        let gear = app.buttons["nav.settings"].firstMatch
        if gear.waitForExistence(timeout: 5) {
            gear.tap()
            _ = app.buttons["settings.done"].waitForExistence(timeout: 5)
            visit("\(tag)-settings", app, big: big)
            app.buttons["settings.done"].tap()
        }
        let setup = app.buttons["home.setup"]
        if setup.waitForExistence(timeout: 5) {
            app.reveal(setup)
            setup.tap()
            _ = app.buttons["setup.ready"].waitForExistence(timeout: 8)
            visit("\(tag)-setup", app, big: big)
        }
    }

    func testNoRawKeysEnglish() {
        walk("en", big: false)
    }

    func testNoRawKeysSwedish() {
        walk("sv", big: false)
    }

    func testLargestTextAndDoubledStringsEnglish() {
        walk("en", big: true)
    }

    func testLargestTextAndDoubledStringsSwedish() {
        walk("sv", big: true)
    }

    func testOnboardingAtTheLargestTextSize() {
        for lang in ["en", "sv"] {
            let app = launch(lang, big: true, extra: ["-uiTestShowOnboarding", "-uiTestFakeCamera", "authorized"])
            XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 12))
            visit("\(lang)-onboarding-1", app, big: true)
            XCTAssertTrue(app.buttons["onboarding.next"].isHittable, "Continue stays reachable")
            app.buttons["onboarding.next"].tap()
            app.buttons["onboarding.next"].tap()
            visit("\(lang)-onboarding-handedness", app, big: true)
            app.terminate()
        }
    }
}
