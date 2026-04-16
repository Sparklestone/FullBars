import XCTest

/// Cover the key user flows beyond onboarding: starting a scan, exploring
/// the Results tab, and navigating Settings sub-screens. These tests are
/// deliberately resilient to copy tweaks — they look for any of a set of
/// likely labels, then assert the app didn't crash.
final class KeyFlowsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches the app past onboarding and returns it. The `-UITesting-SkipOnboarding`
    /// hook is implemented in `UITestingLaunchHandler.swift` — a timeout here
    /// is a real regression, not a missing hook.
    private func launchedApp(_ extraArgs: [String] = ["-UITesting-SkipOnboarding"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += extraArgs
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Tab bar never appeared — `-UITesting-SkipOnboarding` regression. See UITestingLaunchHandler."
        )
        return app
    }

    private func anyExists(_ app: XCUIApplication, labels: [String], timeout: TimeInterval = 3) -> Bool {
        for label in labels {
            if app.staticTexts[label].waitForExistence(timeout: timeout) { return true }
            if app.buttons[label].waitForExistence(timeout: 0.5) { return true }
            if app.otherElements[label].waitForExistence(timeout: 0.5) { return true }
        }
        return false
    }

    // MARK: - Home Scan: empty-state "start scan" entry point

    func testHomeScanEmptyStateOffersStartScan() {
        let app = launchedApp(["-UITesting-SkipOnboarding", "-UITesting-NoRooms"])
        app.tabBars.firstMatch.buttons["Home Scan"].tap()

        let found = anyExists(app, labels: [
            "Scan your first room", "Start scan", "Start your first scan", "Scan a room"
        ])
        XCTAssertTrue(found, "Empty-state CTA should surface on the Home Scan tab when no rooms are saved")
    }

    // MARK: - Results tab populates after skip (there may or may not be rooms)

    func testResultsTabRendersWithoutCrashing() {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons["Results"].tap()
        // Accept either an empty-state label or a results header.
        let found = anyExists(app, labels: [
            "No rooms scanned yet", "Results", "Overall grade", "Coverage", "Space grade"
        ])
        XCTAssertTrue(found, "Results tab should render some recognisable header or empty-state")
    }

    // MARK: - Settings sub-navigation does not crash

    func testSettingsAboutAndPrivacyOpen() {
        let app = launchedApp()
        app.tabBars.firstMatch.buttons["Settings"].tap()

        // Attempt to open each top-level settings entry; we're not asserting
        // layout, just that tapping doesn't push us into a dead state.
        for entry in ["Internet plan", "Share anonymous data", "Privacy", "About"] {
            let btn = app.buttons[entry].firstMatch
            if btn.waitForExistence(timeout: 2) {
                btn.tap()
                // Pop back if a nav bar is present
                let back = app.navigationBars.buttons.element(boundBy: 0)
                if back.exists { back.tap() }
            }
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Tab switching under rapid taps (smoke)

    func testRapidTabSwitchingIsStable() {
        let app = launchedApp()
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<5 {
            tabBar.buttons["Results"].tap()
            tabBar.buttons["Settings"].tap()
            tabBar.buttons["Home Scan"].tap()
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Backgrounding doesn't crash

    func testBackgroundAndForegroundDoesNotCrash() {
        let app = launchedApp()
        XCUIDevice.shared.press(.home)
        // small pause for the app to deactivate
        _ = app.wait(for: .runningBackground, timeout: 5)
        app.activate()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Rotation (iPad + Pro Max) should not crash

    func testRotationDoesNotCrash() {
        let app = launchedApp()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(app.state, .runningForeground)
    }
}
