#if DEBUG
import Foundation
import SwiftData
import os

/// Handles UI-testing launch arguments documented in FullBars/Tests/QA/TEST_SETUP.md §3.
///
/// Supported flags:
///   • `-UITesting-ResetState`      — wipes `hasCompletedOnboarding` so the onboarding flow shows.
///   • `-UITesting-SkipOnboarding`  — marks onboarding complete and seeds a default HomeConfiguration.
///   • `-UITesting-NoRooms`         — as above, but guarantees the Room table is empty.
///   • `-UITesting-SeedRooms <N>`   — as SkipOnboarding, plus inserts N synthetic rooms (caps at 20).
///
/// Split into two phases because we need to flip `UserDefaults` before the SwiftData
/// container is constructed, but need the container itself to seed HomeConfiguration / wipe Rooms.
enum UITestingLaunchHandler {
    private static let log = Logger(subsystem: "com.fullbars.app", category: "UITestingLaunch")

    private static var args: [String] { ProcessInfo.processInfo.arguments }

    private static func hasFlag(_ flag: String) -> Bool { args.contains(flag) }

    /// Returns the value following `flag` in argv, or nil if not present.
    /// Supports `-flag value` form (XCTest passes launch args as two tokens).
    private static func value(for flag: String) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    private static var seedRoomsCount: Int? {
        guard let raw = value(for: "-UITesting-SeedRooms"), let n = Int(raw), n > 0 else { return nil }
        return min(n, 20)
    }

    /// Runs before the ModelContainer is built. Mutates UserDefaults only.
    static func applyPreContainer() {
        if hasFlag("-UITesting-ResetState") {
            log.debug("Applying -UITesting-ResetState")
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        }
        let skipFlags = hasFlag("-UITesting-SkipOnboarding")
            || hasFlag("-UITesting-NoRooms")
            || seedRoomsCount != nil
        if skipFlags {
            log.debug("Applying SkipOnboarding (hasCompletedOnboarding = true)")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    /// Runs after the ModelContainer is built. Seeds / wipes SwiftData as needed.
    @MainActor
    static func applyPostContainer(_ container: ModelContainer) {
        let seedCount = seedRoomsCount
        let wantsSkip = hasFlag("-UITesting-SkipOnboarding")
            || hasFlag("-UITesting-NoRooms")
            || seedCount != nil
        let wantsNoRooms = hasFlag("-UITesting-NoRooms")
        guard wantsSkip || wantsNoRooms else { return }

        let context = ModelContext(container)

        var home: HomeConfiguration?
        if wantsSkip {
            let existing = (try? context.fetch(FetchDescriptor<HomeConfiguration>())) ?? []
            if let first = existing.first {
                home = first
            } else {
                log.debug("Seeding default HomeConfiguration for UI tests")
                let newHome = HomeConfiguration(
                    name: "UITest Home",
                    dwellingType: "House",
                    squareFootage: 1500,
                    numberOfFloors: 1,
                    floorLabelsJSON: "[\"Main\"]",
                    numberOfPeople: 2,
                    ispName: "Test ISP",
                    ispPromisedDownloadMbps: 500,
                    ispPromisedUploadMbps: 50,
                    zipCode: "94103"
                )
                context.insert(newHome)
                home = newHome
            }
        }

        if wantsNoRooms {
            log.debug("Wiping Room table for -UITesting-NoRooms")
            if let rooms = try? context.fetch(FetchDescriptor<Room>()) {
                for room in rooms { context.delete(room) }
            }
        } else if let seedCount, let homeId = home?.id {
            // Only seed rooms if the table is empty — don't double-seed across launches.
            let existing = (try? context.fetch(FetchDescriptor<Room>())) ?? []
            if existing.isEmpty {
                log.debug("Seeding \(seedCount) synthetic Rooms for UI tests")
                for i in 0..<seedCount { context.insert(Self.syntheticRoom(index: i, homeId: homeId)) }
            }
        }

        do { try context.save() }
        catch { log.error("UITesting post-container save failed: \(error.localizedDescription)") }
    }

    private static func syntheticRoom(index: Int, homeId: UUID) -> Room {
        // Rotate through a handful of room types so lists don't look homogenous.
        let types: [RoomType] = [.livingRoom, .kitchen, .bedroom, .bathroom, .office, .hallway]
        let type = types[index % types.count]
        // Grades cycle A→B→C→D so populated results views exercise multiple states.
        let grades: [(Double, String)] = [(92, "A"), (82, "B"), (71, "C"), (58, "D")]
        let grade = grades[index % grades.count]
        return Room(
            homeId: homeId,
            lastScannedAt: .now.addingTimeInterval(Double(-index) * 3600),
            roomTypeRaw: type.rawValue,
            customName: nil,
            floorIndex: 0,
            cornersJSON: "[[0,0],[4,0],[4,3],[0,3]]",
            paintedCellsJSON: "[]",
            downloadMbps: 120 + Double(index * 10),
            uploadMbps: 12 + Double(index),
            pingMs: 20 + Double(index),
            speedTestAt: .now,
            bleDeviceCount: index,
            gradeScore: grade.0,
            gradeLetterRaw: grade.1,
            deadZoneCount: index % 3,
            interferenceZoneCount: index % 2,
            recommendationCount: 1 + index % 4
        )
    }
}
#endif
