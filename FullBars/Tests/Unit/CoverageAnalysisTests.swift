import XCTest
@testable import FullBars

/// Tests for CoverageAnalysisResult, FloorCoverageSummary, and
/// CoveragePlanningService.floorSummaries — the analysis layer above
/// raw dead-zone detection.
final class CoverageAnalysisTests: XCTestCase {

    private func point(signal: Int, x: Float = 0, z: Float = 0, floor: Int = 0, room: String? = nil, latency: Double = 20, download: Double = 80) -> HeatmapPoint {
        HeatmapPoint(x: x, y: 0, z: z, signalStrength: signal, latency: latency, downloadSpeed: download, roomName: room, floorIndex: floor)
    }

    // MARK: - CoverageAnalysisResult computed properties

    func testMeshNodesNeededCountsOnlyNodesAndExtenders() {
        let router = MeshPlacementRecommendation(
            x: 0, z: 0, floorIndex: 0, type: .primaryRouter,
            priority: 0, reason: "", expectedImpact: "", nearestRoomName: nil
        )
        let mesh = MeshPlacementRecommendation(
            x: 5, z: 5, floorIndex: 0, type: .meshNode,
            priority: 1, reason: "", expectedImpact: "", nearestRoomName: nil
        )
        let ext = MeshPlacementRecommendation(
            x: 10, z: 10, floorIndex: 0, type: .extender,
            priority: 2, reason: "", expectedImpact: "", nearestRoomName: nil
        )
        let result = CoverageAnalysisResult(
            deadZones: [],
            meshRecommendations: [router, mesh, ext],
            interferenceZones: [],
            coveragePercentage: 60,
            estimatedRouterPosition: CGPoint(x: 0, y: 0),
            floorCount: 1,
            timestamp: .now
        )
        XCTAssertEqual(result.meshNodesNeeded, 2, "Should count mesh + extender, not router")
    }

    func testAssessmentTiersBasedOnCoverage() {
        // ≥ 90% with no dead zones → Excellent
        let excellent = CoverageAnalysisResult(
            deadZones: [], meshRecommendations: [], interferenceZones: [],
            coveragePercentage: 95, estimatedRouterPosition: nil, floorCount: 1, timestamp: .now
        )
        XCTAssertTrue(excellent.overallAssessment.contains("Excellent"))

        // 50-70% → Moderate
        let moderate = CoverageAnalysisResult(
            deadZones: [
                DeadZone(centerX: 0, centerZ: 0, radius: 1, floorIndex: 0, averageSignal: -85, pointCount: 3, roomName: nil, severity: .severe),
                DeadZone(centerX: 5, centerZ: 5, radius: 1, floorIndex: 0, averageSignal: -82, pointCount: 2, roomName: nil, severity: .severe),
                DeadZone(centerX: 10, centerZ: 10, radius: 1, floorIndex: 0, averageSignal: -83, pointCount: 2, roomName: nil, severity: .severe),
            ],
            meshRecommendations: [
                MeshPlacementRecommendation(x: 0, z: 0, floorIndex: 0, type: .meshNode, priority: 1, reason: "", expectedImpact: "", nearestRoomName: nil),
            ],
            interferenceZones: [],
            coveragePercentage: 55, estimatedRouterPosition: nil, floorCount: 1, timestamp: .now
        )
        XCTAssertTrue(moderate.overallAssessment.contains("Moderate"))
    }

    // MARK: - Floor summaries

    func testFloorSummariesSingleFloor() {
        let pts = (0..<10).map { i in point(signal: -55, x: Float(i), floor: 0) }
        let summaries = CoveragePlanningService.floorSummaries(points: pts)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.floorLabel, "Ground Floor")
        XCTAssertEqual(summaries.first?.coveragePercentage, 100, accuracy: 0.1)
    }

    func testFloorSummariesMultipleFloors() {
        var pts: [HeatmapPoint] = []
        pts += (0..<5).map { i in point(signal: -55, x: Float(i), floor: 0) }
        pts += (0..<5).map { i in point(signal: -80, x: Float(i), floor: 1) }
        let summaries = CoveragePlanningService.floorSummaries(points: pts)
        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries[0].coveragePercentage > summaries[1].coveragePercentage)
    }

    func testFloorSummariesCustomLabels() {
        let pts = [point(signal: -55, floor: 0), point(signal: -60, floor: 1)]
        let summaries = CoveragePlanningService.floorSummaries(points: pts, floorLabels: ["Basement", "Main"])
        XCTAssertEqual(summaries.first?.floorLabel, "Basement")
        XCTAssertEqual(summaries.last?.floorLabel, "Main")
    }

    // MARK: - Router position estimation

    func testEstimateRouterPositionWeightsStrongestSignals() {
        // Strong cluster at (0,0), weak cluster at (10,10) — router estimate
        // should be near the strong cluster
        var pts: [HeatmapPoint] = []
        pts += (0..<10).map { _ in point(signal: -40, x: 0, z: 0) }
        pts += (0..<10).map { _ in point(signal: -85, x: 10, z: 10) }
        let pos = CoveragePlanningService.estimateRouterPosition(points: pts)
        XCTAssertNotNil(pos)
        if let p = pos {
            XCTAssertLessThan(p.x, 5, "Router should be estimated near the strong signals")
            XCTAssertLessThan(p.y, 5)
        }
    }

    func testEstimateRouterPositionEmptyReturnsNil() {
        let pos = CoveragePlanningService.estimateRouterPosition(points: [])
        XCTAssertNil(pos)
    }

    // MARK: - Coverage percentage

    func testCoveragePercentageEmpty() {
        XCTAssertEqual(CoveragePlanningService.calculateCoveragePercentage(points: []), 0)
    }

    func testCoveragePercentageMixed() {
        let pts = [
            point(signal: -50), // good
            point(signal: -55), // good
            point(signal: -80), // bad
            point(signal: -90), // bad
        ]
        XCTAssertEqual(CoveragePlanningService.calculateCoveragePercentage(points: pts), 50, accuracy: 0.1)
    }
}
