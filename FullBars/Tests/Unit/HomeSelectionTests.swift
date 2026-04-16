import XCTest
@testable import FullBars

/// Unit tests for `HomeSelection` — active home persistence + Pro gating.
final class HomeSelectionTests: XCTestCase {

    private let activeHomeIdKey = "activeHomeId"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: activeHomeIdKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: activeHomeIdKey)
        super.tearDown()
    }

    // MARK: - activeHome(from:)

    func testReturnsNilWhenNoHomes() {
        XCTAssertNil(HomeSelection.activeHome(from: []))
    }

    func testReturnsFirstHomeWhenNothingStored() {
        let a = HomeConfiguration(name: "A")
        let b = HomeConfiguration(name: "B")
        let active = HomeSelection.activeHome(from: [a, b])
        XCTAssertEqual(active?.id, a.id)
    }

    func testReturnsStoredHomeWhenIdMatches() {
        let a = HomeConfiguration(name: "A")
        let b = HomeConfiguration(name: "B")
        HomeSelection.setActive(b)

        let active = HomeSelection.activeHome(from: [a, b])
        XCTAssertEqual(active?.id, b.id, "Should return the stored home, not the first")
    }

    func testFallsBackToFirstWhenStoredIdNotInList() {
        let a = HomeConfiguration(name: "A")
        let stale = HomeConfiguration(name: "Deleted")
        HomeSelection.setActive(stale)

        let active = HomeSelection.activeHome(from: [a])
        XCTAssertEqual(active?.id, a.id, "Stale stored id should fall back to first")
    }

    func testFallsBackWhenStoredIdIsGarbage() {
        UserDefaults.standard.set("not-a-uuid", forKey: activeHomeIdKey)
        let a = HomeConfiguration(name: "A")
        XCTAssertEqual(HomeSelection.activeHome(from: [a])?.id, a.id)
    }

    // MARK: - setActive

    func testSetActivePersistsId() {
        let h = HomeConfiguration(name: "Lake House")
        HomeSelection.setActive(h)
        XCTAssertEqual(UserDefaults.standard.string(forKey: activeHomeIdKey), h.id.uuidString)
    }

    // MARK: - canAddAnotherHome

    func testFreeUserCanAddFirstHome() {
        XCTAssertTrue(HomeSelection.canAddAnotherHome(currentCount: 0, isPro: false))
    }

    func testFreeUserCannotAddSecondHome() {
        XCTAssertFalse(HomeSelection.canAddAnotherHome(currentCount: 1, isPro: false))
        XCTAssertFalse(HomeSelection.canAddAnotherHome(currentCount: 5, isPro: false))
    }

    func testProUserCanAlwaysAddHome() {
        XCTAssertTrue(HomeSelection.canAddAnotherHome(currentCount: 0, isPro: true))
        XCTAssertTrue(HomeSelection.canAddAnotherHome(currentCount: 1, isPro: true))
        XCTAssertTrue(HomeSelection.canAddAnotherHome(currentCount: 42, isPro: true))
    }
}
