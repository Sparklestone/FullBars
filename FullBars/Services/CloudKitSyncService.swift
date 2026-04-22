import Foundation
import CloudKit
import SwiftData
import os

/// Syncs user data to iCloud via CloudKit for cross-device backup.
///
/// Architecture:
/// - Uses the private CloudKit database (user's own iCloud storage)
/// - Syncs: HomeConfiguration, Room, DevicePlacement, Doorway, HeatmapPoint
/// - Offline-first: local SwiftData is the source of truth; CloudKit is backup
/// - Conflict resolution: last-write-wins based on timestamp
/// - Designed for eventual consistency — not real-time sync
///
/// Setup required:
/// 1. Add "iCloud" capability in Xcode → Signing & Capabilities
/// 2. Check "CloudKit" and add container "iCloud.com.fullbars.app"
/// 3. Add the container identifier to entitlements
final class CloudKitSyncService {
    static let shared = CloudKitSyncService()

    private let logger = Logger(subsystem: "com.fullbars.app", category: "CloudKitSync")
    private let container = CKContainer(identifier: "iCloud.com.fullbars.app")
    private var privateDB: CKDatabase { container.privateCloudDatabase }

    /// CloudKit record type names
    private enum RecordType {
        static let home = "HomeConfiguration"
        static let room = "Room"
        static let device = "DevicePlacement"
        static let doorway = "Doorway"
        static let heatmapPoint = "HeatmapPoint"
    }

    /// UserDefaults key for tracking last sync timestamp
    private let lastSyncKey = "cloudkit_last_sync"
    private let syncEnabledKey = "cloudkit_sync_enabled"

