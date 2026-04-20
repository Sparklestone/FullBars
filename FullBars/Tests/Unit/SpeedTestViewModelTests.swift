import XCTest
@testable import FullBars

/// Unit tests for SpeedTestViewModel — specifically the generateReport()
/// string builder and history/state management (no network calls).
final class SpeedTestViewModelTests: XCTestCase {

    private var vm: SpeedTestViewModel!

    override func setUp() {
        super.setUp()
        vm = SpeedTestViewModel()
    }

    // MARK: - Initial state

    func testInitialStateHasNoResult() {
        XCTAssertNil(vm.currentResult)
        XCTAssertTrue(vm.testHistory.isEmpty)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - generateReport()

    func testReportWithNoDataContainsHeader() {
        let report = vm.generateReport()
        XCTAssertTrue(report.contains("Speed Test Report"))
    }

    func testReportIncludesCurrentResult() {
        vm.currentResult = SpeedTestResult(
            downloadSpeed: 142.5,
            uploadSpeed: 22.1,
            latency: 18,
            jitter: 3.4,
            packetLoss: 0.1,
            serverName: "Chicago",
            serverLocation: "US"
        )
        let report = vm.generateReport()
        XCTAssertTrue(report.contains("142.50"), "Report should include download speed")
        XCTAssertTrue(report.contains("22.10"), "Report should include upload speed")
        XCTAssertTrue(report.contains("18.00"), "Report should include latency")
        XCTAssertTrue(report.contains("3.40"), "Report should include jitter")
    }

    func testReportIncludesHistoryAverages() {
        vm.testHistory = [
            SpeedTestResult(downloadSpeed: 100, uploadSpeed: 20, latency: 10),
            SpeedTestResult(downloadSpeed: 200, uploadSpeed: 40, latency: 30),
        ]
        let report = vm.generateReport()
        XCTAssertTrue(report.contains("150.00"), "Report should include avg download (100+200)/2")
        XCTAssertTrue(report.contains("30.00"), "Report should include avg upload (20+40)/2")
        XCTAssertTrue(report.contains("20.00"), "Report should include avg latency (10+30)/2")
        XCTAssertTrue(report.contains("Last 2 tests"))
    }

    func testReportWithEmptyHistoryOmitsAverageSection() {
        vm.currentResult = SpeedTestResult(downloadSpeed: 50)
        vm.testHistory = []
        let report = vm.generateReport()
        XCTAssertFalse(report.contains("Average Performance"))
    }

    // MARK: - CoverageAnalysisResult computed properties

    func testAnalysisResultAssessmentExcellent() {
        let result = CoverageAnalysisResult(
            weakSpots: [],
            meshRecommendations: [],
            interferenceZones: [],
            coveragePercentage: 95,
            estimatedRouterPosition: nil,
            floorCount: 1,
            timestamp: .now
        )
        XCTAssertTrue(result.overallAssessment.contains("Excellent"))
        XCTAssertEqual(result.weakSpotCount, 0)
        XCTAssertFalse(result.hasCriticalWeakSpots)
    }

    func testAnalysisResultAssessmentPoor() {
        let ws = WeakSpot(
            centerX: 0, centerZ: 0, radius: 2,
            floorIndex: 0, averageSignal: -90,
            pointCount: 5, roomName: "Garage",
            severity: .critical
        )
        let result = CoverageAnalysisResult(
            weakSpots: [ws, ws, ws],
            meshRecommendations: [],
            interferenceZones: [],
            coveragePercentage: 30,
            estimatedRouterPosition: nil,
            floorCount: 1,
            timestamp: .now
        )
        XCTAssertTrue(result.overallAssessment.contains("Poor"))
        XCTAssertTrue(result.hasCriticalWeakSpots)
        XCTAssertEqual(result.weakSpotCount, 3)
    }

    // MARK: - WeakSpotSeverity display

    func testWeakSpotSeverityLabels() {
        XCTAssertEqual(WeakSpotSeverity.critical.label, "No Signal")
        XCTAssertEqual(WeakSpotSeverity.severe.label, "Very Weak")
        XCTAssertEqual(WeakSpotSeverity.moderate.label, "Weak Zone")
    }

    func testWeakSpotSeverityDescriptions() {
        for severity in WeakSpotSeverity.allCases {
            XCTAssertFalse(severity.friendlyDescription.isEmpty)
            XCTAssertFalse(severity.icon.isEmpty)
        }
    }

    // MARK: - PlacementType display

    func testPlacementTypeLabels() {
        XCTAssertEqual(PlacementType.primaryRouter.label, "Router")
        XCTAssertEqual(PlacementType.meshNode.label, "Mesh Node")
        XCTAssertEqual(PlacementType.extender.label, "Extender")
    }
}
