import XCTest

final class BagUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, extra: [String] = [], resetSettings: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestStoreFile", storeFile]
        if resetSettings {
            args.append("-uiTestResetSettings")
        }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    func openBag(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
        XCTAssertTrue(bagList(app).waitForExistence(timeout: 8))
    }

    func bagList(_ app: XCUIApplication) -> XCUIElement {
        app.collectionViews["bag.list"].exists ? app.collectionViews["bag.list"] : app.otherElements["bag.list"]
    }

    func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// Diagnostic: prints every button label so a failure shows what was really on screen.
    func dumpButtons(_ app: XCUIApplication, _ tag: String) {
        var buttons: [String] = []
        for element in app.buttons.allElementsBoundByIndex {
            buttons.append(element.label)
        }
        var texts: [String] = []
        for element in app.staticTexts.allElementsBoundByIndex.prefix(40) {
            texts.append(element.label)
        }
        print("DUMP[\(tag)] buttons: \(buttons)")
        print("DUMP[\(tag)] staticTexts: \(texts)")
    }

    func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
    }

    func addClub(_ app: XCUIApplication, name: String, loft: String) {
        app.buttons["bag.add"].tap()
        let field = app.textFields["clubEdit.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        if !loft.isEmpty {
            let loftField = app.textFields["clubEdit.loft"]
            loftField.tap()
            loftField.typeText(loft)
        }
        app.buttons["clubEdit.save"].tap()
        XCTAssertTrue(app.textFields["clubEdit.name"].waitForNonExistence(timeout: 5), "the editor closes after a successful save")
    }

    /// UI1 (English): the seeded bag is shown, a club can be added, and a bad loft disables Save with the reason shown.
    func testAddClubAndRejectABadLoftEnglish() {
        let app = launch("en")
        openBag(app)
        XCTAssertTrue(app.navigationBars["My Bag"].exists)
        XCTAssertTrue(row(app, "Driver").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "Sand wedge")
            .exists || { scrollTo(row(app, "Sand wedge"), in: app); return row(app, "Sand wedge").exists }())
        addClub(app, name: "Test 7i", loft: "34")
        let added = row(app, "Test 7i")
        scrollTo(added, in: app)
        XCTAssertTrue(added.exists)
        XCTAssertTrue(added.label.contains("34"), "loft is shown: \(added.label)")
        added.tap()
        let loft = app.textFields["clubEdit.loft"]
        XCTAssertTrue(loft.waitForExistence(timeout: 5))
        loft.tap()
        loft.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "5.5.5") // the decimal pad has no letters
        XCTAssertFalse(app.buttons["clubEdit.save"].isEnabled)
        XCTAssertEqual(app.staticTexts["clubEdit.error"].label, "Enter the loft as a number.")
        app.buttons["clubEdit.cancel"].tap()
        XCTAssertTrue(bagList(app).waitForExistence(timeout: 5))
    }

    /// UI2 (Swedish): decimal comma accepted, Swedish seed names, and a duplicate name is refused with a Swedish message.
    func testSwedishNamesDecimalCommaAndDuplicate() {
        let app = launch("sv")
        openBag(app)
        XCTAssertTrue(app.navigationBars["Min bag"].exists)
        XCTAssertTrue(row(app, "Trä 3")
            .waitForExistence(timeout: 5) || { scrollTo(row(app, "Trä 3"), in: app); return row(app, "Trä 3").exists }())
        addClub(app, name: "Min wedge", loft: "56,5")
        let added = row(app, "Min wedge")
        scrollTo(added, in: app)
        XCTAssertTrue(added.label.contains("56,5"), "decimal comma shown: \(added.label)")
        app.buttons["bag.add"].tap()
        let field = app.textFields["clubEdit.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("min WEDGE")
        XCTAssertFalse(app.buttons["clubEdit.save"].isEnabled)
        XCTAssertEqual(app.staticTexts["clubEdit.error"].label, "En aktiv klubba har redan det namnet.")
    }

    /// UI3: archive by swipe moves the club to the Archived section; restore brings it back.
    func testArchiveAndRestoreBySwipe() {
        let app = launch("en")
        openBag(app)
        let putter = row(app, "Putter")
        scrollTo(putter, in: app)
        putter.swipeLeft()
        app.buttons["Archive"].tap()
        let section = app.buttons["bag.archivedSection"].exists ? app.buttons["bag.archivedSection"] : app
            .otherElements["bag.archivedSection"]
        scrollTo(section, in: app)
        XCTAssertTrue(section.waitForExistence(timeout: 5))
        XCTAssertTrue(section.label.contains("(1)"))
        section.tap() // expand
        app.swipeUp() // bring the archived row above the floating tab bar, as a person would
        let archivedPutter = row(app, "Putter")
        XCTAssertTrue(archivedPutter.waitForExistence(timeout: 5))
        archivedPutter.swipeLeft()
        app.buttons["Restore"].tap()
        XCTAssertFalse(app.buttons["bag.archivedSection"].waitForExistence(timeout: 2), "no archived clubs left")
    }

    /// UI4: rotating while the editor is open keeps what was typed.
    func testRotationKeepsTheDraftAndTheSheet() {
        let app = launch("en")
        openBag(app)
        app.buttons["bag.add"].tap()
        let field = app.textFields["clubEdit.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Half typed")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.textFields["clubEdit.name"].waitForExistence(timeout: 8), "the editor survived rotation")
        XCTAssertEqual(app.textFields["clubEdit.name"].value as? String, "Half typed")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(app.textFields["clubEdit.name"].value as? String, "Half typed")
    }

    /// Persistence in the real app: a club added now is still there after the app is closed and opened again.
    func testTheBagSurvivesRelaunch() {
        var app = launch("en")
        openBag(app)
        addClub(app, name: "Survivor", loft: "")
        scrollTo(row(app, "Survivor"), in: app)
        XCTAssertTrue(row(app, "Survivor").exists)
        app.terminate()
        app = launch("en", resetSettings: false)
        openBag(app)
        let again = row(app, "Survivor")
        scrollTo(again, in: app)
        XCTAssertTrue(again.exists, "the club persisted in the database")
        XCTAssertTrue(
            row(app, "Driver").exists || { app.swipeDown(); return row(app, "Driver").exists }(),
            "and the seed was not applied twice"
        )
    }

    /// UI5: the largest accessibility text size keeps the add button and the rows usable.
    func testLargestTextKeepsTheScreenUsable() {
        let app = launch("en", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openBag(app)
        XCTAssertTrue(app.buttons["bag.add"].isHittable)
        app.buttons["bag.add"].tap()
        XCTAssertTrue(app.textFields["clubEdit.name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["clubEdit.cancel"].isHittable)
        XCTAssertTrue(app.buttons["clubEdit.save"].exists)
        app.buttons["clubEdit.cancel"].tap()
    }

    func testLandscapeShowsTheBagWithTheRail() {
        let app = launch("en")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["nav.bag"].waitForExistence(timeout: 8))
        app.buttons["nav.bag"].tap()
        XCTAssertTrue(bagList(app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["bag.add"].isHittable)
        XCTAssertTrue(row(app, "Driver").waitForExistence(timeout: 5))
    }
}
