import XCTest

/// F21 on screen: export, delete everything (explained, export first, cancel keeps data), media only, diagnostic preview.
final class PrivacyUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    func launch(_ lang: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestFakeVoice",
        ]
        app.launch()
        return app
    }

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons["nav.settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 12))
        gear.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
    }

    func reveal(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let element = app.buttons[id]
        app.reveal(element)
        XCTAssertTrue(element.waitForExistence(timeout: 8), id)
        return element
    }

    func sessionCount(_ app: XCUIApplication) -> Int {
        app.tabBars.buttons.element(boundBy: 2).tap()
        Thread.sleep(forTimeInterval: 1)
        return app.cells.count
    }

    func testDeleteExplainsWhatGoesAndWhatStaysAndCancelKeepsEverything() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        XCTAssertGreaterThan(sessionCount(app), 0)
        app.tabBars.buttons.element(boundBy: 0).tap()
        openSettings(app)
        reveal(app, "settings.deleteAll").tap()
        let removes = any(app, "delete.removes")
        XCTAssertTrue(removes.waitForExistence(timeout: 8))
        XCTAssertTrue(removes.label.contains("cannot be undone"), removes.label)
        XCTAssertTrue(any(app, "delete.keeps").label.contains("App Store purchases"), any(app, "delete.keeps").label)
        XCTAssertTrue(any(app, "delete.keeps").label.contains("free allowance"))
        app.buttons["delete.cancel"].tap()
        app.buttons["settings.done"].tap()
        XCTAssertGreaterThan(sessionCount(app), 0, "cancel deletes nothing")
    }

    func testExportFirstThenDeleteEmptiesHistoryAndBagIsReseeded() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        app.tabBars.buttons.element(boundBy: 0).tap()
        openSettings(app)
        reveal(app, "settings.deleteAll").tap()
        let exportFirst = app.buttons["delete.exportFirst"]
        XCTAssertTrue(exportFirst.waitForExistence(timeout: 8))
        exportFirst.tap()
        XCTAssertTrue(any(app, "delete.share").waitForExistence(timeout: 10), "the export file is ready to share before deleting")
        app.buttons["delete.confirm"].tap()
        XCTAssertTrue(any(app, "settings.deleteAll.status").waitForExistence(timeout: 12))
        XCTAssertTrue(any(app, "settings.deleteAll.status").label.contains("Deleted"))
        app.buttons["settings.done"].tap()
        XCTAssertEqual(sessionCount(app), 0, "history is empty after deleting")
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.cells.allElementsBoundByIndex.isEmpty, "the default bag is back, as on a first launch")
    }

    func testExportRowsPrepareAFileToShare() {
        let app = launch("en")
        openSettings(app)
        reveal(app, "settings.export.json").tap()
        XCTAssertTrue(any(app, "settings.export.share").waitForExistence(timeout: 10))
    }

    func testDiagnosticPreviewShowsExactlyWhatWouldBeSharedWithoutPersonalContent() {
        let app = launch("en")
        openSettings(app)
        reveal(app, "settings.diagnostics").tap()
        let text = any(app, "diagnostics.text")
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertTrue(text.label.contains("Shots:") && text.label.contains("App:"), text.label)
        XCTAssertTrue(text.label.contains("No video, clips, shot values, club names or dates are included."))
        XCTAssertFalse(text.label.contains("7 iron") || text.label.contains("Driver"), "no club names")
        XCTAssertTrue(any(app, "diagnostics.share").exists)
    }

    func testMediaOnlyDeletionAsksFirstAndSaysWhatHappened() {
        let app = launch("en")
        openSettings(app)
        reveal(app, "settings.deleteMedia").tap()
        let confirm = app.buttons["settings.deleteMedia.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        confirm.tap()
        let status = any(app, "settings.deleteMedia.status")
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(status.label.contains("no media to delete"), status.label)
    }

    func testSwedishDeleteSheet() {
        let app = launch("sv")
        openSettings(app)
        reveal(app, "settings.deleteAll").tap()
        let removes = any(app, "delete.removes")
        XCTAssertTrue(removes.waitForExistence(timeout: 8))
        XCTAssertTrue(removes.label.contains("Det går inte att ångra"), removes.label)
        XCTAssertTrue(any(app, "delete.keeps").label.contains("Apple hanterar dem"))
        XCTAssertTrue(app.buttons["delete.confirm"].label.contains("Radera allt"))
    }

    /// QA 6.7: after deleting everything the app is usable at once: practice starts with the reseeded bag.
    func testPracticeStartsAfterDeletingEverything() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        openSettings(app)
        reveal(app, "settings.deleteAll").tap()
        XCTAssertTrue(app.buttons["delete.confirm"].waitForExistence(timeout: 8))
        app.buttons["delete.confirm"].tap()
        XCTAssertTrue(any(app, "settings.deleteAll.status").waitForExistence(timeout: 12))
        app.buttons["settings.done"].tap()
        let start = app.buttons["home.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(
            app.buttons["practice.end"].waitForExistence(timeout: 12) || any(app, "practice.capture").exists,
            "the practice screen opened"
        )
    }
}