    var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: syncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: syncEnabledKey) }
    }

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    // MARK: - Account Status

    /// Check if iCloud is available before attempting sync.
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            logger.error("Failed to check iCloud account: \(error.localizedDescription)")
            return .couldNotDetermine
        }
    }

    // MARK: - Full Backup (Upload)

    /// Uploads all homes and their child records to CloudKit.
    /// Call after a scan completes or when user explicitly requests backup.
    func backupAll(context: ModelContext) async throws {
        guard isSyncEnabled else {
            logger.info("CloudKit sync disabled — skipping backup")
            return
        }

        let status = await checkAccountStatus()
        guard status == .available else {
            logger.warning("iCloud not available (status: \(String(describing: status)))")
            throw CloudKitSyncError.iCloudUnavailable
        }

        // Fetch all homes
        let homes = try context.fetch(FetchDescriptor<HomeConfiguration>())
        logger.info("Backing up \(homes.count) homes to iCloud")

        for home in homes {
            try await backupHome(home, context: context)
        }

        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        logger.info("Full backup complete")
    }

    /// Backs up a single home and all its child records.
    func backupHome(_ home: HomeConfiguration, context: ModelContext) async throws {
        // 1. Upload home record
        let homeRecord = homeToRecord(home)
        try await saveRecord(homeRecord)

        // 2. Fetch and upload rooms
        let homeIdValue = home.id
        let roomDescriptor = FetchDescriptor<Room>(predicate: #Predicate { $0.homeId == homeIdValue })
        let rooms = try context.fetch(roomDescriptor)

        for room in rooms {
            let roomRecord = roomToRecord(room)
            try await saveRecord(roomRecord)

            // 3. Upload devices for this room
            let roomIdForDevices = room.id
            let deviceDescriptor = FetchDescriptor<DevicePlacement>(predicate: #Predicate { $0.roomId == roomIdForDevices })
            let devices = try context.fetch(deviceDescriptor)
            let deviceRecords = devices.map { deviceToRecord($0) }
            if !deviceRecords.isEmpty {
                try await saveBatch(deviceRecords)
            }

            // 4. Upload doorways for this room
            let roomIdForDoorways = room.id
            let doorwayDescriptor = FetchDescriptor<Doorway>(predicate: #Predicate { $0.roomId == roomIdForDoorways })
            let doorways = try context.fetch(doorwayDescriptor)
            let doorwayRecords = doorways.map { doorwayToRecord($0) }
            if !doorwayRecords.isEmpty {
                try await saveBatch(doorwayRecords)
            }

            // 5. Upload heatmap points for this room (batched — can be large)
            let roomIdForPoints: UUID? = room.id
            let pointDescriptor = FetchDescriptor<HeatmapPoint>(predicate: #Predicate { $0.roomId == roomIdForPoints })
            let points = try context.fetch(pointDescriptor)
            if !points.isEmpty {
                try await uploadHeatmapPointsBatched(points)
            }
        }

        logger.info("Backed up home '\(home.name)' with \(rooms.count) rooms")
    }

    // MARK: - Restore (Download)

    /// Restores all data from iCloud to local SwiftData.
    /// Call on first launch after reinstall or on a new device.
    func restoreAll(context: ModelContext) async throws {
        let status = await checkAccountStatus()
        guard status == .available else {
            throw CloudKitSyncError.iCloudUnavailable
        }

        logger.info("Starting restore from iCloud")

        // 1. Fetch all home records
        let homeRecords = try await fetchAll(recordType: RecordType.home)
        logger.info("Found \(homeRecords.count) homes in iCloud")

        for homeRecord in homeRecords {
            // Check if this home already exists locally
            let homeId = UUID(uuidString: homeRecord.recordID.recordName) ?? UUID()
            let homeIdValue = homeId
            let existing = try context.fetch(FetchDescriptor<HomeConfiguration>(
                predicate: #Predicate { $0.id == homeIdValue }
            ))
            if !existing.isEmpty {
                logger.info("Home \(homeId.uuidString) already exists locally — updating")
                updateHomeFromRecord(existing[0], record: homeRecord)
            } else {
                let home = recordToHome(homeRecord)
                context.insert(home)
            }
        }

        // 2. Fetch and restore rooms
        let roomRecords = try await fetchAll(recordType: RecordType.room)
        for roomRecord in roomRecords {
            let roomId = UUID(uuidString: roomRecord.recordID.recordName) ?? UUID()
            let roomIdValue = roomId
            let existing = try context.fetch(FetchDescriptor<Room>(
                predicate: #Predicate { $0.id == roomIdValue }
            ))
            if existing.isEmpty {
                let room = recordToRoom(roomRecord)
                context.insert(room)
            }
        }

        // 3. Fetch and restore devices
        let deviceRecords = try await fetchAll(recordType: RecordType.device)
        for record in deviceRecords {
            let devId = UUID(uuidString: record.recordID.recordName) ?? UUID()
            let devIdValue = devId
            let existing = try context.fetch(FetchDescriptor<DevicePlacement>(
                predicate: #Predicate { $0.id == devIdValue }
            ))
            if existing.isEmpty {
                let device = recordToDevice(record)
                context.insert(device)
            }
        }

        // 4. Fetch and restore doorways
        let doorwayRecords = try await fetchAll(recordType: RecordType.doorway)
        for record in doorwayRecords {
            let dwId = UUID(uuidString: record.recordID.recordName) ?? UUID()
            let dwIdValue = dwId
            let existing = try context.fetch(FetchDescriptor<Doorway>(
                predicate: #Predicate { $0.id == dwIdValue }
            ))
            if existing.isEmpty {
                let doorway = recordToDoorway(record)
                context.insert(doorway)
            }
        }

        // 5. Fetch and restore heatmap points
        let pointRecords = try await fetchAll(recordType: RecordType.heatmapPoint)
        for record in pointRecords {
            let ptId = UUID(uuidString: record.recordID.recordName) ?? UUID()
            let ptIdValue = ptId
            let existing = try context.fetch(FetchDescriptor<HeatmapPoint>(
                predicate: #Predicate { $0.id == ptIdValue }
            ))
            if existing.isEmpty {
                let point = recordToHeatmapPoint(record)
                context.insert(point)
            }
        }

        try context.save()
        UserDefaults.standard.set(Date(), forKey: lastSyncKey)
        logger.info("Restore complete")
    }

    // MARK: - Delete Home from iCloud

    /// Removes a home and all its child records from iCloud.
    func deleteHome(_ homeId: UUID) async throws {
        guard isSyncEnabled else { return }

        // Delete child records first, then the home
        let childTypes = [RecordType.heatmapPoint, RecordType.device, RecordType.doorway, RecordType.room]
        for type in childTypes {
            let records = try await fetchAll(recordType: type) // Would ideally filter by homeId
            let toDelete = records.filter { record in
                if let recordHomeId = record["homeId"] as? String {
                    return recordHomeId == homeId.uuidString
                }
                return false
            }
            if !toDelete.isEmpty {
                try await deleteBatch(toDelete.map(\.recordID))
            }
        }

        // Delete the home record
        let homeRecordID = CKRecord.ID(recordName: homeId.uuidString)
        try await privateDB.deleteRecord(withID: homeRecordID)
        logger.info("Deleted home \(homeId.uuidString) from iCloud")
    }

    // MARK: - CloudKit Record Conversions

    private func homeToRecord(_ home: HomeConfiguration) -> CKRecord {
        let record = CKRecord(recordType: RecordType.home, recordID: CKRecord.ID(recordName: home.id.uuidString))
        record["name"] = home.name
        record["dwellingType"] = home.dwellingType
        record["squareFootage"] = home.squareFootage
        record["numberOfFloors"] = home.numberOfFloors
        record["floorLabelsJSON"] = home.floorLabelsJSON
        record["numberOfPeople"] = home.numberOfPeople
        record["hasMeshNetwork"] = home.hasMeshNetwork ? 1 : 0
        record["meshNodeCount"] = home.meshNodeCount
        record["ispName"] = home.ispName
        record["ispPromisedDownloadMbps"] = home.ispPromisedDownloadMbps
        record["ispPromisedUploadMbps"] = home.ispPromisedUploadMbps
        record["zipCode"] = home.zipCode
        record["dataCollectionOptIn"] = home.dataCollectionOptIn ? 1 : 0
        record["createdAt"] = home.createdAt
        record["lastScannedAt"] = home.lastScannedAt
        return record
    }

    private func recordToHome(_ record: CKRecord) -> HomeConfiguration {
        HomeConfiguration(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            createdAt: record["createdAt"] as? Date ?? .now,
            lastScannedAt: record["lastScannedAt"] as? Date,
            name: record["name"] as? String ?? "Home",
            dwellingType: record["dwellingType"] as? String ?? "House",
            squareFootage: record["squareFootage"] as? Int ?? 1500,
            numberOfFloors: record["numberOfFloors"] as? Int ?? 1,
            floorLabelsJSON: record["floorLabelsJSON"] as? String ?? "[\"Main\"]",
            numberOfPeople: record["numberOfPeople"] as? Int ?? 2,
            hasMeshNetwork: (record["hasMeshNetwork"] as? Int ?? 0) == 1,
            meshNodeCount: record["meshNodeCount"] as? Int ?? 0,
            ispName: record["ispName"] as? String ?? "",
            ispPromisedDownloadMbps: record["ispPromisedDownloadMbps"] as? Double ?? 0,
            ispPromisedUploadMbps: record["ispPromisedUploadMbps"] as? Double ?? 0,
            zipCode: record["zipCode"] as? String ?? "",
            dataCollectionOptIn: (record["dataCollectionOptIn"] as? Int ?? 0) == 1
        )
    }

    private func updateHomeFromRecord(_ home: HomeConfiguration, record: CKRecord) {
        home.name = record["name"] as? String ?? home.name
        home.dwellingType = record["dwellingType"] as? String ?? home.dwellingType
        home.squareFootage = record["squareFootage"] as? Int ?? home.squareFootage
        home.numberOfFloors = record["numberOfFloors"] as? Int ?? home.numberOfFloors
        home.floorLabelsJSON = record["floorLabelsJSON"] as? String ?? home.floorLabelsJSON
        home.numberOfPeople = record["numberOfPeople"] as? Int ?? home.numberOfPeople
        home.hasMeshNetwork = (record["hasMeshNetwork"] as? Int ?? 0) == 1
        home.meshNodeCount = record["meshNodeCount"] as? Int ?? home.meshNodeCount
        home.ispName = record["ispName"] as? String ?? home.ispName
        home.ispPromisedDownloadMbps = record["ispPromisedDownloadMbps"] as? Double ?? home.ispPromisedDownloadMbps
        home.ispPromisedUploadMbps = record["ispPromisedUploadMbps"] as? Double ?? home.ispPromisedUploadMbps
        home.zipCode = record["zipCode"] as? String ?? home.zipCode
        home.dataCollectionOptIn = (record["dataCollectionOptIn"] as? Int ?? 0) == 1
        home.lastScannedAt = record["lastScannedAt"] as? Date ?? home.lastScannedAt
    }

    private func roomToRecord(_ room: Room) -> CKRecord {
        let record = CKRecord(recordType: RecordType.room, recordID: CKRecord.ID(recordName: room.id.uuidString))
        record["homeId"] = room.homeId.uuidString
        record["roomTypeRaw"] = room.roomTypeRaw
        record["customName"] = room.customName
        record["floorIndex"] = room.floorIndex
        record["cornersJSON"] = room.cornersJSON
        record["paintedCellsJSON"] = room.paintedCellsJSON
        record["paintGridResolutionMeters"] = Double(room.paintGridResolutionMeters)
        record["downloadMbps"] = room.downloadMbps
        record["uploadMbps"] = room.uploadMbps
        record["pingMs"] = room.pingMs
        record["bleDeviceCount"] = room.bleDeviceCount
        record["sessionId"] = room.sessionId.uuidString
        record["gradeScore"] = room.gradeScore
        record["gradeLetterRaw"] = room.gradeLetterRaw
        record["deadZoneCount"] = room.deadZoneCount  // DO NOT RENAME (CloudKit persistence key)
        record["interferenceZoneCount"] = room.interferenceZoneCount
        record["recommendationCount"] = room.recommendationCount
        record["createdAt"] = room.createdAt
        record["lastScannedAt"] = room.lastScannedAt
        record["speedTestAt"] = room.speedTestAt
        return record
    }

    private func recordToRoom(_ record: CKRecord) -> Room {
        let room = Room(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            homeId: UUID(uuidString: record["homeId"] as? String ?? "") ?? UUID(),
            roomTypeRaw: record["roomTypeRaw"] as? String ?? "other",
            customName: record["customName"] as? String,
            floorIndex: record["floorIndex"] as? Int ?? 0,
            cornersJSON: record["cornersJSON"] as? String ?? "[]",
            paintedCellsJSON: record["paintedCellsJSON"] as? String ?? "[]",
            paintGridResolutionMeters: record["paintGridResolutionMeters"] as? Double ?? 0.5,
            downloadMbps: record["downloadMbps"] as? Double ?? 0,
            uploadMbps: record["uploadMbps"] as? Double ?? 0,
            pingMs: record["pingMs"] as? Double ?? 0,
            bleDeviceCount: record["bleDeviceCount"] as? Int ?? 0,
            sessionId: UUID(uuidString: record["sessionId"] as? String ?? "") ?? UUID()
        )
        room.gradeScore = record["gradeScore"] as? Double ?? 0
        room.gradeLetterRaw = record["gradeLetterRaw"] as? String ?? "F"
        room.deadZoneCount = record["deadZoneCount"] as? Int ?? 0  // DO NOT RENAME (CloudKit persistence key)
        room.interferenceZoneCount = record["interferenceZoneCount"] as? Int ?? 0
        room.recommendationCount = record["recommendationCount"] as? Int ?? 0
        room.lastScannedAt = record["lastScannedAt"] as? Date
        room.speedTestAt = record["speedTestAt"] as? Date
        return room
    }

    private func deviceToRecord(_ device: DevicePlacement) -> CKRecord {
        let record = CKRecord(recordType: RecordType.device, recordID: CKRecord.ID(recordName: device.id.uuidString))
        record["homeId"] = device.homeId.uuidString
        record["roomId"] = device.roomId.uuidString
        record["x"] = device.x
        record["z"] = device.z
        record["deviceTypeRaw"] = device.deviceTypeRaw
        record["label"] = device.label
        record["isPrimaryRouter"] = device.isPrimaryRouter ? 1 : 0
        record["createdAt"] = device.createdAt
        return record
    }

    private func recordToDevice(_ record: CKRecord) -> DevicePlacement {
        DevicePlacement(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            homeId: UUID(uuidString: record["homeId"] as? String ?? "") ?? UUID(),
            roomId: UUID(uuidString: record["roomId"] as? String ?? "") ?? UUID(),
            x: record["x"] as? Double ?? 0,
            z: record["z"] as? Double ?? 0,
            deviceTypeRaw: record["deviceTypeRaw"] as? String ?? "router",
            label: record["label"] as? String,
            isPrimaryRouter: (record["isPrimaryRouter"] as? Int ?? 0) == 1
        )
    }

    private func doorwayToRecord(_ doorway: Doorway) -> CKRecord {
        let record = CKRecord(recordType: RecordType.doorway, recordID: CKRecord.ID(recordName: doorway.id.uuidString))
        record["roomId"] = doorway.roomId.uuidString
        record["x"] = doorway.x
        record["z"] = doorway.z
        record["connectsToRoomId"] = doorway.connectsToRoomId?.uuidString
        record["connectsToOutside"] = doorway.connectsToOutside ? 1 : 0
        record["connectsToUnknownRoom"] = doorway.connectsToUnknownRoom ? 1 : 0
        record["connectsToOutsideTypeRaw"] = doorway.connectsToOutsideTypeRaw
        record["pendingRoomTypeRaw"] = doorway.pendingRoomTypeRaw
        record["pendingRoomName"] = doorway.pendingRoomName
        record["createdAt"] = doorway.createdAt
        return record
    }

    private func recordToDoorway(_ record: CKRecord) -> Doorway {
        Doorway(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            roomId: UUID(uuidString: record["roomId"] as? String ?? "") ?? UUID(),
            x: record["x"] as? Double ?? 0,
            z: record["z"] as? Double ?? 0,
            connectsToRoomId: (record["connectsToRoomId"] as? String).flatMap(UUID.init),
            connectsToOutside: (record["connectsToOutside"] as? Int ?? 0) == 1,
            connectsToUnknownRoom: (record["connectsToUnknownRoom"] as? Int ?? 0) == 1,
            connectsToOutsideTypeRaw: record["connectsToOutsideTypeRaw"] as? String,
            pendingRoomTypeRaw: record["pendingRoomTypeRaw"] as? String,
            pendingRoomName: record["pendingRoomName"] as? String
        )
    }

    private func heatmapPointToRecord(_ point: HeatmapPoint) -> CKRecord {
        let record = CKRecord(recordType: RecordType.heatmapPoint, recordID: CKRecord.ID(recordName: point.id.uuidString))
        record["x"] = point.x
        record["y"] = point.y
        record["z"] = point.z
        record["signalStrength"] = point.signalStrength
        record["latency"] = point.latency
        record["downloadSpeed"] = point.downloadSpeed
        record["timestamp"] = point.timestamp
        record["sessionId"] = point.sessionId.uuidString
        record["roomName"] = point.roomName
        record["floorIndex"] = point.floorIndex
        record["roomId"] = point.roomId?.uuidString
        record["homeId"] = point.homeId?.uuidString
        return record
    }

    private func recordToHeatmapPoint(_ record: CKRecord) -> HeatmapPoint {
        HeatmapPoint(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            x: record["x"] as? Double ?? 0,
            y: record["y"] as? Double ?? 0,
            z: record["z"] as? Double ?? 0,
            signalStrength: record["signalStrength"] as? Int ?? -70,
            latency: record["latency"] as? Double ?? 0,
            downloadSpeed: record["downloadSpeed"] as? Double ?? 0,
            timestamp: record["timestamp"] as? Date ?? .now,
            sessionId: UUID(uuidString: record["sessionId"] as? String ?? "") ?? UUID(),
            roomName: record["roomName"] as? String,
            floorIndex: record["floorIndex"] as? Int ?? 0,
            roomId: (record["roomId"] as? String).flatMap(UUID.init),
            homeId: (record["homeId"] as? String).flatMap(UUID.init)
        )
    }

    // MARK: - CloudKit Operations

    private func saveRecord(_ record: CKRecord) async throws {
        do {
            _ = try await privateDB.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict: server has a newer version. Use last-write-wins.
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                // Copy our values onto the server record and retry
                for key in record.allKeys() {
                    serverRecord[key] = record[key]
                }
                _ = try await privateDB.save(serverRecord)
            }
        }
    }

    private func saveBatch(_ records: [CKRecord]) async throws {
        // CloudKit batch limit is 400 records
        let batchSize = 400
        for chunk in stride(from: 0, to: records.count, by: batchSize) {
            let batch = Array(records[chunk..<min(chunk + batchSize, records.count)])
            let operation = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDB.add(operation)
            }
        }
    }

    private func deleteBatch(_ recordIDs: [CKRecord.ID]) async throws {
        let batchSize = 400
        for chunk in stride(from: 0, to: recordIDs.count, by: batchSize) {
            let batch = Array(recordIDs[chunk..<min(chunk + batchSize, recordIDs.count)])
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
            operation.isAtomic = false

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDB.add(operation)
            }
        }
    }

    private func uploadHeatmapPointsBatched(_ points: [HeatmapPoint]) async throws {
        let records = points.map { heatmapPointToRecord($0) }
        try await saveBatch(records)
    }

    private func fetchAll(recordType: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        var cursor: CKQueryOperation.Cursor? = nil
        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor = cursor {
                result = try await privateDB.records(continuingMatchFrom: cursor)
            } else {
                result = try await privateDB.records(matching: query)
            }

            for (_, recordResult) in result.matchResults {
                if case .success(let record) = recordResult {
                    allRecords.append(record)
                }
            }
            cursor = result.queryCursor
        } while cursor != nil

        return allRecords
    }
}

// MARK: - Error

enum CloudKitSyncError: LocalizedError {
    case iCloudUnavailable
    case syncDisabled

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable: return "iCloud is not available. Sign in to iCloud in Settings to enable backup."
        case .syncDisabled: return "iCloud sync is disabled."
        }
    }
}
