import XCTest
@testable import FullBars

final class HomeConfigurationTests: XCTestCase {

    // MARK: - floorLabels JSON round-trip

    func testFloorLabelsDecodeFromJSON() {
        let home = HomeConfiguration(numberOfFloors: 3, floorLabelsJSON: "[\"Basement\",\"Main\",\"Upstairs\"]")
        XCTAssertEqual(home.floorLabels, ["Basement", "Main", "Upstairs"])
    }

    func testFloorLabelsSetterEncodesToJSON() {
        let home = HomeConfiguration(numberOfFloors: 2)
        home.floorLabels = ["Ground", "Loft"]
        XCTAssertTrue(home.floorLabelsJSON.contains("Ground"))
        XCTAssertTrue(home.floorLabelsJSON.contains("Loft"))
        XCTAssertEqual(home.floorLabels, ["Ground", "Loft"])
    }

    func testFloorLabelsFallsBackWhenJSONInvalid() {
        let home = HomeConfiguration(numberOfFloors: 2, floorLabelsJSON: "not-json")
        XCTAssertEqual(home.floorLabels.count, 2)
        XCTAssertEqual(home.floorLabels.first, "Main")
    }

    // MARK: - defaultFloorLabels

    func testDefaultFloorLabels() {
        XCTAssertEqual(HomeConfiguration.defaultFloorLabels(for: 1), ["Main"])
        XCTAssertEqual(HomeConfiguration.defaultFloorLabels(for: 2), ["Main", "Upstairs"])
        XCTAssertEqual(HomeConfiguration.defaultFloorLabels(for: 3), ["Basement", "Main", "Upstairs"])
        XCTAssertEqual(HomeConfiguration.defaultFloorLabels(for: 4), ["Basement", "Main", "Second", "Third"])
        XCTAssertEqual(HomeConfiguration.defaultFloorLabels(for: 6).count, 6)
    }

    // MARK: - Defaults

    func testDefaultInitializerSetsReasonableValues() {
        let h = HomeConfiguration()
        XCTAssertEqual(h.name, "Home")
        XCTAssertEqual(h.numberOfFloors, 1)
        XCTAssertEqual(h.numberOfPeople, 2)
        XCTAssertFalse(h.hasMeshNetwork)
        XCTAssertEqual(h.meshNodeCount, 0)
        XCTAssertEqual(h.ispPromisedDownloadMbps, 0)
        XCTAssertFalse(h.dataCollectionOptIn)
    }
}
