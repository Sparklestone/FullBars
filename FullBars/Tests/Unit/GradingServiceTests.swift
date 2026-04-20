import XCTest
@testable import FullBars

/// Unit tests for GradingService — pure-function scoring logic.
/// These are the tests most likely to catch regressions in the grade thresholds,
/// since the algorithm is weighted and small changes cascade.
final class GradingServiceTests: XCTestCase {

    // MARK: - Helpers

    private func point(signal: Int, latency: Double = 30, download: Double = 100, floor: Int = 0, x: Float = 0, z: Float = 0) -> HeatmapPoint {
        HeatmapPoint(
            x: x, y: 0, z: z,
            signalStrength: signal,
            latency: latency,
            downloadSpeed: download,
            floorIndex: floor
        )
    }

    private let session = UUID()

    // MARK: - Empty input

    func testEmptyPointsProducesZeroGrade() {
        let g = GradingService.grade(points: [], sessionId: session, durationSeconds: 0)
        XCTAssertEqual(g.overallScore, 0)
        XCTAssertEqual(g.pointCount, 0)
        XCTAssertEqual(g.grade, .F)
    }

    // MARK: - Signal coverage

    func testStrongSignalEverywhereYieldsAOrB() {
        // All points strong (-50 dBm), fast, low latency — should be near the top.
        let pts = (0..<30).map { _ in point(signal: -50) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 60)
        XCTAssertGreaterThanOrEqual(g.overallScore, 85, "Strong signal + fast + low latency should be B or better")
        XCTAssertTrue([.A, .B].contains(g.grade))
    }

    func testAllDeadSignalCrushesScore() {
        // All points -95 dBm — weak spot penalty should apply.
        let pts = (0..<20).map { i in point(signal: -95, x: Float(i) * 0.2, z: 0) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 60)
        XCTAssertLessThan(g.signalCoverageScore, 20)
        // Overall drops to a failing grade (D or worse) even though other
        // categories default to neutral when their inputs are missing.
        XCTAssertLessThan(g.overallScore, 70, "All-dead signal should not reach a passing C")
    }

    // MARK: - Speed performance

    func testSpeedCategoryCaps() {
        let fast = (0..<10).map { _ in point(signal: -50, download: 250) }
        let slow = (0..<10).map { _ in point(signal: -50, download: 5) }
        let gFast = GradingService.grade(points: fast, sessionId: session, durationSeconds: 30)
        let gSlow = GradingService.grade(points: slow, sessionId: session, durationSeconds: 30)
        XCTAssertEqual(gFast.speedPerformanceScore, 100, accuracy: 0.1)
        XCTAssertLessThan(gSlow.speedPerformanceScore, 30)
    }

    func testMissingSpeedDoesNotZeroScore() {
        // When no speed samples are present the service returns a neutral 70.
        let pts = (0..<5).map { _ in point(signal: -55, download: 0) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 15)
        XCTAssertEqual(g.speedPerformanceScore, 70, accuracy: 0.1)
    }

    // MARK: - Reliability (jitter + packet loss proxy)

    func testHighJitterPenalizesReliability() {
        let latencies: [Double] = [10, 200, 15, 180, 20, 250, 5, 210]
        let pts = latencies.map { point(signal: -55, latency: $0) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 20)
        XCTAssertLessThan(g.reliabilityScore, 80)
    }

    func testPacketLossProxyReducesReliability() {
        // latency == -1 treated as a failed measurement
        var pts = (0..<10).map { _ in point(signal: -55, latency: 30) }
        pts.append(contentsOf: (0..<5).map { _ in point(signal: -55, latency: -1) })
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 20)
        // 5 / 15 ≈ 33% loss — should drop reliability substantially
        XCTAssertLessThan(g.reliabilityScore, 75)
    }

    // MARK: - Latency scoring

    func testExcellentLatencyMaxesCategory() {
        let pts = (0..<5).map { _ in point(signal: -55, latency: 12) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 10)
        XCTAssertEqual(g.latencyScore, 100, accuracy: 0.1)
    }

    func testAwfulLatencyCrushesCategory() {
        let pts = (0..<5).map { _ in point(signal: -55, latency: 400) }
        let g = GradingService.grade(points: pts, sessionId: session, durationSeconds: 10)
        XCTAssertLessThanOrEqual(g.latencyScore, 40)
    }

    // MARK: - Interference (BLE)

    func testBLEInterferenceBandings() {
        let pts = (0..<5).map { _ in point(signal: -55) }
        let clean = GradingService.grade(points: pts, bleDeviceCount: 2, sessionId: session, durationSeconds: 10)
        let crowded = GradingService.grade(points: pts, bleDeviceCount: 40, sessionId: session, durationSeconds: 10)
        XCTAssertEqual(clean.interferenceScore, 100, accuracy: 0.1)
        XCTAssertEqual(crowded.interferenceScore, 40, accuracy: 0.1)
    }

    // MARK: - Score bounds

    func testOverallScoreNeverExceedsBounds() {
        // Throw a mix at it and make sure nothing clamps out of [0, 100].
        let pts: [HeatmapPoint] = [
            point(signal: -40, latency: 5, download: 500),
            point(signal: -90, latency: 900, download: 0.1),
            point(signal: -60, latency: 40, download: 60)
        ]
        let g = GradingService.grade(points: pts, bleDeviceCount: 100, sessionId: session, durationSeconds: 10)
        XCTAssertGreaterThanOrEqual(g.overallScore, 0)
        XCTAssertLessThanOrEqual(g.overallScore, 100)
        for cat in g.categoryScores {
            XCTAssertGreaterThanOrEqual(cat.score, 0, "Category \(cat.category) went below 0")
            XCTAssertLessThanOrEqual(cat.score, 100, "Category \(cat.category) went above 100")
        }
    }

    // MARK: - Grade letter mapping

    func testGradeLetterBoundaries() {
        XCTAssertEqual(GradeLetter.from(score: 100), .A)
        XCTAssertEqual(GradeLetter.from(score: 90),  .A)
        XCTAssertEqual(GradeLetter.from(score: 89.9), .B)
        XCTAssertEqual(GradeLetter.from(score: 80),  .B)
        XCTAssertEqual(GradeLetter.from(score: 79.9), .C)
        XCTAssertEqual(GradeLetter.from(score: 70),  .C)
        XCTAssertEqual(GradeLetter.from(score: 69.9), .D)
        XCTAssertEqual(GradeLetter.from(score: 60),  .D)
        XCTAssertEqual(GradeLetter.from(score: 59.9), .F)
        XCTAssertEqual(GradeLetter.from(score: 0),   .F)
    }
}
