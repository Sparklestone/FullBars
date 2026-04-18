import Foundation
import SwiftData

// MARK: - Dwelling Type

enum DwellingType: String, CaseIterable, Codable {
    case house = "House"
    case apartment = "Apartment"
    case condo = "Condo"
    case townhouse = "Townhouse"
    case rentalUnit = "Rental Unit"
    case commercial = "Commercial Space"
    case other = "Other"

    var icon: String {
        switch self {
        case .house: return "house.fill"
        case .apartment: return "building.2.fill"
        case .condo: return "building.fill"
        case .townhouse: return "house.and.flag.fill"
        case .rentalUnit: return "key.fill"
        case .commercial: return "storefront.fill"
        case .other: return "questionmark.square.fill"
        }
    }
}

// MARK: - Square Footage Range

enum SquareFootageRange: String, CaseIterable, Codable {
    case small = "Under 800 sq ft"
    case medium = "800 - 1,500 sq ft"
    case large = "1,500 - 2,500 sq ft"
    case veryLarge = "2,500 - 4,000 sq ft"
    case huge = "4,000+ sq ft"

    var midpoint: Int {
        switch self {
        case .small: return 600
        case .medium: return 1150
        case .large: return 2000
        case .veryLarge: return 3250
        case .huge: return 5000
        }
    }
}

// MARK: - User Profile (persisted via UserDefaults)

final class UserProfile {
    private let defaults = UserDefaults.standard

    var dwellingType: DwellingType {
        get {
            guard let raw = defaults.string(forKey: "dwellingType") else { return .house }
            return DwellingType(rawValue: raw) ?? .house
        }
        set { defaults.set(newValue.rawValue, forKey: "dwellingType") }
    }

    var squareFootage: SquareFootageRange {
        get {
            guard let raw = defaults.string(forKey: "squareFootage") else { return .medium }
            return SquareFootageRange(rawValue: raw) ?? .medium
        }
        set { defaults.set(newValue.rawValue, forKey: "squareFootage") }
    }

    var numberOfFloors: Int {
        get { max(1, defaults.integer(forKey: "numberOfFloors")) }
        set { defaults.set(newValue, forKey: "numberOfFloors") }
    }

    var numberOfPeople: Int {
        get { max(1, defaults.integer(forKey: "numberOfPeople")) }
        set { defaults.set(newValue, forKey: "numberOfPeople") }
    }

    var ispName: String {
        get { defaults.string(forKey: "ispName") ?? "" }
        set { defaults.set(newValue, forKey: "ispName") }
    }

    var ispPromisedSpeed: Double {
        get {
            let v = defaults.double(forKey: "ispPromisedSpeed")
            return v > 0 ? v : 100  // sane fallback so downstream math never divides by zero
        }
        set { defaults.set(newValue, forKey: "ispPromisedSpeed") }
    }

    /// Data collection is now standard — always true going forward.
    /// Property kept for backwards compatibility with existing installs.
    var dataCollectionOptIn: Bool {
        get { true }
        set { defaults.set(true, forKey: "dataCollectionOptIn") }
    }

    var floorLabels: [String] {
        get {
            if let arr = defaults.stringArray(forKey: "floorLabels"), !arr.isEmpty { return arr }
            // Default labels based on numberOfFloors
            let n = numberOfFloors
            if n <= 1 { return ["Main Floor"] }
            if n == 2 { return ["Main Floor", "Upstairs"] }
            if n == 3 { return ["Basement", "Main Floor", "Upstairs"] }
            return (1...n).map { "Floor \($0)" }
        }
        set { defaults.set(newValue, forKey: "floorLabels") }
    }

    var roomPresets: [String] {
        get {
            if let arr = defaults.stringArray(forKey: "roomPresets"), !arr.isEmpty { return arr }
            return ["Living Room", "Kitchen", "Primary Bedroom", "Bedroom 2", "Office", "Bathroom", "Garage", "Hallway"]
        }
        set { defaults.set(newValue, forKey: "roomPresets") }
    }

    var hasCompletedSetup: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}

// MARK: - Anonymous Data Snapshot (what we'd collect)

@Model
final class AnonymousDataSnapshot {
    var id: UUID
    var timestamp: Date

    // Dwelling
    var dwellingType: String
    var squareFootage: String
    var numberOfFloors: Int
    var numberOfPeople: Int

    // ISP
    var ispName: String
    var ispPromisedSpeedMbps: Double

    // Measured performance
    var measuredDownloadMbps: Double
    var measuredUploadMbps: Double
    var measuredLatencyMs: Double
    var measuredJitterMs: Double

    // Coverage (from walkthrough)
    var coverageStrongPercent: Double
    var coverageModeratePercent: Double
    var coverageWeakPercent: Double
    var totalPointsSampled: Int

    // Devices
    var wifiDeviceCount: Int
    var bleDeviceCount: Int

    // Grade
    var overallGrade: String
    var overallScore: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        dwellingType: String = "",
        squareFootage: String = "",
        numberOfFloors: Int = 1,
        numberOfPeople: Int = 1,
        ispName: String = "",
        ispPromisedSpeedMbps: Double = 0,
        measuredDownloadMbps: Double = 0,
        measuredUploadMbps: Double = 0,
        measuredLatencyMs: Double = 0,
        measuredJitterMs: Double = 0,
        coverageStrongPercent: Double = 0,
        coverageModeratePercent: Double = 0,
        coverageWeakPercent: Double = 0,
        totalPointsSampled: Int = 0,
        wifiDeviceCount: Int = 0,
        bleDeviceCount: Int = 0,
        overallGrade: String = "",
        overallScore: Double = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.dwellingType = dwellingType
        self.squareFootage = squareFootage
        self.numberOfFloors = numberOfFloors
        self.numberOfPeople = numberOfPeople
        self.ispName = ispName
        self.ispPromisedSpeedMbps = ispPromisedSpeedMbps
        self.measuredDownloadMbps = measuredDownloadMbps
        self.measuredUploadMbps = measuredUploadMbps
        self.measuredLatencyMs = measuredLatencyMs
        self.measuredJitterMs = measuredJitterMs
        self.coverageStrongPercent = coverageStrongPercent
        self.coverageModeratePercent = coverageModeratePercent
        self.coverageWeakPercent = coverageWeakPercent
        self.totalPointsSampled = totalPointsSampled
        self.wifiDeviceCount = wifiDeviceCount
        self.bleDeviceCount = bleDeviceCount
        self.overallGrade = overallGrade
        self.overallScore = overallScore
    }
}
