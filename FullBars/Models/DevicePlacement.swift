import Foundation
import SwiftData
import SwiftUI

/// A known Wi-Fi device placement (router or mesh node) within a room.
/// Replaces signal-strength-based router position estimation with ground truth.
@Model
final class DevicePlacement {
    var id: UUID
    var homeId: UUID                      // Which home this device belongs to
    var roomId: UUID                      // Which room the device is located in
    var createdAt: Date

    // Position within the room (room-local coordinates, meters)
    var x: Double
    var z: Double

    // Type
    var deviceTypeRaw: String             // DeviceType.rawValue

    // Optional metadata
    var label: String?                    // "Main Router", "Living Room Eero"
    var isPrimaryRouter: Bool             // Main router vs mesh node

    init(
        id: UUID = UUID(),
        homeId: UUID,
        roomId: UUID,
        createdAt: Date = .now,
        x: Double = 0,
        z: Double = 0,
        deviceTypeRaw: String = DeviceType.router.rawValue,
        label: String? = nil,
        isPrimaryRouter: Bool = false
    ) {
        self.id = id
        self.homeId = homeId
        self.roomId = roomId
        self.createdAt = createdAt
        self.x = x
        self.z = z
        self.deviceTypeRaw = deviceTypeRaw
        self.label = label
        self.isPrimaryRouter = isPrimaryRouter
    }

    var deviceType: DeviceType {
        DeviceType(rawValue: deviceTypeRaw) ?? .router
    }

    var displayLabel: String {
        if let label = label, !label.isEmpty { return label }
        return deviceType.label
    }
}

enum DeviceType: String, CaseIterable, Identifiable, Codable {
    case router = "router"
    case meshNode = "meshNode"
    case computer = "computer"
    case television = "television"
    case tablet = "tablet"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .router: return "Router"
        case .meshNode: return "Mesh Node"
        case .computer: return "Computer"
        case .television: return "Television"
        case .tablet: return "Tablet"
        }
    }

    var systemImage: String {
        switch self {
        case .router: return "wifi.router.fill"
        case .meshNode: return "dot.radiowaves.left.and.right"
        case .computer: return "desktopcomputer"
        case .television: return "tv.fill"
        case .tablet: return "ipad"
        }
    }

    var color: Color {
        switch self {
        case .router: return .cyan
        case .meshNode: return .purple
        case .computer: return .blue
        case .television: return .green
        case .tablet: return .orange
        }
    }
}
