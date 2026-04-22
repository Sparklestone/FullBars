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
    case under600  = "Under 600 sq ft"
    case sqft600   = "600+ sq ft"
    case sqft1200  = "1,200+ sq ft"
    case sqft1800  = "1,800+ sq ft"
    case sqft2400  = "2,400+ sq ft"
    case sqft3000  = "3,000+ sq ft"
    case sqft3600  = "3,600+ sq ft"
    case sqft4200  = "4,200+ sq ft"
    case sqft4800  = "4,800+ sq ft"
    case sqft5400  = "5,400+ sq ft"
    case sqft6000  = "6,000+ sq ft"
    case sqft6600  = "6,600+ sq ft"
    case sqft7200  = "7,200+ sq ft"
    case sqft7800  = "7,800+ sq ft"
    case sqft8400  = "8,400+ sq ft"
    case sqft9000  = "9,000+ sq ft"

    var midpoint: Int {
        switch self {
        case .under600:  return 400
        case .sqft600:   return 900
        case .sqft1200:  return 1500
        case .sqft1800:  return 2100
        case .sqft2400:  return 2700
        case .sqft3000:  return 3300
        case .sqft3600:  return 3900
        case .sqft4200:  return 4500
        case .sqft4800:  return 5100
        case .sqft5400:  return 5700
        case .sqft6000:  return 6300
        case .sqft6600:  return 6900
        case .sqft7200:  return 7500
        case .sqft7800:  return 8100
        case .sqft8400:  return 8700
        case .sqft9000:  return 9300
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
            guard let raw = defaults.string(forKey: "squareFootage") else { return .sqft1800 }
            return SquareFootageRange(rawValue: raw) ?? .sqft1800
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

    /// Data collection accepted by continuing through onboarding.
    /// Defaults to true for users who complete the data acceptance step.
    var dataCollectionOptIn: Bool {
        get { defaults.object(forKey: "dataCollectionOptIn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "dataCollectionOptIn") }
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

    /// Whether the ISP speed is the user's actual plan or an area average estimate.
    var usingAreaAverage: Bool {
        get { defaults.bool(forKey: "usingAreaAverage") }
        set { defaults.set(newValue, forKey: "usingAreaAverage") }
    }

    /// The comparison label shown in the UI — either "promised speed" or "area average".
    var speedComparisonLabel: String {
        usingAreaAverage ? "area average" : "promised speed"
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
