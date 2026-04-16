import XCTest
@testable import FullBars

/// Unit tests for `Room` geometry helpers — shoelace area + painted coverage.
final class RoomGeometryTests: XCTestCase {

    private let homeId = UUID()

    private func room(corners: [(Float, Float)] = [],
                      painted: [(Int, Int)] = [],
                      gridRes: Float = 0.5) -> Room {
        let r = Room(homeId: homeId, paintGridResolutionMeters: gridRes)
        r.corners = corners
        r.paintedCells = painted
        return r
    }

    // MARK: - approximateAreaSquareMeters

    func testAreaIsZeroForFewerThanThreeCorners() {
        XCTAssertEqual(room(corners: []).approximateAreaSquareMeters, 0)
        XCTAssertEqual(room(corners: [(0, 0)]).approximateAreaSquareMeters, 0)
        XCTAssertEqual(room(corners: [(0, 0), (1, 0)]).approximateAreaSquareMeters, 0)
    }

    func testAreaOfUnitSquareIsOne() {
        let square: [(Float, Float)] = [(0, 0), (1, 0), (1, 1), (0, 1)]
        XCTAssertEqual(room(corners: square).approximateAreaSquareMeters, 1.0, accuracy: 0.001)
    }

    func testAreaOf10x5Rectangle() {
        let rect: [(Float, Float)] = [(0, 0), (10, 0), (10, 5), (0, 5)]
        XCTAssertEqual(room(corners: rect).approximateAreaSquareMeters, 50.0, accuracy: 0.001)
    }

    func testAreaOfRightTriangleIsHalfBaseTimesHeight() {
        let tri: [(Float, Float)] = [(0, 0), (4, 0), (0, 3)]
        XCTAssertEqual(room(corners: tri).approximateAreaSquareMeters, 6.0, accuracy: 0.001)
    }

    func testAreaIsRotationInvariant() {
        // Same unit square rotated around origin — area should still be 1
        let rotated: [(Float, Float)] = [
            (0, 0),
            (Float(cos(0.7)), Float(sin(0.7))),
            (Float(cos(0.7) - sin(0.7)), Float(sin(0.7) + cos(0.7))),
            (-Float(sin(0.7)), Float(cos(0.7)))
        ]
        XCTAssertEqual(room(corners: rotated).approximateAreaSquareMeters, 1.0, accuracy: 0.001)
    }

    func testAreaIsIndependentOfWindingDirection() {
        let cw: [(Float, Float)] = [(0, 0), (0, 1), (1, 1), (1, 0)]
        let ccw: [(Float, Float)] = [(0, 0), (1, 0), (1, 1), (0, 1)]
        XCTAssertEqual(
            room(corners: cw).approximateAreaSquareMeters,
            room(corners: ccw).approximateAreaSquareMeters,
            accuracy: 0.001
        )
    }

    // MARK: - paintedCoverageFraction

    func testCoverageIsZeroWhenAreaIsZero() {
        XCTAssertEqual(room(corners: [], painted: [(0, 0), (1, 1)]).paintedCoverageFraction, 0)
    }

    func testCoverageIsZeroWhenNothingPainted() {
        let r = room(corners: [(0, 0), (2, 0), (2, 2), (0, 2)], painted: [])
        XCTAssertEqual(r.paintedCoverageFraction, 0, accuracy: 0.001)
    }

    func testCoverageWithPartialPaint() {
        // 2x2 m room = 4 m². With 0.5m grid, a single cell = 0.25 m² → 6.25% coverage
        let r = room(
            corners: [(0, 0), (2, 0), (2, 2), (0, 2)],
            painted: [(0, 0)],
            gridRes: 0.5
        )
        XCTAssertEqual(r.paintedCoverageFraction, 0.0625, accuracy: 0.001)
    }

    func testCoverageIsClampedToOne() {
        // Tiny room, lots of painted cells → should clamp to 1.0
        let r = room(
            corners: [(0, 0), (1, 0), (1, 1), (0, 1)],   // 1 m²
            painted: (0..<100).flatMap { i in (0..<100).map { (i, $0) } },
            gridRes: 0.5                                   // 0.25 m² per cell
        )
        XCTAssertEqual(r.paintedCoverageFraction, 1.0, accuracy: 0.001)
    }

    // MARK: - corners / paintedCells JSON round-trip

    func testCornersRoundTripThroughJSON() {
        let r = Room(homeId: homeId)
        r.corners = [(1.5, 2.5), (-3, 0), (0, 0)]
        let decoded = r.corners
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(decoded[0].1, 2.5, accuracy: 0.0001)
        XCTAssertEqual(decoded[1].0, -3, accuracy: 0.0001)
    }

    func testPaintedCellsRoundTripThroughJSON() {
        let r = Room(homeId: homeId)
        r.paintedCells = [(0, 0), (1, 2), (-3, 5)]
        let decoded = r.paintedCells
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[2].0, -3)
        XCTAssertEqual(decoded[2].1, 5)
    }

    // MARK: - displayName

    func testDisplayNameUsesCustomWhenSet() {
        let r = Room(homeId: homeId, roomTypeRaw: RoomType.bedroom.rawValue, customName: "The Cave")
        XCTAssertEqual(r.displayName, "The Cave")
    }

    func testDisplayNameFallsBackToTypeLabel() {
        let r = Room(homeId: homeId, roomTypeRaw: RoomType.bedroom.rawValue, customName: nil)
        XCTAssertEqual(r.displayName, "Bedroom")
    }

    func testDisplayNameFallsBackWhenCustomIsEmpty() {
        let r = Room(homeId: homeId, roomTypeRaw: RoomType.kitchen.rawValue, customName: "")
        XCTAssertEqual(r.displayName, "Kitchen")
    }
}
