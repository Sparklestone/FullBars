import XCTest
@testable import FullBars

/// Unit tests for `RescanHistory` — dedup + per-slot history logic.
/// These are the rules that gate what Free vs Pro users see on the results list.
final class RescanHistoryTests: XCTestCase {

    private let homeId = UUID()

    private func makeRoom(
        type: RoomType = .livingRoom,
        name: String? = nil,
        floor: Int = 0,
        createdOffset: TimeInterval = 0
    ) -> Room {
        Room(
            homeId: homeId,
            createdAt: Date(timeIntervalSince1970: 1_000_000 + createdOffset),
            roomTypeRaw: type.rawValue,
            customName: name,
            floorIndex: floor
        )
    }

    // MARK: - visibleRooms(for:isPro:)

    func testProSeesAllScansEvenDuplicates() {
        let r1 = makeRoom(type: .bedroom, createdOffset: 0)
        let r2 = makeRoom(type: .bedroom, createdOffset: 100)
        let r3 = makeRoom(type: .bedroom, createdOffset: 200)

        let visible = RescanHistory.visibleRooms(for: [r1, r2, r3], isPro: true)
        XCTAssertEqual(visible.count, 3, "Pro users should see every scan")
        XCTAssertEqual(visible.map { $0.createdAt }, [r3.createdAt, r2.createdAt, r1.createdAt],
                       "Results should be sorted newest-first")
    }

    func testFreeUserSeesOnlyMostRecentPerSlot() {
        let oldest = makeRoom(type: .bedroom, createdOffset: 0)
        let middle = makeRoom(type: .bedroom, createdOffset: 100)
        let newest = makeRoom(type: .bedroom, createdOffset: 200)

        let visible = RescanHistory.visibleRooms(for: [oldest, middle, newest], isPro: false)
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.createdAt, newest.createdAt)
    }

    func testFreeUserSeesDistinctRoomsSeparately() {
        let bedroom = makeRoom(type: .bedroom, createdOffset: 0)
        let kitchen = makeRoom(type: .kitchen, createdOffset: 50)
        let office = makeRoom(type: .office, createdOffset: 100)

        let visible = RescanHistory.visibleRooms(for: [bedroom, kitchen, office], isPro: false)
        XCTAssertEqual(visible.count, 3)
    }

    func testDedupDifferentiatesByCustomName() {
        // Two "Bedroom" scans with different custom names = different slots
        let master = makeRoom(type: .bedroom, name: "Master", createdOffset: 0)
        let guest = makeRoom(type: .bedroom, name: "Guest", createdOffset: 100)

        let visible = RescanHistory.visibleRooms(for: [master, guest], isPro: false)
        XCTAssertEqual(visible.count, 2)
    }

    func testDedupIsCaseInsensitiveOnName() {
        // "master" and "MASTER" should collapse to one slot
        let a = makeRoom(type: .bedroom, name: "master", createdOffset: 0)
        let b = makeRoom(type: .bedroom, name: "MASTER", createdOffset: 100)

        let visible = RescanHistory.visibleRooms(for: [a, b], isPro: false)
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.createdAt, b.createdAt)
    }

    func testDedupTreatsNilAndEmptyNameTheSame() {
        let nilName = makeRoom(type: .kitchen, name: nil, createdOffset: 0)
        let emptyName = makeRoom(type: .kitchen, name: "", createdOffset: 100)

        let visible = RescanHistory.visibleRooms(for: [nilName, emptyName], isPro: false)
        XCTAssertEqual(visible.count, 1, "nil and \"\" should be treated as the same slot")
    }

    func testDedupDifferentiatesByFloor() {
        // Same room type + name on different floors = different slots
        let ground = makeRoom(type: .bedroom, name: "Main", floor: 0, createdOffset: 0)
        let upstairs = makeRoom(type: .bedroom, name: "Main", floor: 1, createdOffset: 100)

        let visible = RescanHistory.visibleRooms(for: [ground, upstairs], isPro: false)
        XCTAssertEqual(visible.count, 2)
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertTrue(RescanHistory.visibleRooms(for: [], isPro: false).isEmpty)
        XCTAssertTrue(RescanHistory.visibleRooms(for: [], isPro: true).isEmpty)
    }

    // MARK: - history(forSlotMatching:in:)

    func testHistoryReturnsAllScansForSlot() {
        let target = makeRoom(type: .kitchen, name: "Kitchen", createdOffset: 0)
        let sameSlotLater = makeRoom(type: .kitchen, name: "Kitchen", createdOffset: 100)
        let otherRoom = makeRoom(type: .office, name: "Office", createdOffset: 50)

        let history = RescanHistory.history(
            forSlotMatching: target,
            in: [target, sameSlotLater, otherRoom]
        )
        XCTAssertEqual(history.count, 2)
        // newest first
        XCTAssertEqual(history.first?.createdAt, sameSlotLater.createdAt)
        XCTAssertEqual(history.last?.createdAt, target.createdAt)
    }

    func testHistoryForUnmatchedSlotIsEmpty() {
        let target = makeRoom(type: .garage, createdOffset: 0)
        let unrelated = makeRoom(type: .bedroom, createdOffset: 100)

        let history = RescanHistory.history(forSlotMatching: target, in: [unrelated])
        XCTAssertTrue(history.isEmpty)
    }
}
