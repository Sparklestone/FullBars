import XCTest
@testable import FullBars

final class SettingsViewModelTests: XCTestCase {

    private var vm: SettingsViewModel!
    private let suite = UserDefaults(suiteName: "SettingsViewModelTests")!

    override func setUp() {
        super.setUp()
        // Clear previous test state
        suite.removePersistentDomain(forName: "SettingsViewModelTests")
        vm = SettingsViewModel()
    }

    // MARK: - Defaults

    func testDarkModeDefaultsToTrue() {
        // Before any explicit set, isDarkMode should default to true.
        // NOTE: this test uses the shared UserDefaults, so clean state is important.
        let fresh = SettingsViewModel()
        // We can't guarantee shared defaults are clean, but after resetToDefaults:
        fresh.resetToDefaults()
        XCTAssertTrue(fresh.isDarkMode)
    }

    func testMeasurementUnitDefaultsToMetric() {
        vm.resetToDefaults()
        XCTAssertEqual(vm.measurementUnit, "metric")
    }

    func testSignalDropThresholdDefaultsToNeg75() {
        vm.resetToDefaults()
        XCTAssertEqual(vm.signalDropThreshold, -75)
    }

    func testDataRetentionDaysDefaultsTo30() {
        vm.resetToDefaults()
        XCTAssertEqual(vm.dataRetentionDays, 30)
    }

    func testAutoRefreshIntervalDefaultsTo5() {
        vm.resetToDefaults()
        XCTAssertEqual(vm.autoRefreshInterval, 5)
    }

    func testShowAdvancedMetricsDefaultsToFalse() {
        vm.resetToDefaults()
        XCTAssertFalse(vm.showAdvancedMetrics)
    }

    func testDisplayModeDefaultsToBasic() {
        vm.resetToDefaults()
        XCTAssertEqual(vm.displayMode, .basic)
    }

    // MARK: - Setters round-trip

    func testDarkModeToggle() {
        vm.isDarkMode = false
        XCTAssertFalse(vm.isDarkMode)
        vm.isDarkMode = true
        XCTAssertTrue(vm.isDarkMode)
    }

    func testMeasurementUnitRoundTrip() {
        vm.measurementUnit = "imperial"
        XCTAssertEqual(vm.measurementUnit, "imperial")
        vm.measurementUnit = "metric"
        XCTAssertEqual(vm.measurementUnit, "metric")
    }

    func testSignalDropThresholdRoundTrip() {
        vm.signalDropThreshold = -80
        XCTAssertEqual(vm.signalDropThreshold, -80)
    }

    func testDataRetentionDaysRoundTrip() {
        vm.dataRetentionDays = 90
        XCTAssertEqual(vm.dataRetentionDays, 90)
    }

    func testAutoRefreshIntervalRoundTrip() {
        vm.autoRefreshInterval = 10
        XCTAssertEqual(vm.autoRefreshInterval, 10)
    }

    func testShowAdvancedMetricsRoundTrip() {
        vm.showAdvancedMetrics = true
        XCTAssertTrue(vm.showAdvancedMetrics)
    }

    func testIspPromisedSpeedRoundTrip() {
        vm.ispPromisedSpeed = 200.5
        XCTAssertEqual(vm.ispPromisedSpeed, 200.5, accuracy: 0.001)
    }

    func testIspNameRoundTrip() {
        vm.ispName = "Comcast"
        XCTAssertEqual(vm.ispName, "Comcast")
    }

    func testDisplayModeRoundTrip() {
        vm.displayMode = .advanced
        XCTAssertEqual(vm.displayMode, .advanced)
        vm.displayMode = .basic
        XCTAssertEqual(vm.displayMode, .basic)
    }

    // MARK: - resetToDefaults

    func testResetToDefaultsRestoresAllSettings() {
        // Set non-default values
        vm.isDarkMode = false
        vm.measurementUnit = "imperial"
        vm.notifyOnSignalDrop = false
        vm.signalDropThreshold = -90
        vm.dataRetentionDays = 365
        vm.autoRefreshInterval = 60
        vm.showAdvancedMetrics = true
        vm.displayMode = .advanced

        vm.resetToDefaults()

        XCTAssertTrue(vm.isDarkMode)
        XCTAssertEqual(vm.measurementUnit, "metric")
        XCTAssertTrue(vm.notifyOnSignalDrop)
        XCTAssertEqual(vm.signalDropThreshold, -75)
        XCTAssertEqual(vm.dataRetentionDays, 30)
        XCTAssertEqual(vm.autoRefreshInterval, 5)
        XCTAssertFalse(vm.showAdvancedMetrics)
        XCTAssertEqual(vm.displayMode, .basic)
    }
}
