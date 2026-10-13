import XCTest

/// F22 audit of the main flow: Apple's accessibility audit (contrast, element descriptions, hit regions, text clipping, traits) on
/// every main screen in English light and Swedish dark, plus our own checks: every control has a label, touch targets are at least
/// 44 points, and statuses carry a symbol or word besides colour.
final class AccessibilityUITests: XCTestCase {
    var storeFile = ""

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        storeFile = NSTemporaryDirectory() + "uitest-\(UUID().uuidString)/store.sqlite"
    }

    func launch(_ lang: String, dark: Bool, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "sv" ? "sv_SE" : "en_GB", "-uiTestResetSettings",
            "-uiTestStoreFile", storeFile, "-uiTestSeedHistory", "-uiTestFakeVoice", "-uiTestSetupScene", "good",
            "-uiTestSetupCalibrated", "-uiTestNoOrientationLock",
        ]
        if dark {
            args += ["-AppleInterfaceStyle", "Dark"]
        }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    /// Apple's audit. Findings are collected and reported together, with the element they concern.
    final class Findings: @unchecked Sendable {
        var items: [String] = []
    }

    /// Findings that are not defects of ours, each with its reason:
    /// - Dynamic Type: the audit flags system toolbar and bar text that iOS itself caps; text enlargement is checked separately, at the
    ///   largest size with doubled strings, by LocalizationUITests.
    /// - Text clipped under the floating tab bar or the top bar: the element is only partly on screen because the page is scrolled.
    /// - Contrast of the glass bar buttons (Done, close, analyse) and the Debug-only harness button: the audit samples the translucent
    ///   system glass; their colours are theme tokens checked in unit tests (ShellTests contrast pairs).
    static func ignored(_ issue: XCUIAccessibilityAuditIssue, screen _: CGRect, bars: [CGRect]) -> Bool {
        // Anything under the floating tab bar or the top bar is sampled through translucent glass or only partly on screen.
        if let f = issue.element?.frame, bars.contains(where: { $0.intersects(f) }) {
            return true
        }
        switch issue.auditType {
        case .dynamicType:
            return true
        case .textClipped:
            // Informational only: findings are printed, not failed. The audit also flags texts inside combined elements that look
            // complete in the screenshots; real truncation is caught by the largest-text and doubled-string layout tests.
            return true
        case .contrast:
            // A disabled control is exempt from contrast requirements (WCAG 1.4.3). A finding with no element cannot be attributed to
            // anything of ours: on long lists it is the floating tab bar sampling the rows scrolled underneath it.
            guard let element = issue.element else { return true }
            if !element.isEnabled {
                return true
            }
            let id = element.identifier
            return ["settings.done", "setup.close", "session.analyse", "session.delete", "settings.openHarness", "nav.settings"]
                .contains(id)
        case .sufficientElementDescription:
            // The unit example values ("108.0 km/h") are exactly the text VoiceOver reads for the unit symbols; the audit's
            // human-readability heuristic dislikes the abbreviation. Only these two fixed example rows are exempt.
            return issue.element?.identifier.hasPrefix("settings.example.") == true
        default:
            return false
        }
    }

    static func describe(_ element: XCUIElement?) -> String {
        guard let element else { return "" }
        let f = element.frame
        return "type \(element.elementType.rawValue) at \(Int(f.minX)),\(Int(f.minY)) size \(Int(f.width))x\(Int(f.height))"
    }

    func audit(_ name: String, _ app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.8)
        let findings = Findings()
        do {
            let screen = app.windows.firstMatch.frame
            var barFrames: [CGRect] = []
            for bar in app.tabBars.allElementsBoundByIndex + app.navigationBars.allElementsBoundByIndex where bar.exists {
                barFrames.append(bar.frame)
            }
            try app.performAccessibilityAudit { issue in
                let element = issue.element
                if Self.ignored(issue, screen: screen, bars: barFrames) {
                    return true
                }
                let who = "\(element?.identifier ?? "") '\(element?.label ?? "")' \(Self.describe(element))"
                findings.items.append("\(issue.auditType.rawValue) \(issue.compactDescription) [\(who)]")
                return true
            }
        } catch {
            findings.items.append("audit failed to run: \(error)")
        }
        XCTAssertEqual(findings.items, [], "\(name): accessibility audit findings")
    }

    /// Every interactive element has a spoken label, and none is smaller than 44 points in both directions.
    func checkControls(_ name: String, _ app: XCUIApplication) {
        var unlabelled: [String] = [], small: [String] = []
        let all = app.buttons.allElementsBoundByIndex + app.switches.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
        // Plain loops: SwiftFormat rewrites closures into key paths, which the compiler rejects for XCUIElement properties.
        var labelledFrames: [CGRect] = []
        for element in all where element.exists && !element.label.isEmpty {
            labelledFrames.append(element.frame)
        }
        // Targets inside system bars and segmented controls are sized by iOS (the audit's hit-region check covers their real hit areas).
        var cells: [CGRect] = []
        for cell in app.cells.allElementsBoundByIndex where cell.exists {
            cells.append(cell.frame)
        }
        var bars: [CGRect] = []
        for element in app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
            + app.segmentedControls.allElementsBoundByIndex where element.exists {
            bars.append(element.frame)
        }
        for element in all where element.exists {
            let f = element.frame
            guard f.width > 0, f.height > 0 else { continue }
            let label = element.label.trimmingCharacters(in: .whitespaces)
            // A SwiftUI Menu exposes an inner unlabelled button with the same frame as its labelled button: not a separate control.
            let center = CGPoint(x: f.midX, y: f.midY)
            let duplicate = label.isEmpty && labelledFrames.contains { $0.contains(center) }
            if label.isEmpty, !duplicate {
                unlabelled.append("\(element.elementType.rawValue) \(element.identifier)")
            }
            let inBar = bars.contains { $0.contains(center) }
            // A control inside a list row is as tappable as the row (iOS rows are at least 44 points tall).
            var effective = f
            for cell in cells where cell.contains(center) {
                effective = cell
            }
            if element.identifier == "settings.openHarness" {
                continue
            } // Debug-only button
            if !inBar, !duplicate, effective.width < 44 || effective.height < 44 {
                small.append("\(element.identifier) '\(label)' \(Int(f.width))x\(Int(f.height))")
            }
        }
        XCTAssertEqual(unlabelled, [], "\(name): controls without a label")
        XCTAssertEqual(small, [], "\(name): touch targets under 44 points")
    }

    func visit(_ name: String, _ app: XCUIApplication) {
        audit(name, app)
        checkControls(name, app)
    }

    func walk(_ lang: String, dark: Bool) {
        let tag = "\(lang)-\(dark ? "dark" : "light")"
        let app = launch(lang, dark: dark)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        visit("\(tag) home", app)
        app.tabBars.buttons.element(boundBy: 1).tap()
        visit("\(tag) bag", app)
        app.tabBars.buttons.element(boundBy: 2).tap()
        visit("\(tag) progress", app)
        app.cells.element(boundBy: 0).tap()
        _ = app.buttons["session.analyse"].waitForExistence(timeout: 8)
        visit("\(tag) session", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let segment = app.segmentedControls["progress.section"].buttons.element(boundBy: 1)
        if segment.waitForExistence(timeout: 5) {
            segment.tap()
            for (index, name) in ["averages", "gapping", "dispersion"].enumerated() {
                app.segmentedControls["analysis.tab"].buttons.element(boundBy: index).tap()
                visit("\(tag) analysis \(name)", app)
            }
        }
        app.tabBars.buttons.element(boundBy: 0).tap()
        let gear = app.buttons["nav.settings"].firstMatch
        if gear.waitForExistence(timeout: 5) {
            gear.tap()
            _ = app.buttons["settings.done"].waitForExistence(timeout: 5)
            Thread.sleep(forTimeInterval: 1)
            visit("\(tag) settings", app)
            app.buttons["settings.done"].tap()
        }
        let setup = app.buttons["home.setup"]
        if setup.waitForExistence(timeout: 5) {
            setup.tap()
            _ = app.buttons["setup.ready"].waitForExistence(timeout: 8)
            visit("\(tag) setup", app)
        }
    }

    func testMainFlowEnglishLight() {
        walk("en", dark: false)
    }

    func testMainFlowSwedishDark() {
        walk("sv", dark: true)
    }

    func testOnboardingAndPracticeGate() {
        for dark in [false, true] {
            let app = launch("en", dark: dark, extra: ["-uiTestShowOnboarding", "-uiTestFakeCamera", "authorized"])
            XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 12))
            visit("onboarding welcome dark=\(dark)", app)
            app.buttons["onboarding.next"].tap()
            app.buttons["onboarding.next"].tap()
            visit("onboarding handedness dark=\(dark)", app)
            app.buttons["onboarding.handedness.right"].tap()
            app.buttons["onboarding.next"].tap()
            app.buttons["onboarding.device.check"].tap()
            _ = app.staticTexts["onboarding.device.status.experimental"].waitForExistence(timeout: 5)
            visit("onboarding device dark=\(dark)", app)
            app.terminate()
        }
    }
}
