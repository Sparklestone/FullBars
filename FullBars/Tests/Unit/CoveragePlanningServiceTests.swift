import XCTest
@testable import FullBars

/// Unit tests for CoveragePlanningService — dead-zone clustering and
/// router/mesh placement heuristics. These are high-value tests: the
/// clustering logic is geometric and easy to silently break.
final class CoveragePlanningServiceTests: XCTestCase {

    private func point(signal: Int, x: Float, z: Float, floor: Int = 0, room: String? = nil) -> HeatmapPoint {
        HeatmapPoint(x: x, y: 0, z: z, signalStrength: signal, latency: 30, downloadSpeed: 80, roomName: room, floorIndex: floor)
    }

    // MARK: - Empty

    func testAnalyzeWithNoPointsReturnsEmptyResult() {
        let r = CoveragePlanningService.analyze(points: [])
        XCTAssertTrue(r.deadZones.isEmpty)
        XCTAssertTrue(r.meshRecommendations.isEmpty)
        XCTAssertEqual(r.coveragePercentage, 0)
        XCTAssertNil(r.estimatedRouterPosition)
    }

    // MARK: - Dead-zone detection

    func testStrongSignalProducesNoDeadZones() {
        let pts = (0..<20).map { i in point(signal: -50, x: Float(i) * 1.0, z: 0) }
        let r = CoveragePlanningService.analyze(points: pts)
        XCTAssertTrue(r.deadZones.isEmpty)
    }

    func testCriticalDeadZoneDetected() {
        // Cluster of very-weak points in one corner.
        let weak = (0..<6).map { i in point(signal: -90, x: Float(i) * 0.3, z: 0.2) }
        let strong = (0..<10).map { i in point(signal: -50, x: 15 + Float(i), z: 15) }
        let r = CoveragePlanningService.analyze(points: weak + strong)
        XCTAssertFalse(r.deadZones.isEmpty, "Expected a dead zone from weak cluster")
        XCTAssertTrue(r.deadZones.contains { $0.severity == .critical })
    }

    func testNearbyWeakPointsClusterIntoSingleZone() {
        // Six weak points within ~1m of each other should become one dead zone,
        // not six. This is a guardrail against regressing the clustering step.
        let pts = [
            point(signal: -88, x: 0.0, z: 0.0),
            point(signal: -89, x: 0.2, z: 0.1),
            point(signal: -90, x: 0.4, z: 0.0),
            point(signal: -87, x: 0.1, z: 0.3),
            point(signal: -86, x: 0.3, z: 0.2),
            point(signal: -91, x: 0.0, z: 0.4),
        ]
        let zones = CoveragePlanningService.detectDeadZones(points: pts)
        XCTAssertEqual(zones.count, 1, "Tightly-grouped weak points should collapse into a single zone")
    }

    func testFarApartWeakPointsProduceMultipleZones() {
        // Two clusters separated by > clusterRadius should produce two zones.
        let a = (0..<3).map { i in point(signal: -90, x: Float(i) * 0.2, z: 0.1) }
        let b = (0..<3).map { i in point(signal: -90, x: 20 + Float(i) * 0.2, z: 20) }
        let zones = CoveragePlanningService.detectDeadZones(points: a + b)
        XCTAssertGreaterThanOrEqual(zones.count, 2)
    }

    func testDeadZoneCarriesRoomNameWhenAvailable() {
        let pts = (0..<4).map { i in point(signal: -88, x: Float(i) * 0.2, z: 0, room: "Basement") }
        let zones = CoveragePlanningService.detectDeadZones(points: pts)
        XCTAssertEqual(zones.first?.roomName, "Basement")
    }

    // MARK: - Coverage percentage

    func testCoveragePercentageAllGood() {
        let pts = (0..<20).map { _ in point(signal: -50, x: 0, z: 0) }
        let r = CoveragePlanningService.analyze(points: pts)
        XCTAssertEqual(r.coveragePercentage, 100, accuracy: 0.1)
    }

    func testCoveragePercentageHalfBad() {
        // 10 good, 10 dead → ~50%
        let good = (0..<10).map { i in point(signal: -55, x: Float(i), z: 0) }
        let dead = (0..<10).map { i in point(signal: -90, x: Float(i) + 50, z: 50) }
        let r = CoveragePlanningService.analyze(points: good + dead)
        XCTAssertLessThan(r.coveragePercentage, 80)
        XCTAssertGreaterThan(r.coveragePercentage, 20)
    }

    // MARK: - Multi-floor

    func testFloorCountReflectsDistinctFloors() {
        let pts = [
            point(signal: -55, x: 0, z: 0, floor: 0),
            point(signal: -55, x: 1, z: 0, floor: 0),
            point(signal: -60, x: 0, z: 0, floor: 1),
            point(signal: -60, x: 0, z: 0, floor: 2),
        ]
        let r = CoveragePlanningService.analyze(points: pts)
        XCTAssertEqual(r.floorCount, 3)
    }
}
