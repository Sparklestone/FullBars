import XCTest

/// Exercise user-visible flows that require data already present — uses the
/// `-UITesting-SeedRooms <N>` launch hook (see UITestingLaunchHandler) to
/// stand up a populated Results tab without running a real scan.
final class PopulatedFlowsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Boots the app with N seeded rooms. Fails fast if the tab bar doesn't
    /// appear within 10s — that means SkipOnboarding or the seed logic broke.
    private func launchedWithSeededRooms(_ count: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting-SeedRooms", String(count)]
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Tab bar never appeared with -UITesting-SeedRooms \(count). Check UITestingLaunchHandler."
        )
        return app
    }

    // MARK: - Results tab shows seeded rooms (happy path)

    func testResultsTabShowsSeededRooms() {
        let app = launchedWithSeededRooms(3)
        app.tabBars.firstMatch.buttons["Results"].tap()

        // "Overall grade" is one of the headers that only renders when rooms exist.
        XCTAssertTrue(
            app.staticTexts["Overall grade"].waitForExistence(timeout: 5),
            "Overall grade card should render when rooms are present"
        )
        // "Rooms" section header
        XCTAssertTrue(
            app.staticTexts["Rooms"].waitForExistence(timeout: 2),
            "Rooms section header should render"
        )
    }

    // MARK: - Drilldown: Results → RoomDetailView

    func testResultsDrilldownOpensRoomDetail() {
        let app = launchedWithSeededRooms(3)
        app.tabBars.firstMatch.buttons["Results"].tap()

        // Wait for the Rooms section to be populated, then tap the first room row.
        // SwiftUI's NavigationLink can surface as button / cell / otherElement depending
        // on accessibility wiring and iOS version — we try a few.
        XCTAssertTrue(app.staticTexts["Rooms"].waitForExistence(timeout: 5))

        // NavigationLink renders as a button whose label concatenates the row's text
        // children (e.g. "Living Room, 50 Mbps · 20 ms ping, A"). Match on label prefix.
        let roomNames = ["Living Room", "Kitchen", "Bedroom", "Bathroom", "Office", "Hallway"]

        func tapFirstRow() -> Bool {
            // 1) Try a button whose label begins with a known room name.
            for name in roomNames {
                let pred = NSPredicate(format: "label BEGINSWITH %@", name)
                let btn = app.buttons.matching(pred).firstMatch
                if btn.waitForExistence(timeout: 1) {
                    btn.tap()
                    return true
                }
            }
            // 2) Fallback: any button that CONTAINS a room name anywhere in its label.
            for name in roomNames {
                let pred = NSPredicate(format: "label CONTAINS %@", name)
                let btn = app.buttons.matching(pred).firstMatch
                if btn.exists { btn.tap(); return true }
            }
            // 3) Last resort: tap the staticText and hope the row picks it up.
            for name in roomNames {
                let text = app.staticTexts[name]
                if text.exists { text.tap(); return true }
            }
            return false
        }

        XCTAssertTrue(tapFirstRow(), "Expected one of the seeded room rows to be tappable")

        // RoomDetailView always renders "Floor plan", "Layers", and "Recommendations"
        // section headers. "Scan history" is Pro-gated and only shows with >1 history
        // entry, so don't use it as the landing sentinel.
        let landed =
            app.staticTexts["Floor plan"].waitForExistence(timeout: 5) ||
            app.staticTexts["Layers"].waitForExistence(timeout: 1) ||
            app.staticTexts["Recommendations"].waitForExistence(timeout: 1)
        XCTAssertTrue(landed, "Drilldown should land in RoomDetailView (Floor plan/Layers/Recommendations)")

        // Pop back and confirm we're on Results again.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 3))
    }

    // MARK: - Home Scan populated state (non-empty)

    func testHomeScanPopulatedShowsScanAnother() {
        let app = launchedWithSeededRooms(2)
        app.tabBars.firstMatch.buttons["Home Scan"].tap()

        // When rooms exist, the "Scanned rooms" list and the "Scan another room"
        // button should be visible — NOT the first-run empty-state copy.
        XCTAssertTrue(
            app.staticTexts["Scanned rooms"].waitForExistence(timeout: 5) ||
            app.buttons["Scan another room"].waitForExistence(timeout: 1),
            "Home Scan with seeded rooms should show the populated list, not the empty state"
        )
        XCTAssertFalse(
            app.staticTexts["Scan your first room"].exists,
            "Empty-state copy should NOT appear when rooms are seeded"
        )
    }

    // MARK: - Seeded Results is stable under rapid scroll + drill

    func testResultsScrollAndBackIsStable() {
        let app = launchedWithSeededRooms(6)
        app.tabBars.firstMatch.buttons["Results"].tap()
        XCTAssertTrue(app.staticTexts["Overall grade"].waitForExistence(timeout: 5))

        // Scroll the results list a few times — shouldn't crash or blow a constraint.
        let scroll = app.scrollViews.firstMatch
        if scroll.exists {
            for _ in 0..<3 {
                scroll.swipeUp()
            }
            scroll.swipeDown()
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
