import XCTest

/// History runs on DEBUG-only demo data (`-uiTestSeedHistory`): 3 sessions, newest first:
/// practice (6 shots: 7 iron x4, PW x2; shot 4 has no carry), target drill (4 PW shots), practice (3 driver shots, 40 days ago).
final class HistoryUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-history-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, seed: Bool = true, resetSettings: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestStoreFile", storeFile]
        if resetSettings {
            args.append("-uiTestResetSettings")
        }
        if seed {
            args.append("-uiTestSeedHistory")
        }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    func openProgress(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    func list(_ app: XCUIApplication) -> XCUIElement {
        app.collectionViews["history.list"]
    }

    /// The row's spoken text lives on the cell's button child (the cell itself has no label).
    func label(_ app: XCUIApplication, _ index: Int) -> String {
        app.cells.element(boundBy: index).buttons.firstMatch.label
    }

    func openFirstSession(_ app: XCUIApplication) {
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        let first = app.cells.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.staticTexts["session.summary.included"].waitForExistence(timeout: 5))
    }

    /// The summary updates a moment after a change is written; wait for the value instead of reading it once.
    func waitForSummary(_ app: XCUIApplication, _ expected: String, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts["session.summary.included"].exists, summary(app) == expected {
                return true
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    func summary(_ app: XCUIApplication) -> String {
        app.staticTexts["session.summary.included"].label
    }

    func meanCarry(_ app: XCUIApplication) -> String {
        app.otherElements["session.mean.carry"].exists ? app
            .otherElements["session.mean.carry"].label : app.staticTexts["session.mean.carry"].label
    }

    /// Opens the long-press menu of a shot and taps one of its actions (Exclude, Restore or Delete).
    func shotAction(_ app: XCUIApplication, _ title: String, onShot n: Int) {
        let row = shotRow(app, n)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "shot \(n) is on screen")
        row.press(forDuration: 1.2)
        let item = app.buttons[title].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the \(title) action is in the shot menu")
        item.tap()
    }

    func shotRow(_ app: XCUIApplication, _ n: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shot \(n)")).firstMatch
    }

    func testListShowsTheDemoSessionsNewestFirstAndLabelsThemAsDemo() {
        let app = launch("en")
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        XCTAssertEqual(app.cells.count, 3)
        let first = label(app, 0)
        XCTAssertTrue(first.contains("Practice") && first.contains("6 shots") && first.contains("7 iron") && first.contains("PW"), first)
        XCTAssertTrue(first.contains("Demo data"), "demo data is always labelled: \(first)")
        XCTAssertTrue(label(app, 1).contains("Target drill"))
        XCTAssertTrue(label(app, 2).contains("3 shots") && label(app, 2).contains("Driver"))
    }

    func testWithoutDemoDataTheHistoryIsEmptyAndHonest() {
        let app = launch("en", seed: false)
        openProgress(app)
        XCTAssertTrue(app.staticTexts["No sessions yet. Your practice sessions will appear here."].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Demo data"].exists)
        XCTAssertEqual(app.cells.count, 0)
    }

    func testFiltersNarrowTheListAndCanBeCleared() {
        let app = launch("en")
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        app.buttons["history.filter.range"].tap()
        app.buttons["Last 7 days"].tap()
        XCTAssertEqual(app.cells.count, 2, "the 40-day-old session drops out")
        app.buttons["history.filter.mode"].tap()
        app.buttons["Target drill"].tap()
        XCTAssertEqual(app.cells.count, 1)
        app.buttons["history.filter.club"].tap()
        app.buttons["Driver"].tap() // nobody used the driver in the last 7 days in a target drill
        XCTAssertTrue(app.staticTexts["No sessions match these filters."].waitForExistence(timeout: 5))
        app.buttons["Clear filters"].tap()
        XCTAssertTrue(list(app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.cells.count, 3)
    }

    /// F10: exclusion and restoration recompute the summary; the mean ignores the shot without a carry value.
    func testExcludeAndRestoreRecomputeTheSummary() {
        let app = launch("en")
        openFirstSession(app)
        XCTAssertEqual(summary(app), "6 of 6 shots included")
        XCTAssertTrue(meanCarry(app).contains("117"), "mean of 128,131,134,94,96 (shot 4 has no carry): \(meanCarry(app))")
        shotAction(app, "Exclude", onShot: 3)
        XCTAssertEqual(summary(app), "5 of 6 shots included")
        XCTAssertTrue(meanCarry(app).contains("112"), "mean of 128,131,94,96 without shot 3: \(meanCarry(app))")
        XCTAssertTrue(shotRow(app, 3).label.contains("Excluded"))
        shotAction(app, "Restore", onShot: 3)
        XCTAssertEqual(summary(app), "6 of 6 shots included")
        XCTAssertTrue(meanCarry(app).contains("117"))
    }

    /// Opens the third demo session (the driver, 3 shots): every row is visible without scrolling.
    func openThirdSession(_ app: XCUIApplication) {
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        app.cells.element(boundBy: 2).tap()
        XCTAssertTrue(waitForSummary(app, "3 of 3 shots included"))
    }

    /// Opens shot 3's menu and taps Delete; the confirmation then appears.
    func startDeletingShot3(_ app: XCUIApplication) {
        shotAction(app, "Delete", onShot: 3)
        XCTAssertTrue(app.staticTexts["Delete this shot permanently?"].waitForExistence(timeout: 5), "the confirmation appeared")
    }

    func testDeletingAShotNeedsConfirmationAndCancelChangesNothing() {
        // Extra-small text keeps every row on screen: the last row of a long list sits under the floating tab bar.
        let app = launch("en", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryExtraSmall"])
        openThirdSession(app)
        startDeletingShot3(app)
        // The confirmation is a native popover: cancelling means tapping outside it (some presentations also add a Cancel button).
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 1) {
            cancel.tap()
        } else {
            app.otherElements["PopoverDismissRegion"].tap()
        }
        XCTAssertTrue(app.staticTexts["Delete this shot permanently?"].waitForNonExistence(timeout: 5), "the confirmation closed")
        XCTAssertEqual(summary(app), "3 of 3 shots included", "cancelling changed nothing")
        startDeletingShot3(app)
        let confirm = app.popovers.buttons["Delete"]
        (confirm.exists ? confirm : app.buttons["Delete"].firstMatch).tap()
        XCTAssertTrue(waitForSummary(app, "2 of 2 shots included"), "after deleting: \(summary(app))")
    }

    func testDeletingASessionNeedsConfirmationAndLeavesTheOthers() {
        let app = launch("en")
        openFirstSession(app)
        app.buttons["session.delete"].tap()
        XCTAssertTrue(app.staticTexts["Delete this session permanently?"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertTrue(list(app).waitForExistence(timeout: 8), "back on the list")
        XCTAssertEqual(app.cells.count, 2)
        XCTAssertFalse(label(app, 0).contains("6 shots"))
    }

    /// Persistence in the real app: an exclusion survives closing and reopening, and the demo data is not added twice.
    func testExclusionSurvivesRelaunchWithoutReseeding() {
        var app = launch("en")
        openFirstSession(app)
        shotAction(app, "Exclude", onShot: 2)
        XCTAssertEqual(summary(app), "5 of 6 shots included")
        app.terminate()
        app = launch("en", resetSettings: false)
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        XCTAssertEqual(app.cells.count, 3, "no duplicate demo sessions")
        XCTAssertTrue(label(app, 0).contains("1 excluded"), label(app, 0))
    }

    func testSwedishLabelsAndLocalTimeFormat() {
        let app = launch("sv")
        openProgress(app)
        XCTAssertTrue(list(app).waitForExistence(timeout: 8))
        let first = label(app, 0)
        XCTAssertTrue(first.contains("Träning") && first.contains("6 slag") && first.contains("Demodata"), first)
        XCTAssertTrue(label(app, 1).contains("Målövning"))
        app.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["session.summary.included"].waitForExistence(timeout: 5))
        XCTAssertEqual(summary(app), "6 av 6 slag inkluderade")
        XCTAssertTrue(meanCarry(app).contains("117") && meanCarry(app).contains("Beräknad"), meanCarry(app))
    }

    /// An unavailable metric is shown as unavailable with its reason, never as a zero.
    func testShotDetailShowsProvenanceAndAnUnavailableValueHonestly() {
        let app = launch("en")
        openFirstSession(app)
        shotRow(app, 4).tap()
        XCTAssertTrue(app.staticTexts["Measurements"].waitForExistence(timeout: 5))
        let carry = app.otherElements["shotDetail.metric.carry"].exists ? app.otherElements["shotDetail.metric.carry"] : app
            .staticTexts["shotDetail.metric.carry"]
        XCTAssertTrue(carry.waitForExistence(timeout: 5))
        XCTAssertTrue(carry.label.contains("Unavailable") && carry.label.contains("Ball hidden"), carry.label)
        XCTAssertFalse(carry.label.contains("0 m"))
        let speed = app.otherElements["shotDetail.metric.ballSpeed"].exists ? app.otherElements["shotDetail.metric.ballSpeed"] : app
            .staticTexts["shotDetail.metric.ballSpeed"]
        XCTAssertTrue(speed.label.contains("Measured") && speed.label.contains("Valid"), speed.label)
        app.buttons["shotDetail.done"].tap()
    }

    /// Rotation rebuilds the shell; the open session must stay open.
    func testRotationKeepsTheOpenSession() {
        let app = launch("en")
        openFirstSession(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.progress"].waitForExistence(timeout: 8), "rail in landscape")
        XCTAssertTrue(app.staticTexts["session.summary.included"].waitForExistence(timeout: 8), "the session is still open")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.staticTexts["session.summary.included"].waitForExistence(timeout: 8))
    }
}
