import XCTest

/// UI smoke tests — launch the app and verify the primary flows render
/// without crashing. These are deliberately lightweight (no deep assertions
/// about layout) so they're fast to run on every PR.
final class OnboardingSmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// App launches at all (the "is this thing on?" test)
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting-ResetState"]
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// First-launch (ResetState clears the onboarding flag) should land in
    /// onboarding, NOT the main shell. The ResetState hook is implemented in
    /// `UITestingLaunchHandler.swift`.
    func testOnboardingAppearsOnFirstLaunch() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting-ResetState"]
        app.launch()

        // Predicate matches any of several onboarding-ish copy strings.
        let onboardingRegex = "(?i).*(welcome|get started|let.?s\\s+(go|set)|step\\s+\\d|continue|skip setup).*"
        let onboardingPredicate = NSPredicate(format: "label MATCHES[c] %@", onboardingRegex)

        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 5)

        let onboardingVisible =
            app.staticTexts.matching(onboardingPredicate).firstMatch.waitForExistence(timeout: 3) ||
            app.buttons.matching(onboardingPredicate).firstMatch.waitForExistence(timeout: 1)

        if onboardingVisible { return }

        let visible = app.staticTexts.allElementsBoundByIndex.prefix(20).map { $0.label }
        XCTFail("-UITesting-ResetState did not land in onboarding. Visible: \(visible)")
    }

    /// Post-onboarding, the three-tab shell should be visible. `-UITesting-SkipOnboarding`
    /// is implemented in `UITestingLaunchHandler.swift`; a timeout here is a
    /// real regression, not a missing hook.
    private func launchPastOnboarding(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITesting-SkipOnboarding"] + extra
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 8),
            "Tab bar never appeared — `-UITesting-SkipOnboarding` regression. See UITestingLaunchHandler."
        )
        return app
    }

    func testMainShellShowsThreeTabs() {
        let app = launchPastOnboarding()
        let tabBar = app.tabBars.firstMatch

        // Three tabs in the new shell: Home Scan, Results, Settings
        for tab in ["Home Scan", "Results", "Settings"] {
            XCTAssertTrue(
                tabBar.buttons[tab].exists,
                "Expected tab '\(tab)' to exist in the tab bar"
            )
        }
    }

    func testSwitchingTabsDoesNotCrash() {
        let app = launchPastOnboarding()
        let tabBar = app.tabBars.firstMatch

        tabBar.buttons["Results"].tap()
        tabBar.buttons["Settings"].tap()
        tabBar.buttons["Home Scan"].tap()

        // Still running
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSettingsTabRendersCoreCards() {
        let app = launchPastOnboarding()

        app.tabBars.firstMatch.buttons["Settings"].tap()

        // These labels come from SettingsHomeView.swift
        let expected = ["Internet plan", "Share anonymous data", "Reset onboarding"]
        for label in expected {
            XCTAssertTrue(
                app.staticTexts[label].waitForExistence(timeout: 3) ||
                app.buttons[label].waitForExistence(timeout: 1),
                "Expected '\(label)' on the Settings tab"
            )
        }
    }

    func testEmptyResultsTabShowsEmptyState() {
        let app = launchPastOnboarding(extra: ["-UITesting-NoRooms"])

        app.tabBars.firstMatch.buttons["Results"].tap()

        XCTAssertTrue(
            app.staticTexts["No rooms scanned yet"].waitForExistence(timeout: 3),
            "Empty state copy should appear when no rooms exist"
        )
    }
}
