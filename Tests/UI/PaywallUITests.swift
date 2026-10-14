import XCTest

/// F19 commerce screens against a scripted store (no purchase, no network), in English and Swedish. The real StoreKit catalog is
/// not tested here: the StoreKit test configuration reached the app in two early runs and not in later ones (docs/EVIDENCE.md 6.3).
final class PaywallUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    func launch(_ lang: String, store: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestFakeVoice",
        ]
        if let store {
            args += ["-uiTestStore", store]
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

    func openPlans(_ app: XCUIApplication) {
        let plans = app.buttons["home.plans"]
        XCTAssertTrue(plans.waitForExistence(timeout: 12))
        plans.tap()
        XCTAssertTrue(any(app, "paywall.root").waitForExistence(timeout: 8))
    }

    func testPlansShowStorePricesAnnualFigureAndSavingEnglish() {
        let app = launch("en", store: "ok")
        openPlans(app)
        let monthly = any(app, "paywall.plan.monthly")
        XCTAssertTrue(monthly.waitForExistence(timeout: 8))
        XCTAssertTrue(plain(monthly.label).contains("49 kr per month"), monthly.label)
        let annual = any(app, "paywall.plan.annual")
        XCTAssertTrue(plain(annual.label).contains("499 kr per year, billed once a year"), annual.label)
        XCTAssertTrue(plain(annual.label).contains("billed annually"), "per-month figure is labelled as annual billing: " + annual.label)
        XCTAssertTrue(plain(annual.label).contains("15.1%"), annual.label)
        XCTAssertTrue(app.buttons["paywall.continueFree"].exists)
        XCTAssertTrue(app.buttons["paywall.restore"].exists && app.buttons["paywall.manage"].exists)
    }

    func testSwedishPlans() {
        let app = launch("sv", store: "ok")
        openPlans(app)
        let annual = any(app, "paywall.plan.annual")
        XCTAssertTrue(annual.waitForExistence(timeout: 8))
        XCTAssertTrue(plain(annual.label).contains("per år, debiteras en gång per år"), annual.label)
        XCTAssertTrue(plain(annual.label).contains("15,1"), annual.label)
        XCTAssertTrue(app.buttons["paywall.restore"].label.contains("Återställ köp"))
    }

    func testLoadFailureOffersRetryAndNoPlan() {
        let app = launch("en", store: "loadFail")
        openPlans(app)
        XCTAssertTrue(any(app, "paywall.failed").waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["paywall.retry"].exists)
        XCTAssertFalse(any(app, "paywall.plan.monthly").exists, "a failed load never shows a plan")
    }

    func testSuccessfulPurchaseShowsProAndUnlimitedOnHome() {
        let app = launch("en", store: "ok")
        openPlans(app)
        app.buttons["paywall.buy.annual"].tap()
        let status = any(app, "paywall.status")
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(status.label.contains("Thank you"), status.label)
        XCTAssertTrue(any(app, "paywall.active").waitForExistence(timeout: 5))
        app.buttons["paywall.continueFree"].tap()
        let row = any(app, "home.allowance")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(plain(row.label).contains("GolfLaunchr Pro: unlimited shots"), row.label)
    }

    func testPendingCancelledAndFailedUnlockNothing() {
        for (scenario, expected) in [("pending", "Nothing is unlocked yet"), ("cancel", "cancelled"), ("fail", "did not go through")] {
            let app = launch("en", store: scenario)
            openPlans(app)
            app.buttons["paywall.buy.monthly"].tap()
            let status = any(app, "paywall.status")
            XCTAssertTrue(status.waitForExistence(timeout: 8), scenario)
            XCTAssertTrue(status.label.contains(expected), "\(scenario): \(status.label)")
            XCTAssertFalse(any(app, "paywall.active").exists, scenario)
            app.terminate()
        }
    }

    func testRestoreWithNothingToRestoreSaysSo() {
        let app = launch("en", store: "ok")
        openPlans(app)
        app.buttons["paywall.restore"].tap()
        let result = any(app, "paywall.restoreStatus")
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(result.label.contains("No earlier purchase"), result.label)
    }
}
