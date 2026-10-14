import XCTest

/// F19 on screen: what is left for free is shown before practising, and with nothing left the capture screen cannot arm.
final class AllowanceUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, spent: Int?, failing: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestFakeVoice", "-uiTestSetupScene", "good", "-uiTestSetupCalibrated",
            "-uiTestNoOrientationLock",
        ]
        if let spent {
            args += ["-uiTestAllowanceSpent", "\(spent)"]
        }
        if failing {
            args.append("-uiTestAllowanceFail")
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    func plain(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func testFreshInstallShowsFiftyFreeShotsEnglish() {
        let app = launch("en", spent: nil)
        let row = app.descendants(matching: .any)["home.allowance"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        XCTAssertTrue(plain(row.label).contains("50 free shots left"), row.label)
    }

    func testMonthlyAllowanceAndNextResetAfterExhaustionSwedish() {
        // 50 spent today: nothing left, and the next free shots arrive next month.
        let app = launch("sv", spent: 50)
        let row = app.descendants(matching: .any)["home.allowance"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        XCTAssertTrue(plain(row.label).contains("Inga gratis slag kvar"), row.label)
        XCTAssertTrue(plain(row.label).contains("Nästa gratis slag:"), row.label)
    }

    func testIntroCountDropsWithSpentCredits() {
        let app = launch("en", spent: 49)
        let row = app.descendants(matching: .any)["home.allowance"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12))
        XCTAssertTrue(plain(row.label).contains("1 free shot left"), row.label) // singular
    }

    func testExhaustedCannotArmOnTheCaptureScreen() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("en", spent: 50)
        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        for _ in 0 ..< 3 where start.frame.minY < 60 {
            app.swipeDown()
        }
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["practice.capture"].waitForExistence(timeout: 10))
        let note = app.descendants(matching: .any)["practice.noAllowance"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["practice.arm"].isEnabled, "no allowance left: arming is disabled")
    }

    func testWithAllowanceTheArmButtonStillWorks() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("en", spent: 10)
        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        for _ in 0 ..< 3 where start.frame.minY < 60 {
            app.swipeDown()
        }
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["practice.capture"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["practice.noAllowance"].exists)
    }

    /// QA 6.7: an unreadable balance must not leave a silently dead Arm button.
    func testUnreadableBalanceSaysSoAndOffersARetry() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("en", spent: nil, failing: true)
        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        for _ in 0 ..< 3 where start.frame.minY < 60 {
            app.swipeDown()
        }
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["practice.capture"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["practice.allowanceUnavailable"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["practice.allowance.retry"].exists)
        XCTAssertFalse(app.buttons["practice.arm"].isEnabled)
    }
}
