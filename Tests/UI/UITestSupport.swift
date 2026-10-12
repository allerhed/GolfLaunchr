import XCTest

extension XCUIApplication {
    /// Scrolls the visible list or form until `element` is on screen (clear of the bottom edge and the home indicator). Settings has
    /// grown, so rows can start below the fold. Uses frames, not `isHittable`, which reports an error for rows that are out of view.
    func reveal(_ element: XCUIElement, maxSwipes: Int = 12) {
        let screen = windows.firstMatch.frame
        func isOnScreen() -> Bool {
            guard element.exists else { return false }
            let f = element.frame
            return f.height > 0 && f.minY >= screen.minY + 60 && f.maxY <= screen.maxY - 90
        }
        _ = element.waitForExistence(timeout: 4)
        var swipes = 0
        while !isOnScreen(), swipes < maxSwipes {
            let list = collectionViews.firstMatch.exists ? collectionViews
                .firstMatch : (tables.firstMatch.exists ? tables.firstMatch : self)
            list.swipeUp()
            swipes += 1
        }
    }
}
