import XCTest
import SwiftData
@testable import FullBars

/// Integration tests for data that's captured during a walkthrough session:
/// heatmap points, speed test results, and the computed SpaceGrade.
///
/// These exercise the full path: insert → save → fetch with predicate →
/// round-trip JSON (for roomGrades), catching regressions where a schema
/// change breaks persistence even when unit-level code still compiles.
final class SpeedTestAndGradePersistenceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            HeatmapPoint.self,
            SpeedTestResult.self,
            SpaceGrade.self,
            WalkthroughSession.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - HeatmapPoint

    func testHeatmapPointsPersistWithSessionID() throws {
        let session = UUID()
        for i in 0..<5 {
            context.insert(HeatmapPoint(
                x: Double(i), y: 0, z: 0,
                signalStrength: -60 - i,
                latency: 20,
                downloadSpeed: 100,
                sessionId: session
            ))
        }
        try context.save()

        let descriptor = FetchDescriptor<HeatmapPoint>(
            predicate: #Predicate { $0.sessionId == session }
        )
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 5)
    }

    func testHeatmapPointsFromTwoSessionsAreIsolated() throws {
        let a = UUID(), b = UUID()
        for _ in 0..<3 { context.insert(HeatmapPoint(sessionId: a)) }
        for _ in 0..<7 { context.insert(HeatmapPoint(sessionId: b)) }
        try context.save()

        let fetchA = FetchDescriptor<HeatmapPoint>(predicate: #Predicate { $0.sessionId == a })
        let fetchB = FetchDescriptor<HeatmapPoint>(predicate: #Predicate { $0.sessionId == b })
        XCTAssertEqual(try context.fetch(fetchA).count, 3)
        XCTAssertEqual(try context.fetch(fetchB).count, 7)
    }

    // MARK: - SpeedTestResult

    func testSpeedTestResultRoundTrips() throws {
        let r = SpeedTestResult(
            downloadSpeed: 142.5,
            uploadSpeed: 22.1,
            latency: 18,
            jitter: 3.4,
            packetLoss: 0.1,
            serverName: "Chicago",
            serverLocation: "US"
        )
        context.insert(r)
        try context.save()

        let all = try context.fetch(FetchDescriptor<SpeedTestResult>())
        XCTAssertEqual(all.count, 1)
        let got = try XCTUnwrap(all.first)
        XCTAssertEqual(got.downloadSpeed, 142.5, accuracy: 0.001)
        XCTAssertEqual(got.serverName, "Chicago")
    }

    func testSpeedTestHistoryOrderedByTimestamp() throws {
        let now = Date()
        context.insert(SpeedTestResult(timestamp: now.addingTimeInterval(-3600), downloadSpeed: 50))
        context.insert(SpeedTestResult(timestamp: now.addingTimeInterval(-60),   downloadSpeed: 120))
        context.insert(SpeedTestResult(timestamp: now,                           downloadSpeed: 140))
        try context.save()

        let desc = FetchDescriptor<SpeedTestResult>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let all = try context.fetch(desc)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.first?.downloadSpeed, 140, "Most recent should be first")
        XCTAssertEqual(all.last?.downloadSpeed, 50)
    }

    // MARK: - SpaceGrade

    func testSpaceGradePersistsAndReconstructsGradeLetter() throws {
        let g = SpaceGrade(
            sessionId: UUID(),
            overallScore: 83,
            signalCoverageScore: 85,
            speedPerformanceScore: 90,
            reliabilityScore: 75,
            latencyScore: 80,
            interferenceScore: 90,
            pointCount: 42,
            durationSeconds: 300
        )
        context.insert(g)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<SpaceGrade>()).first)
        XCTAssertEqual(fetched.grade, .B)
        XCTAssertEqual(fetched.categoryScores.count, 5)
        XCTAssertEqual(fetched.categoryScores.map(\.weight).reduce(0, +), 1.0, accuracy: 0.001)
    }

    func testRoomGradesJSONRoundTrip() throws {
        let rooms = [
            RoomGrade(name: "Kitchen", score: 88, pointCount: 12, averageSignal: -58, averageLatency: 22),
            RoomGrade(name: "Basement", score: 55, pointCount: 9, averageSignal: -82, averageLatency: 60),
        ]
        let data = try JSONEncoder().encode(rooms)
        let g = SpaceGrade(roomGradesJSON: data)
        context.insert(g)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<SpaceGrade>()).first)
        XCTAssertEqual(fetched.roomGrades.count, 2)
        XCTAssertEqual(fetched.roomGrades.first(where: { $0.name == "Basement" })?.grade, .F)
    }

    // MARK: - Walkthrough + grade linkage

    func testWalkthroughSessionLinksToGradeByID() throws {
        let sessionID = UUID()
        let grade = SpaceGrade(sessionId: sessionID, overallScore: 72)
        context.insert(grade)

        let session = WalkthroughSession(
            durationSeconds: 240,
            pointCount: 30,
            gradeId: grade.id,
            minX: -1, maxX: 5, minY: -1, maxY: 4
        )
        context.insert(session)
        try context.save()

        let gradeId = grade.id
        let gdesc = FetchDescriptor<SpaceGrade>(
            predicate: #Predicate { $0.id == gradeId }
        )
        let fetchedGrade = try XCTUnwrap(try context.fetch(gdesc).first)
        XCTAssertEqual(fetchedGrade.overallScore, 72)
        XCTAssertEqual(fetchedGrade.grade, .C)
    }
}
