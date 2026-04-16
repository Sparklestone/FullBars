import Foundation
import SwiftData
import SwiftUI

/// A single room within a home. Contains shape (corners), painted coverage,
/// device placements (router/mesh nodes), doorways, and aggregated metrics.
@Model
final class Room {
    var id: UUID
    var homeId: UUID
    var createdAt: Date
    var lastScannedAt: Date?

    // Identity
    var roomTypeRaw: String               // RoomType.rawValue
    var customName: String?               // Optional user override ("Master Bedroom", "The Cave")
    var floorIndex: Int                   // 0-based; references HomeConfiguration.floorLabels

    // Shape — polygon of corner points in room-local coordinates (meters)
    var cornersJSON: String               // JSON-encoded [[Float, Float]] representing (x, z) tuples

    // Painted coverage — grid cells that the user walked through. Used to show
    // which areas were actually scanned vs gaps (furniture/obstacles).
    var paintedCellsJSON: String          // JSON-encoded [[Int, Int]] (grid indices)
    var paintGridResolutionMeters: Float  // Cell size (default 0.5m = 0.5m × 0.5m tiles)

    // Speed test result for this room (single stationary test at room start)
    var downloadMbps: Double
    var uploadMbps: Double
    var pingMs: Double
    var speedTestAt: Date?

    // BLE interference count (captured during walk)
    var bleDeviceCount: Int

    // Session identifier — ties HeatmapPoints to this specific room scan
    var sessionId: UUID

    // Analysis cache — so we don't recompute every time the view opens
    var gradeScore: Double                // 0-100
    var gradeLetterRaw: String            // "A", "B", etc.
    var deadZoneCount: Int
    var interferenceZoneCount: Int
    var recommendationCount: Int

    init(
        id: UUID = UUID(),
        homeId: UUID,
        createdAt: Date = .now,
        lastScannedAt: Date? = nil,
        roomTypeRaw: String = RoomType.livingRoom.rawValue,
        customName: String? = nil,
        floorIndex: Int = 0,
        cornersJSON: String = "[]",
        paintedCellsJSON: String = "[]",
        paintGridResolutionMeters: Float = 0.5,
        downloadMbps: Double = 0,
        uploadMbps: Double = 0,
        pingMs: Double = 0,
        speedTestAt: Date? = nil,
        bleDeviceCount: Int = 0,
        sessionId: UUID = UUID(),
        gradeScore: Double = 0,
        gradeLetterRaw: String = "",
        deadZoneCount: Int = 0,
        interferenceZoneCount: Int = 0,
        recommendationCount: Int = 0
    ) {
        self.id = id
        self.homeId = homeId
        self.createdAt = createdAt
        self.lastScannedAt = lastScannedAt
        self.roomTypeRaw = roomTypeRaw
        self.customName = customName
        self.floorIndex = floorIndex
        self.cornersJSON = cornersJSON
        self.paintedCellsJSON = paintedCellsJSON
        self.paintGridResolutionMeters = paintGridResolutionMeters
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.pingMs = pingMs
        self.speedTestAt = speedTestAt
        self.bleDeviceCount = bleDeviceCount
        self.sessionId = sessionId
        self.gradeScore = gradeScore
        self.gradeLetterRaw = gradeLetterRaw
        self.deadZoneCount = deadZoneCount
        self.interferenceZoneCount = interferenceZoneCount
        self.recommendationCount = recommendationCount
    }

    // MARK: - Computed helpers

    var roomType: RoomType {
        RoomType(rawValue: roomTypeRaw) ?? .other
    }

    var displayName: String {
        if let custom = customName, !custom.isEmpty {
            return custom
        }
        return roomType.label
    }

    var corners: [(Float, Float)] {
        get {
            guard let data = cornersJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([[Float]].self, from: data) else {
                return []
            }
            return arr.compactMap { $0.count >= 2 ? ($0[0], $0[1]) : nil }
        }
        set {
            let arr = newValue.map { [$0.0, $0.1] }
            if let data = try? JSONEncoder().encode(arr),
               let json = String(data: data, encoding: .utf8) {
                cornersJSON = json
            }
        }
    }

    var paintedCells: [(Int, Int)] {
        get {
            guard let data = paintedCellsJSON.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([[Int]].self, from: data) else {
                return []
            }
            return arr.compactMap { $0.count >= 2 ? ($0[0], $0[1]) : nil }
        }
        set {
            let arr = newValue.map { [$0.0, $0.1] }
            if let data = try? JSONEncoder().encode(arr),
               let json = String(data: data, encoding: .utf8) {
                paintedCellsJSON = json
            }
        }
    }

    /// Approximate floor area in square meters from the corner polygon (shoelace formula)
    var approximateAreaSquareMeters: Float {
        let pts = corners
        guard pts.count >= 3 else { return 0 }
        var sum: Float = 0
        for i in 0..<pts.count {
            let j = (i + 1) % pts.count
            sum += pts[i].0 * pts[j].1
            sum -= pts[j].0 * pts[i].1
        }
        return abs(sum) / 2
    }

    /// Painted coverage percentage (0.0 - 1.0). How much of the room's floor area
    /// the user actually walked over. Used to gate the "Room Complete" button.
    var paintedCoverageFraction: Double {
        let area = approximateAreaSquareMeters
        guard area > 0 else { return 0 }
        let paintedArea = Float(paintedCells.count) * paintGridResolutionMeters * paintGridResolutionMeters
        return min(1.0, Double(paintedArea / area))
    }
}

// MARK: - Room type enum

enum RoomType: String, CaseIterable, Identifiable, Codable {
    case livingRoom = "livingRoom"
    case kitchen = "kitchen"
    case diningRoom = "diningRoom"
    case bedroom = "bedroom"
    case masterBedroom = "masterBedroom"
    case bathroom = "bathroom"
    case office = "office"
    case hallway = "hallway"
    case entryway = "entryway"
    case laundry = "laundry"
    case garage = "garage"
    case basement = "basement"
    case attic = "attic"
    case outdoor = "outdoor"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .livingRoom: return "Living Room"
        case .kitchen: return "Kitchen"
        case .diningRoom: return "Dining Room"
        case .bedroom: return "Bedroom"
        case .masterBedroom: return "Master Bedroom"
        case .bathroom: return "Bathroom"
        case .office: return "Office"
        case .hallway: return "Hallway"
        case .entryway: return "Entryway"
        case .laundry: return "Laundry Room"
        case .garage: return "Garage"
        case .basement: return "Basement"
        case .attic: return "Attic"
        case .outdoor: return "Outdoor"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .kitchen: return "fork.knife"
        case .diningRoom: return "table.furniture.fill"
        case .bedroom, .masterBedroom: return "bed.double.fill"
        case .bathroom: return "bathtub.fill"
        case .office: return "desktopcomputer"
        case .hallway: return "arrow.left.and.right"
        case .entryway: return "door.left.hand.open"
        case .laundry: return "washer.fill"
        case .garage: return "car.fill"
        case .basement: return "square.stack.3d.down.right.fill"
        case .attic: return "triangle.fill"
        case .outdoor: return "tree.fill"
        case .other: return "square.dashed"
        }
    }
}
