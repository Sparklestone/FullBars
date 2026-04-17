import XCTest
@testable import FullBars

/// Unit tests for GradeLetter, GradeCategoryScore, and RoomGrade value types.
final class GradeLetterTests: XCTestCase {

    // MARK: - GradeLetter.from(score:)

    func testScoreBoundaries() {
        XCTAssertEqual(GradeLetter.from(score: 100), .A)
        XCTAssertEqual(GradeLetter.from(score: 95),  .A)
        XCTAssertEqual(GradeLetter.from(score: 90),  .A)
        XCTAssertEqual(GradeLetter.from(score: 89.99), .B)
        XCTAssertEqual(GradeLetter.from(score: 85),  .B)
        XCTAssertEqual(GradeLetter.from(score: 80),  .B)
        XCTAssertEqual(GradeLetter.from(score: 79.99), .C)
        XCTAssertEqual(GradeLetter.from(score: 70),  .C)
        XCTAssertEqual(GradeLetter.from(score: 69.99), .D)
        XCTAssertEqual(GradeLetter.from(score: 60),  .D)
        XCTAssertEqual(GradeLetter.from(score: 59.99), .F)
        XCTAssertEqual(GradeLetter.from(score: 0),   .F)
    }

    func testNegativeScoreReturnsF() {
        XCTAssertEqual(GradeLetter.from(score: -10), .F)
    }

    // MARK: - GradeLetter display properties

    func testSummaryIsNonEmpty() {
        for letter in GradeLetter.allCases {
            XCTAssertFalse(letter.summary.isEmpty, "\(letter.rawValue).summary is empty")
        }
    }

    func testBasicDescriptionIsNonEmpty() {
        for letter in GradeLetter.allCases {
            XCTAssertFalse(letter.basicDescription.isEmpty, "\(letter.rawValue).basicDescription is empty")
        }
    }

    func testAllCasesPresent() {
        XCTAssertEqual(GradeLetter.allCases.count, 5)
    }

    // MARK: - GradeCategoryScore

    func testWeightedScore() {
        let cat = GradeCategoryScore(category: "Speed", score: 80, weight: 0.25, details: "test")
        XCTAssertEqual(cat.weightedScore, 20, accuracy: 0.001)
    }

    func testCategoryScoreId() {
        let cat = GradeCategoryScore(category: "Latency", score: 90, weight: 0.15, details: "")
        XCTAssertEqual(cat.id, "Latency")
    }

    // MARK: - RoomGrade

    func testRoomGradeDerivesLetterFromScore() {
        let room = RoomGrade(name: "Kitchen", score: 88, pointCount: 12, averageSignal: -58, averageLatency: 22)
        XCTAssertEqual(room.grade, .B)
        XCTAssertEqual(room.id, "Kitchen")
    }

    func testRoomGradeFailingScore() {
        let room = RoomGrade(name: "Garage", score: 35, pointCount: 5, averageSignal: -85, averageLatency: 200)
        XCTAssertEqual(room.grade, .F)
    }

    // MARK: - SpaceGrade computed properties

    func testSpaceGradeComputedGrade() {
        let sg = SpaceGrade(overallScore: 92)
        XCTAssertEqual(sg.grade, .A)
    }

    func testSpaceGradeCategoryScoresHaveCorrectWeights() {
        let sg = SpaceGrade(
            signalCoverageScore: 80,
            speedPerformanceScore: 90,
            reliabilityScore: 70,
            latencyScore: 85,
            interferenceScore: 95
        )
        let scores = sg.categoryScores
        XCTAssertEqual(scores.count, 5)
        let totalWeight = scores.map(\.weight).reduce(0, +)
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    func testSpaceGradeRoomGradesEmptyWhenNoJSON() {
        let sg = SpaceGrade()
        XCTAssertTrue(sg.roomGrades.isEmpty)
    }

    func testSpaceGradeRoomGradesDecodesJSON() throws {
        let rooms = [
            RoomGrade(name: "Office", score: 75, pointCount: 8, averageSignal: -62, averageLatency: 35)
        ]
        let data = try JSONEncoder().encode(rooms)
        let sg = SpaceGrade(roomGradesJSON: data)
        XCTAssertEqual(sg.roomGrades.count, 1)
        XCTAssertEqual(sg.roomGrades.first?.name, "Office")
        XCTAssertEqual(sg.roomGrades.first?.grade, .C)
    }

    func testSpaceGradeRoomGradesHandlesCorruptJSON() {
        let sg = SpaceGrade(roomGradesJSON: "not json".data(using: .utf8))
        XCTAssertTrue(sg.roomGrades.isEmpty, "Corrupt JSON should return empty array, not crash")
    }
}
