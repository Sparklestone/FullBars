import Foundation
import SwiftData

/// Global active-home selection + Pro gating for multi-home and rescan history.
/// Free users get ONE home and only the most-recent scan per room type.
/// Pro users get unlimited homes and full rescan history.
enum HomeSelection {
    private static let activeHomeIdKey = "activeHomeId"

    /// The currently active home for the scan / results / settings tabs.
    /// Falls back to the first home if nothing is stored or the stored ID
    /// no longer exists.
    static func activeHome(from homes: [HomeConfiguration]) -> HomeConfiguration? {
        guard !homes.isEmpty else { return nil }
        if let raw = UserDefaults.standard.string(forKey: activeHomeIdKey),
           let uuid = UUID(uuidString: raw),
           let match = homes.first(where: { $0.id == uuid }) {
            return match
        }
        return homes.first
    }

    static func setActive(_ home: HomeConfiguration) {
        UserDefaults.standard.set(home.id.uuidString, forKey: activeHomeIdKey)
    }

    /// Free users are limited to a single home.
    static func canAddAnotherHome(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount == 0
    }
}

/// Reduce a list of rooms for a home into the set visible to the user, given
/// their subscription status. Free users see only the most recent scan per
/// room (same type + same custom name). Pro users see everything.
enum RescanHistory {
    /// Deduplicate rooms by (roomType, customName, floorIndex), keeping the
    /// most recently created. Returns rooms in descending createdAt order.
    static func visibleRooms(for rooms: [Room], isPro: Bool) -> [Room] {
        let sorted = rooms.sorted { $0.createdAt > $1.createdAt }
        if isPro { return sorted }

        var seenKeys = Set<String>()
        var result: [Room] = []
        for room in sorted {
            let key = dedupKey(for: room)
            if seenKeys.insert(key).inserted {
                result.append(room)
            }
        }
        return result
    }

    /// All historical scans for a single "slot" (same room type + name + floor).
    /// Sorted newest first.
    static func history(forSlotMatching room: Room, in rooms: [Room]) -> [Room] {
        let key = dedupKey(for: room)
        return rooms
            .filter { dedupKey(for: $0) == key }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func dedupKey(for room: Room) -> String {
        let name = (room.customName ?? "").lowercased()
        return "\(room.roomTypeRaw)|\(name)|\(room.floorIndex)"
    }
}
