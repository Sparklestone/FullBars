import XCTest
@testable import FullBars

final class DataCollectionServiceTests: XCTestCase {

    // MARK: - coverageBreakdown

    func testCoverageBreakdownEmptyReturnsZeros() {
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: [])
        XCTAssertEqual(s, 0)
        XCTAssertEqual(m, 0)
        XCTAssertEqual(w, 0)
    }

    func testCoverageBreakdownAllStrong() {
        let points = (0..<10).map { _ in
            HeatmapPoint(signalStrength: -50)
        }
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: points)
        XCTAssertEqual(s, 100, accuracy: 0.01)
        XCTAssertEqual(m, 0, accuracy: 0.01)
        XCTAssertEqual(w, 0, accuracy: 0.01)
    }

    func testCoverageBreakdownAllWeak() {
        let points = (0..<10).map { _ in
            HeatmapPoint(signalStrength: -80)
        }
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: points)
        XCTAssertEqual(s, 0, accuracy: 0.01)
        XCTAssertEqual(m, 0, accuracy: 0.01)
        XCTAssertEqual(w, 100, accuracy: 0.01)
    }

    func testCoverageBreakdownAllModerate() {
        let points = (0..<10).map { _ in
            HeatmapPoint(signalStrength: -65)
        }
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: points)
        XCTAssertEqual(s, 0, accuracy: 0.01)
        XCTAssertEqual(m, 100, accuracy: 0.01)
        XCTAssertEqual(w, 0, accuracy: 0.01)
    }

    func testCoverageBreakdownMixed() {
        // 5 strong (-50), 3 moderate (-65), 2 weak (-80)
        var points: [HeatmapPoint] = []
        points += (0..<5).map { _ in HeatmapPoint(signalStrength: -50) }
        points += (0..<3).map { _ in HeatmapPoint(signalStrength: -65) }
        points += (0..<2).map { _ in HeatmapPoint(signalStrength: -80) }
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: points)
        XCTAssertEqual(s, 50, accuracy: 0.01)
        XCTAssertEqual(m, 30, accuracy: 0.01)
        XCTAssertEqual(w, 20, accuracy: 0.01)
    }

    func testCoverageBreakdownBoundarySignals() {
        // -60 is strong (>=), -75 is moderate (>= -75 and < -60)
        let points = [
            HeatmapPoint(signalStrength: -60),  // strong
            HeatmapPoint(signalStrength: -75),   // moderate
        ]
        let (s, m, w) = DataCollectionService.coverageBreakdown(from: points)
        XCTAssertEqual(s, 50, accuracy: 0.01)
        XCTAssertEqual(m, 50, accuracy: 0.01)
        XCTAssertEqual(w, 0, accuracy: 0.01)
    }

    // MARK: - speedDeficit

    func testSpeedDeficitZeroPromised() {
        XCTAssertEqual(DataCollectionService.speedDeficit(measured: 50, promised: 0), 0)
    }

    func testSpeedDeficitNoDeficit() {
        XCTAssertEqual(DataCollectionService.speedDeficit(measured: 100, promised: 100), 0, accuracy: 0.01)
    }

    func testSpeedDeficitHalf() {
        XCTAssertEqual(DataCollectionService.speedDeficit(measured: 50, promised: 100), 50, accuracy: 0.01)
    }

    func testSpeedDeficitExceedsPromised() {
        // Negative deficit means measured > promised
        XCTAssertEqual(DataCollectionService.speedDeficit(measured: 120, promised: 100), -20, accuracy: 0.01)
    }

    // MARK: - coverageLabel

    func testCoverageLabelExcellent() {
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 80, moderate: 10, weak: 10), "Excellent")
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 70, moderate: 20, weak: 10), "Excellent")
    }

    func testCoverageLabelGood() {
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 50, moderate: 30, weak: 20), "Good")
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 60, moderate: 30, weak: 10), "Good")
    }

    func testCoverageLabelModerate() {
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 30, moderate: 40, weak: 30), "Moderate")
    }

    func testCoverageLabelPoor() {
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 10, moderate: 20, weak: 70), "Poor")
    }

    func testCoverageLabelWeak() {
        XCTAssertEqual(DataCollectionService.coverageLabel(strong: 20, moderate: 30, weak: 40), "Weak")
    }
}
