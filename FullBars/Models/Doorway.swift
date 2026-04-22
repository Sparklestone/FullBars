import Foundation
import SwiftData

/// A doorway / entryway within a room. Used to stitch rooms together into
/// a connected floor plan and to understand signal pass-throughs for analysis.
@Model
final class Doorway {
    var id: UUID
    var roomId: UUID                       // The room this doorway belongs to
    var createdAt: Date

    // Position in room-local coordinates (meters)
    var x: Double
    var z: Double

    // What this doorway connects to. Only one of the three should be true.
    var connectsToRoomId: UUID?           // Links to another Room.id (internal door)
    var connectsToOutside: Bool           // External door (front door, back door, patio)
    var connectsToUnknownRoom: Bool       // User said "another room" but hasn't scanned it yet
    var connectsToOutsideTypeRaw: String?  // If outside: "Front", "Back", "Garage", etc.

    // Optional metadata
    var pendingRoomTypeRaw: String?       // If connectsToUnknownRoom, what type did they say it'd be
    var pendingRoomName: String?          // Optional custom name for the pending room

    init(
        id: UUID = UUID(),
        roomId: UUID,
        createdAt: Date = .now,
        x: Double = 0,
        z: Double = 0,
        connectsToRoomId: UUID? = nil,
        connectsToOutside: Bool = false,
        connectsToUnknownRoom: Bool = false,
        connectsToOutsideTypeRaw: String? = nil,
        pendingRoomTypeRaw: String? = nil,
        pendingRoomName: String? = nil
    ) {
        self.id = id
        self.roomId = roomId
        self.createdAt = createdAt
        self.x = x
        self.z = z
        self.connectsToRoomId = connectsToRoomId
        self.connectsToOutside = connectsToOutside
        self.connectsToUnknownRoom = connectsToUnknownRoom
        self.connectsToOutsideTypeRaw = connectsToOutsideTypeRaw
        self.pendingRoomTypeRaw = pendingRoomTypeRaw
        self.pendingRoomName = pendingRoomName
    }

    var connectionDescription: String {
        if connectsToOutside {
            return "Outside" + (connectsToOutsideTypeRaw.map { " (\($0))" } ?? "")
        }
        if connectsToRoomId != nil {
            return "Connected room"
        }
        if connectsToUnknownRoom {
            if let label = pendingRoomName, !label.isEmpty {
                return "Pending: \(label)"
            }
            if let typeRaw = pendingRoomTypeRaw,
               let type = RoomType(rawValue: typeRaw) {
                return "Pending: \(type.label)"
            }
            return "Pending room"
        }
        return "Unmarked"
    }
}

enum OutsideConnectionType: String, CaseIterable, Identifiable {
    case front = "Front"
    case back = "Back"
    case side = "Side"
    case garage = "Garage"
    case patio = "Patio / Deck"
    case other = "Other"

    var id: String { rawValue }
}
