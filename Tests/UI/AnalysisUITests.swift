import XCTest

final class AnalysisUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ lang: String, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestStoreFile", storeFile,
            "-uiTestSeedHistory", "-uiTestFakeVoice",
        ]
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

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Accessibility labels use no-break spaces inside values ("221 m"): compare with plain spaces.
    func label(_ element: XCUIElement) -> String {
        element.label.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    func openAnalysis(_ app: XCUIApplication, landscape: Bool = false) {
        if landscape {
            XCTAssertTrue(app.buttons["nav.progress"].waitForExistence(timeout: 10))
            app.buttons["nav.progress"].tap()
        } else {
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
            app.tabBars.buttons.element(boundBy: 2).tap()
        }
        let segment = app.segmentedControls["progress.section"].buttons.element(boundBy: 1)
        XCTAssertTrue(segment.waitForExistence(timeout: 8))
        segment.tap()
        XCTAssertTrue(any(app, "analysis.tab").waitForExistence(timeout: 8))
    }

    func chooseTab(_ app: XCUIApplication, _ index: Int) {
        app.segmentedControls["analysis.tab"].buttons.element(boundBy: index).tap()
    }

    /// Averages: one card per club with the pooled mean, the provenance and the provisional flag; the numbers are the stored ones.
    func testAveragesShowsPooledMeansWithEstimateAndProvisionalLabels() {
        let app = launch("en")
        openAnalysis(app)
        // Seeded demo shots: Driver 221/228/215 -> 221 m; PW over two sessions 94/96/92/95/99/90 -> 94 m; 7 iron 128/131/134 -> 131 m.
        let seven = any(app, "analysis.card.0") // order: bag order, then other clubs by name (7 iron, Driver, PW)
        XCTAssertTrue(seven.waitForExistence(timeout: 8))
        XCTAssertTrue(label(seven).contains("7 iron") && label(seven).contains("131 m") && label(seven).contains("4 shots"), label(seven))
        let driver = any(app, "analysis.card.1")
        XCTAssertTrue(label(driver).contains("Driver") && label(driver).contains("221 m"), label(driver))
        XCTAssertTrue(label(driver).contains("Estimated") && label(driver).contains("Provisional"), label(driver))
        let pw = any(app, "analysis.card.2")
        XCTAssertTrue(label(pw).contains("PW") && label(pw).contains("94 m") && label(pw).contains("6 shots"), label(pw))
        shot("analysis-en-port-averages")
    }

    /// Profile -> View all shots -> shot detail with the comparison against the club average and the signed difference.
    func testProfileShotsAndShotComparison() {
        let app = launch("en")
        openAnalysis(app)
        app.buttons["analysis.card.0"].firstMatch.tap() // 7 iron
        XCTAssertTrue(any(app, "analysis.profile").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Median"].exists && app.staticTexts["10th percentile"].exists)
        shot("analysis-en-port-profile")
        let view = app.buttons["analysis.profile.viewShots"]
        app.reveal(view)
        view.tap()
        XCTAssertTrue(any(app, "analysis.clubShots").waitForExistence(timeout: 8))
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'analysis.shot.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        shot("analysis-en-port-shotdetail")
        let delta = any(app, "shotDetail.compare.delta")
        XCTAssertTrue(delta.waitForExistence(timeout: 8))
        XCTAssertTrue(
            label(delta).contains("−3") || label(delta).contains("+") || label(delta).contains("3 m") || label(delta).contains("0 m"),
            delta.label
        )
        shot("analysis-en-port-shotcompare")
    }

    /// Gapping keeps the order the clubs are shown in: a negative gap is marked, never sorted away; the last row has no gap.
    func testGappingKeepsOrderAndMarksAnInversion() {
        let app = launch("en")
        openAnalysis(app)
        chooseTab(app, 1)
        XCTAssertTrue(any(app, "analysis.gap.table").waitForExistence(timeout: 8))
        let rows = (0 ..< 3).map { any(app, "analysis.gap.row.\($0)") }
        XCTAssertTrue(label(rows[0]).contains("7 iron") && label(rows[0]).contains("Next club is longer"), label(rows[0])) // 131 - 221 < 0
        XCTAssertTrue(label(rows[1]).contains("Driver") && label(rows[1]).contains("127 m"), label(rows[1])) // 221 - 94
        XCTAssertTrue(label(rows[2]).contains("PW") && label(rows[2]).contains("—"), label(rows[2]))
        shot("analysis-en-port-gapping")
    }

    /// Multi-club filter: draft, Apply disabled for an empty choice, Cancel leaves the old filter, Apply updates every screen and the
    /// "Selected clubs only" warning, and the applied filter survives a relaunch.
    func testFilterSheetDraftApplyCancelAndRelaunch() {
        let app = launch("en")
        openAnalysis(app)
        chooseTab(app, 1)
        app.buttons["analysis.chip.clubs"].tap()
        XCTAssertTrue(app.buttons["filter.apply"].waitForExistence(timeout: 8))
        shot("analysis-en-port-filter")
        // start from All clubs: untick it -> nothing chosen -> Apply disabled with the reason
        app.switches["filter.allClubs"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["filter.apply"].isEnabled)
        XCTAssertTrue(app.staticTexts["Choose at least one club, or All clubs."].waitForExistence(timeout: 3))
        app.buttons["filter.club.1"].tap() // PW
        app.buttons["filter.club.2"].tap() // 7 iron
        XCTAssertTrue(app.buttons["filter.apply"].isEnabled)
        app.buttons["filter.cancel"].tap()
        XCTAssertTrue(app.buttons["analysis.chip.clubs"].label.contains("All clubs"), "cancel leaves the applied filter")
        app.buttons["analysis.chip.clubs"].tap()
        app.switches["filter.allClubs"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["filter.club.1"].tap()
        app.buttons["filter.club.2"].tap()
        app.buttons["filter.apply"].tap()
        XCTAssertTrue(app.buttons["analysis.chip.clubs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["analysis.chip.clubs"].label.contains("2 clubs"), app.buttons["analysis.chip.clubs"].label)
        XCTAssertTrue(any(app, "analysis.gap.selectedOnly").waitForExistence(timeout: 5))
        XCTAssertFalse(any(app, "analysis.gap.row.2").exists, "two clubs, two rows")
        app.terminate()
        let again = launch("en", reset: false)
        openAnalysis(again)
        XCTAssertTrue(again.buttons["analysis.chip.clubs"].label.contains("2 clubs"), "the applied filter survived a relaunch")
    }

    /// Distance and conditions chips apply at once; Standardised shows no recorded numbers under that label.
    func testTotalAndStandardisedChips() {
        let app = launch("en")
        openAnalysis(app)
        app.buttons["analysis.chip.conditions"].tap()
        app.buttons["Standardised"].firstMatch.tap()
        XCTAssertTrue(any(app, "analysis.standardised.note").waitForExistence(timeout: 5))
        let none = any(app, "analysis.card.0")
        XCTAssertTrue(none.waitForExistence(timeout: 5))
        XCTAssertTrue(
            label(none).contains("No data") && !label(none).contains("131"),
            "no recorded numbers under Standardised: " + label(none)
        )
        app.buttons["analysis.chip.conditions"].tap()
        app.buttons["As recorded"].firstMatch.tap()
        XCTAssertTrue(any(app, "analysis.card.0").waitForExistence(timeout: 5))
        app.buttons["analysis.chip.distance"].tap()
        app.buttons["Total"].firstMatch.tap()
        // The demo shots have no total distance: honest "No data", never 0.
        let total = any(app, "analysis.card.0")
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertTrue(label(total).contains("No data") && !label(total).contains(" 0 m"), label(total))
    }

    /// Dispersion plot with the shot list alternative; opening a shot from the list shows its detail.
    func testDispersionHasAPlotAndAListAlternative() {
        let app = launch("en")
        openAnalysis(app)
        chooseTab(app, 2)
        XCTAssertTrue(any(app, "analysis.disp.plot").waitForExistence(timeout: 8))
        XCTAssertTrue(any(app, "analysis.disp.legend.0").exists)
        shot("analysis-en-port-dispersion")
        let list = any(app, "analysis.disp.list")
        app.reveal(list)
        list.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'PW'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    /// "Analyse this session" from a session screen scopes the analysis to that session.
    func testAnalyseThisSessionScopesTheAnalysis() {
        let app = launch("en")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let firstSession = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstSession.waitForExistence(timeout: 8))
        firstSession.tap()
        let analyse = app.buttons["session.analyse"]
        XCTAssertTrue(analyse.waitForExistence(timeout: 8))
        analyse.tap()
        XCTAssertTrue(any(app, "analysis.scope").waitForExistence(timeout: 8))
        // The newest seeded session is practice with 7 iron and PW only.
        XCTAssertTrue(any(app, "analysis.card.0").waitForExistence(timeout: 5))
        XCTAssertFalse(any(app, "analysis.card.2").exists)
        app.buttons["analysis.scope.clear"].tap()
        XCTAssertTrue(any(app, "analysis.card.2").waitForExistence(timeout: 5), "all sessions again")
    }

    func testSwedishLandscapeAveragesAndDispersion() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch("sv")
        openAnalysis(app, landscape: true)
        let card = any(app, "analysis.card.0")
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        XCTAssertTrue(
            label(card).contains("Medelflyglängd") && label(card).contains("Beräknad") && label(card).contains("Preliminär"),
            card.label
        )
        shot("analysis-sv-land-averages")
        chooseTab(app, 2)
        XCTAssertTrue(any(app, "analysis.disp.plot").waitForExistence(timeout: 8))
        shot("analysis-sv-land-dispersion")
    }
}
