import XCTest

final class HomeUITests: XCTestCase {
    func launch(_ lang: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang]
        app.launch()
        return app
    }

    func testHomeEnglish() {
        let app = launch("en")
        XCTAssertEqual(app.staticTexts["home.subtitle"].label, "Golf launch monitor")
    }

    func testHomeSwedish() {
        let app = launch("sv")
        XCTAssertEqual(app.staticTexts["home.subtitle"].label, "Slagmätare för golf")
    }
}
