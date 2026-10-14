import XCTest

/// F19a on screen: Settings -> Membership, Apple's code sheet (scripted: no real code, no network) and what is shown afterwards.
final class MembershipUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    func launch(_ lang: String, store: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestFakeVoice", "-uiTestStore", store,
        ]
        app.launch()
        return app
    }

    func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func openMembership(_ app: XCUIApplication) -> XCUIElement {
        let gear = app.buttons["nav.settings"].firstMatch
        XCTAssertTrue(gear.waitForExistence(timeout: 12))
        gear.tap()
        let redeem = app.buttons["settings.redeem"]
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        app.reveal(redeem)
        XCTAssertTrue(redeem.waitForExistence(timeout: 8))
        return redeem
    }

    func testFreeMemberSeesFreePlanAndTheWarningBeforeRedeeming() {
        let app = launch("en", store: "ok")
        _ = openMembership(app)
        XCTAssertTrue(any(app, "settings.membership.status").label.contains("Free plan"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'never cancels or refunds'")).firstMatch.exists)
    }

    func testRedeemingAFreeOfferShowsComplimentaryAccessEndDateAndNoCharge() {
        let app = launch("en", store: "redeem")
        let redeem = openMembership(app)
        redeem.tap()
        let status = any(app, "settings.redeem.status")
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertTrue(status.label.contains("Pro access is active"), status.label)
        let member = any(app, "settings.membership.status")
        XCTAssertTrue(member.label.contains("Complimentary"), member.label)
        XCTAssertTrue(member.label.contains("Access ends"), member.label)
        XCTAssertTrue(member.label.contains("No charge when this access ends"), member.label)
        app.buttons["settings.done"].tap()
        let row = any(app, "home.allowance")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        XCTAssertTrue(row.label.contains("unlimited shots"), row.label)
        XCTAssertFalse(app.buttons["home.plans"].exists, "no upgrade prompt while Pro access is valid")
    }

    func testACodeThatUnlocksNothingIsSaidSoAndStaysFree() {
        let app = launch("en", store: "ok")
        let redeem = openMembership(app)
        redeem.tap()
        let status = any(app, "settings.redeem.status")
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        _ = NSPredicate(format: "label CONTAINS 'Nothing was unlocked'")
        let done = expectation(for: NSPredicate(format: "label CONTAINS 'Nothing was unlocked'"), evaluatedWith: status)
        wait(for: [done], timeout: 20)
        XCTAssertTrue(any(app, "settings.membership.status").label.contains("Free plan"))
    }

    func testSwedishComplimentaryAccess() {
        let app = launch("sv", store: "redeem")
        let redeem = openMembership(app)
        redeem.tap()
        let member = any(app, "settings.membership.status")
        let done = expectation(for: NSPredicate(format: "label CONTAINS 'Kostnadsfri'"), evaluatedWith: member)
        wait(for: [done], timeout: 20)
        XCTAssertTrue(member.label.contains("Ingen debitering när denna åtkomst upphör"), member.label)
        XCTAssertTrue(member.label.contains("Åtkomsten upphör"), member.label)
    }
}
