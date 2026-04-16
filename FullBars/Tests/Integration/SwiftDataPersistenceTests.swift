import XCTest
import SwiftData
@testable import FullBars

/// SwiftData integration tests — ensure our @Model types round-trip through
/// an in-memory ModelContainer and relationships/queries behave as expected.
final class SwiftDataPersistenceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([HomeConfiguration.self, Room.self, Doorway.self, DevicePlacement.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - HomeConfiguration

    func testInsertAndFetchHome() throws {
        let home = HomeConfiguration(name: "Test Home", squareFootage: 2000, numberOfFloors: 2)
        context.insert(home)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<HomeConfiguration>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Home")
        XCTAssertEqual(fetched.first?.squareFootage, 2000)
    }

    func testHomeSupportsMultipleInstances() throws {
        context.insert(HomeConfiguration(name: "Primary"))
        context.insert(HomeConfiguration(name: "Rental"))
        context.insert(HomeConfiguration(name: "Lake House"))
        try context.save()

        let all = try context.fetch(FetchDescriptor<HomeConfiguration>())
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(Set(all.map { $0.name }), ["Primary", "Rental", "Lake House"])
    }

    // MARK: - Room

    func testRoomPersistsAndLinksToHomeByUUID() throws {
        let home = HomeConfiguration(name: "H")
        context.insert(home)

        let room = Room(homeId: home.id, roomTypeRaw: RoomType.kitchen.rawValue)
        context.insert(room)
        try context.save()

        let rooms = try context.fetch(FetchDescriptor<Room>())
        XCTAssertEqual(rooms.count, 1)
        XCTAssertEqual(rooms.first?.homeId, home.id)
        XCTAssertEqual(rooms.first?.roomType, .kitchen)
    }

    func testRoomCornersSurviveSaveReload() throws {
        let home = HomeConfiguration()
        context.insert(home)
        let room = Room(homeId: home.id)
        room.corners = [(0, 0), (4, 0), (4, 3), (0, 3)]
        context.insert(room)
        try context.save()

        // Re-fetch through a fresh context to force a reload
        let freshContext = ModelContext(container)
        let reloaded = try freshContext.fetch(FetchDescriptor<Room>()).first
        XCTAssertEqual(reloaded?.corners.count, 4)
        XCTAssertEqual(reloaded?.approximateAreaSquareMeters ?? 0, 12, accuracy: 0.001)
    }

    func testRoomPaintedCellsSurviveReload() throws {
        let home = HomeConfiguration()
        context.insert(home)
        let room = Room(homeId: home.id)
        room.paintedCells = [(0, 0), (1, 1), (2, 2), (3, 3)]
        context.insert(room)
        try context.save()

        let freshContext = ModelContext(container)
        let reloaded = try freshContext.fetch(FetchDescriptor<Room>()).first
        XCTAssertEqual(reloaded?.paintedCells.count, 4)
    }

    // MARK: - Query filtering

    func testFetchRoomsForSpecificHome() throws {
        let h1 = HomeConfiguration(name: "A")
        let h2 = HomeConfiguration(name: "B")
        context.insert(h1)
        context.insert(h2)
        context.insert(Room(homeId: h1.id, roomTypeRaw: RoomType.bedroom.rawValue))
        context.insert(Room(homeId: h1.id, roomTypeRaw: RoomType.kitchen.rawValue))
        context.insert(Room(homeId: h2.id, roomTypeRaw: RoomType.office.rawValue))
        try context.save()

        let h1Id = h1.id
        let descriptor = FetchDescriptor<Room>(predicate: #Predicate { $0.homeId == h1Id })
        let h1Rooms = try context.fetch(descriptor)
        XCTAssertEqual(h1Rooms.count, 2)
    }

    func testDeleteRoomRemovesFromStore() throws {
        let home = HomeConfiguration()
        context.insert(home)
        let room = Room(homeId: home.id)
        context.insert(room)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Room>()).count, 1)

        context.delete(room)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Room>()).count, 0)
    }

    // MARK: - Rescan history end-to-end (through SwiftData)

    func testVisibleRoomsDedupsAcrossPersistedScans() throws {
        let home = HomeConfiguration()
        context.insert(home)

        // Three scans of the same "Kitchen" slot
        for offset in 0..<3 {
            let r = Room(
                homeId: home.id,
                createdAt: Date(timeIntervalSince1970: 1_000_000 + TimeInterval(offset * 100)),
                roomTypeRaw: RoomType.kitchen.rawValue,
                customName: "Kitchen",
                floorIndex: 0
            )
            context.insert(r)
        }
        try context.save()

        let allRooms = try context.fetch(FetchDescriptor<Room>())
        XCTAssertEqual(allRooms.count, 3)

        let freeVisible = RescanHistory.visibleRooms(for: allRooms, isPro: false)
        XCTAssertEqual(freeVisible.count, 1, "Free user should see only 1 deduped scan")

        let proVisible = RescanHistory.visibleRooms(for: allRooms, isPro: true)
        XCTAssertEqual(proVisible.count, 3, "Pro user should see all 3 scans")
    }
}
