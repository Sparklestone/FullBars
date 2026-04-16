import Foundation
import SwiftData

/// Represents a home or property being scanned. Supports multi-home (Pro feature)
/// but free tier is limited to one active home.
@Model
final class HomeConfiguration {
    var id: UUID
    var createdAt: Date
    var lastScannedAt: Date?

    // Basic info
    var name: String                      // "Home", "Rental #1", "Lake House"
    var dwellingType: String              // "House", "Apartment", "Condo", "Townhouse", "Other"
    var squareFootage: Int                // Total sq ft
    var numberOfFloors: Int
    var floorLabelsJSON: String           // JSON-encoded [String] like ["Basement", "Main", "Upstairs"]
    var numberOfPeople: Int

    // Mesh topology
    var hasMeshNetwork: Bool
    var meshNodeCount: Int                // Number of mesh nodes (not including router)

    // ISP / plan — the key data point for the "you're getting X% of your plan" insight
    var ispName: String                   // "Xfinity", "Verizon Fios", "Spectrum", etc.
    var ispPromisedDownloadMbps: Double   // e.g. 500, 1000
    var ispPromisedUploadMbps: Double     // Often much lower on cable; 0 if unknown
    var zipCode: String                   // For ISP recommendations later

    // User options
    var dataCollectionOptIn: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        lastScannedAt: Date? = nil,
        name: String = "Home",
        dwellingType: String = "House",
        squareFootage: Int = 1500,
        numberOfFloors: Int = 1,
        floorLabelsJSON: String = "[\"Main\"]",
        numberOfPeople: Int = 2,
        hasMeshNetwork: Bool = false,
        meshNodeCount: Int = 0,
        ispName: String = "",
        ispPromisedDownloadMbps: Double = 0,
        ispPromisedUploadMbps: Double = 0,
        zipCode: String = "",
        dataCollectionOptIn: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastScannedAt = lastScannedAt
        self.name = name
        self.dwellingType = dwellingType
        self.squareFootage = squareFootage
        self.numberOfFloors = numberOfFloors
        self.floorLabelsJSON = floorLabelsJSON
        self.numberOfPeople = numberOfPeople
        self.hasMeshNetwork = hasMeshNetwork
        self.meshNodeCount = meshNodeCount
        self.ispName = ispName
        self.ispPromisedDownloadMbps = ispPromisedDownloadMbps
        self.ispPromisedUploadMbps = ispPromisedUploadMbps
        self.zipCode = zipCode
        self.dataCollectionOptIn = dataCollectionOptIn
    }

    // MARK: - Floor label helpers

    var floorLabels: [String] {
        get {
            guard let data = floorLabelsJSON.data(using: .utf8),
                  let labels = try? JSONDecoder().decode([String].self, from: data) else {
                return (0..<numberOfFloors).map { $0 == 0 ? "Main" : "Floor \($0 + 1)" }
            }
            return labels
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                floorLabelsJSON = json
            }
        }
    }

    // MARK: - Default floor labels for given floor count

    static func defaultFloorLabels(for floorCount: Int) -> [String] {
        switch floorCount {
        case 1: return ["Main"]
        case 2: return ["Main", "Upstairs"]
        case 3: return ["Basement", "Main", "Upstairs"]
        case 4: return ["Basement", "Main", "Second", "Third"]
        default: return (0..<floorCount).map { "Floor \($0 + 1)" }
        }
    }
}

// NOTE: `DwellingType` is defined in UserProfile.swift and shared with this model.
