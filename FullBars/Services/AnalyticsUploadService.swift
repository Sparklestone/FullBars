import Foundation
import SwiftData
import os

/// Uploads anonymized scan data to Supabase after each completed scan.
/// All data is aggregated and anonymized — no PII, no exact addresses.
/// Location is ZIP code only.
///
/// Upload flow:
/// 1. Scan completes → GradingService produces grades
/// 2. AnalyticsUploadService.uploadScanData() called
/// 3. Builds session + room + weak spot payloads
/// 4. Uploads to Supabase in a single batch
/// 5. Fetches matching ad placements for the user's context
final class AnalyticsUploadService {
    static let shared = AnalyticsUploadService()

    private let logger = Logger(subsystem: "com.fullbars.app", category: "AnalyticsUpload")
    private let client = SupabaseClient.shared
    private let retryQueue = DispatchQueue(label: "com.fullbars.analytics.retry")

    /// Key for storing failed uploads that should be retried.
    private let pendingUploadsKey = "pendingAnalyticsUploads"

    // MARK: - Upload Scan Data

    /// Uploads a complete scan session with all rooms and weak spots.
    /// Call this after grading is complete for a home.
    @discardableResult
    func uploadScanData(
        home: HomeConfiguration,
        rooms: [Room],
        heatmapPoints: [HeatmapPoint],
        devices: [DevicePlacement],
        grade: SpaceGrade
    ) async -> ScanSessionPayload? {
        guard home.dataCollectionOptIn else {
            logger.info("Data collection not opted in — skipping upload")
            return nil
        }

        guard SupabaseConfig.isConfigured else {
            logger.info("Supabase not configured — skipping upload")
            return nil
        }

        guard !home.zipCode.isEmpty else {
            logger.warning("No ZIP code set — skipping analytics upload")
            return nil
        }

        // Build payloads
        let sessionPayload = buildSessionPayload(home: home, rooms: rooms, points: heatmapPoints, devices: devices, grade: grade)
        let roomPayloads = buildRoomPayloads(sessionId: sessionPayload.id, rooms: rooms, points: heatmapPoints, devices: devices)
        let weakSpotPayloads = buildWeakSpotPayloads(sessionId: sessionPayload.id, roomPayloads: roomPayloads, rooms: rooms, points: heatmapPoints, devices: devices)

        do {
            // Upload session first (foreign key parent)
            let _ = try await client.insert(table: "scan_sessions", row: sessionPayload)
            logger.info("Uploaded scan session \(sessionPayload.id.uuidString)")

            // Upload rooms
            if !roomPayloads.isEmpty {
                try await client.insertBatch(table: "room_scans", rows: roomPayloads)
                logger.info("Uploaded \(roomPayloads.count) room scans")
            }

            // Upload weak spots
            if !weakSpotPayloads.isEmpty {
                try await client.insertBatch(table: "dead_zones", rows: weakSpotPayloads)
                logger.info("Uploaded \(weakSpotPayloads.count) weak spots")
            }

            return sessionPayload

        } catch {
            logger.error("Analytics upload failed: \(error.localizedDescription)")
            // Queue for retry on next app launch
            queueForRetry(session: sessionPayload, rooms: roomPayloads, weakSpots: weakSpotPayloads)
            return nil
        }
    }

    // MARK: - Fetch Matching Ads

    /// Fetches ad placements that match the user's scan context.
    func fetchMatchingAds(
        zipCode: String,
        ispName: String,
        dwellingType: String,
        weakSpotCount: Int,
        downloadDeficitPct: Double,
        weakCoveragePct: Double
    ) async -> [AdPlacementResponse] {
        guard SupabaseConfig.isConfigured else { return [] }

        let params = MatchAdsParams(
            pZip: zipCode,
            pIsp: ispName,
            pDwelling: dwellingType.lowercased().replacingOccurrences(of: " ", with: "_"),
            pDeadZones: weakSpotCount,
            pDownloadPct: downloadDeficitPct,
            pWeakCoveragePct: weakCoveragePct
        )

        do {
            return try await client.rpc(function: "match_ads", params: params, as: [AdPlacementResponse].self)
        } catch {
            logger.error("Failed to fetch ads: \(error.localizedDescription)")
            return []
        }
    }

    /// Record that an ad was shown to the user.
    func recordImpression(placementId: UUID, sessionId: UUID?, zipCode: String, ispName: String, weakSpotCount: Int, grade: String, deviceHash: String) async {
        guard SupabaseConfig.isConfigured else { return }

        let impression = AdImpressionPayload(
            placementId: placementId,
            sessionId: sessionId,
            zipCode: zipCode,
            ispName: ispName,
            deadZoneCount: weakSpotCount,
            overallGrade: grade.lowercased(),
            deviceHash: deviceHash
        )

        do {
            let _ = try await client.insert(table: "ad_impressions", row: impression)
        } catch {
            logger.error("Failed to record impression: \(error.localizedDescription)")
        }
    }

    /// Record that a user tapped an ad CTA.
    func recordClick(impressionId: UUID, deviceHash: String) async {
        guard SupabaseConfig.isConfigured else { return }

        let click = AdClickPayload(impressionId: impressionId, deviceHash: deviceHash)
        do {
            let _ = try await client.insert(table: "ad_clicks", row: click)
        } catch {
            logger.error("Failed to record click: \(error.localizedDescription)")
        }
    }

    // MARK: - Retry Failed Uploads

    /// Flushes the retry queue. Call when the user opts out of data collection
    /// so previously queued uploads are never sent.
    func flushPendingUploads() {
        UserDefaults.standard.removeObject(forKey: pendingUploadsKey)
        logger.info("Flushed pending analytics uploads (user opted out)")
    }

    /// Retries any uploads that failed previously. Call on app launch.
    /// Skips retry if data collection is currently opted out.
    func retryPendingUploads() async {
        guard SupabaseConfig.isConfigured else { return }

        // Respect current opt-out: if the user turned off data collection,
        // flush the queue instead of retrying.
        if !UserDefaults.standard.bool(forKey: "dataCollectionOptIn") {
            flushPendingUploads()
            return
        }

        guard let data = UserDefaults.standard.data(forKey: pendingUploadsKey),
              let pending = try? JSONDecoder().decode([PendingUpload].self, from: data),
              !pending.isEmpty else {
            return
        }

        logger.info("Retrying \(pending.count) pending uploads")

        var stillPending: [PendingUpload] = []
        for upload in pending {
            do {
                let _ = try await client.insert(table: "scan_sessions", row: upload.session)
                if !upload.rooms.isEmpty {
                    try await client.insertBatch(table: "room_scans", rows: upload.rooms)
                }
                if !upload.weakSpots.isEmpty {
                    try await client.insertBatch(table: "dead_zones", rows: upload.weakSpots)
                }
                logger.info("Retry succeeded for session \(upload.session.id.uuidString)")
            } catch {
                logger.warning("Retry failed for session \(upload.session.id.uuidString)")
                stillPending.append(upload)
            }
        }

        if stillPending.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingUploadsKey)
        } else if let data = try? JSONEncoder().encode(stillPending) {
            UserDefaults.standard.set(data, forKey: pendingUploadsKey)
        }
    }

    // MARK: - Payload Builders

    private func buildSessionPayload(
        home: HomeConfiguration,
        rooms: [Room],
        points: [HeatmapPoint],
        devices: [DevicePlacement],
        grade: SpaceGrade
    ) -> ScanSessionPayload {
        let coverage = DataCollectionService.coverageBreakdown(from: points)
        let totalWeakSpots = rooms.reduce(0) { $0 + $1.deadZoneCount }

        // Aggregate speed from room-level tests
        let roomsWithSpeed = rooms.filter { $0.downloadMbps > 0 }
        let avgDownload = roomsWithSpeed.isEmpty ? 0 : roomsWithSpeed.map(\.downloadMbps).reduce(0, +) / Double(roomsWithSpeed.count)
        let avgUpload = roomsWithSpeed.isEmpty ? 0 : roomsWithSpeed.map(\.uploadMbps).reduce(0, +) / Double(roomsWithSpeed.count)
        let avgLatency = roomsWithSpeed.isEmpty ? 0 : roomsWithSpeed.map(\.pingMs).reduce(0, +) / Double(roomsWithSpeed.count)

        return ScanSessionPayload(
            id: UUID(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            zipCode: home.zipCode,
            dwellingType: home.dwellingType.lowercased().replacingOccurrences(of: " ", with: "_"),
            squareFootage: home.squareFootage,
            floorCount: home.numberOfFloors,
            occupantCount: home.numberOfPeople,
            ispName: home.ispName,
            ispPromisedDownloadMbps: home.ispPromisedDownloadMbps,
            ispPromisedUploadMbps: home.ispPromisedUploadMbps,
            measuredDownloadMbps: avgDownload,
            measuredUploadMbps: avgUpload,
            measuredLatencyMs: avgLatency,
            measuredJitterMs: 0,
            coverageStrongPct: coverage.strong,
            coverageModeratePct: coverage.moderate,
            coverageWeakPct: coverage.weak,
            totalPointsSampled: points.count,
            hasMeshNetwork: home.hasMeshNetwork,
            meshNodeCount: home.meshNodeCount,
            wifiDeviceCount: devices.filter { $0.deviceType == .router || $0.deviceType == .meshNode }.count,
            bleDeviceCount: 0,
            overallGrade: grade.grade.rawValue.lowercased(),
            overallScore: grade.overallScore,
            roomCount: rooms.count,
            deadZoneCount: totalWeakSpots
        )
    }

    private func buildRoomPayloads(
        sessionId: UUID,
        rooms: [Room],
        points: [HeatmapPoint],
        devices: [DevicePlacement]
    ) -> [RoomScanPayload] {
        rooms.map { room in
            let roomPoints = points.filter { $0.roomId == room.id }
            let coverage = DataCollectionService.coverageBreakdown(from: roomPoints)
            let signals = roomPoints.map(\.signalStrength)
            let avgSignal = signals.isEmpty ? -70 : signals.reduce(0, +) / signals.count
            let minSignal = signals.min() ?? -90
            let maxSignal = signals.max() ?? -40

            let stdDev: Double
            if signals.count > 1 {
                let mean = Double(avgSignal)
                let variance = signals.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(signals.count - 1)
                stdDev = sqrt(variance)
            } else {
                stdDev = 0
            }

            let roomDevices = devices.filter { $0.roomId == room.id }

            return RoomScanPayload(
                id: UUID(),
                sessionId: sessionId,
                roomType: room.roomTypeRaw.lowercased().replacingOccurrences(of: " ", with: "_"),
                floorIndex: room.floorIndex,
                downloadMbps: room.downloadMbps,
                uploadMbps: room.uploadMbps,
                pingMs: room.pingMs,
                avgSignalDbm: avgSignal,
                minSignalDbm: minSignal,
                maxSignalDbm: maxSignal,
                signalStdDev: stdDev,
                pointCount: roomPoints.count,
                coverageStrongPct: coverage.strong,
                coverageModeratePct: coverage.moderate,
                coverageWeakPct: coverage.weak,
                areaSqMeters: Double(room.approximateAreaSquareMeters),
                gradeLetter: room.gradeLetterRaw.lowercased(),
                gradeScore: room.gradeScore,
                deadZoneCount: room.deadZoneCount,
                routerCount: roomDevices.filter { $0.deviceType == .router }.count,
                meshNodeCount: roomDevices.filter { $0.deviceType == .meshNode }.count,
                deviceCount: roomDevices.filter { $0.deviceType != .router && $0.deviceType != .meshNode }.count
            )
        }
    }

    private func buildWeakSpotPayloads(
        sessionId: UUID,
        roomPayloads: [RoomScanPayload],
        rooms: [Room],
        points: [HeatmapPoint],
        devices: [DevicePlacement]
    ) -> [DeadZonePayload] {
        var payloads: [DeadZonePayload] = []

        for (index, room) in rooms.enumerated() {
            let roomPoints = points.filter { $0.roomId == room.id }
            guard !roomPoints.isEmpty else { continue }

            let weakSpots = CoveragePlanningService.detectWeakSpots(points: roomPoints)
            let roomPayloadId = index < roomPayloads.count ? roomPayloads[index].id : UUID()

            // Compute room bounds for normalization
            let corners = room.corners
            let xs = corners.map(\.0)
            let zs = corners.map(\.1)
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 1
            let minZ = zs.min() ?? 0
            let maxZ = zs.max() ?? 1
            let rangeX = max(maxX - minX, 0.01)
            let rangeZ = max(maxZ - minZ, 0.01)

            let roomDevices = devices.filter { $0.roomId == room.id }

            for dz in weakSpots {
                let relX = Double((dz.centerX - minX) / rangeX).clamped(to: 0...1)
                let relZ = Double((dz.centerZ - minZ) / rangeZ).clamped(to: 0...1)

                // Check if any non-network device is near this weak spot
                let proximityMargin: Double = 1.5
                let hasDeviceNearby = roomDevices.contains { dev in
                    guard dev.deviceType != .router && dev.deviceType != .meshNode else { return false }
                    let dist = sqrt(pow(dev.x - dz.centerX, 2) + pow(dev.z - dz.centerZ, 2))
                    return Double(dist) <= Double(dz.radius) + proximityMargin
                }

                let nearbyType: String? = hasDeviceNearby ? roomDevices.first { dev in
                    guard dev.deviceType != .router && dev.deviceType != .meshNode else { return false }
                    let dist = sqrt(pow(dev.x - dz.centerX, 2) + pow(dev.z - dz.centerZ, 2))
                    return Double(dist) <= Double(dz.radius) + proximityMargin
                }?.deviceTypeRaw.lowercased() : nil

                payloads.append(DeadZonePayload(
                    id: UUID(),
                    sessionId: sessionId,
                    roomScanId: roomPayloadId,
                    severity: dz.severity.rawValue.lowercased(),
                    radiusMeters: Double(dz.radius),
                    relativeX: relX,
                    relativeZ: relZ,
                    hasDeviceNearby: hasDeviceNearby,
                    nearbyDeviceType: nearbyType
                ))
            }
        }

        return payloads
    }

    // MARK: - Retry Queue

    private func queueForRetry(session: ScanSessionPayload, rooms: [RoomScanPayload], weakSpots: [DeadZonePayload]) {
        let pending = PendingUpload(session: session, rooms: rooms, weakSpots: weakSpots)
        var existing: [PendingUpload] = []
        if let data = UserDefaults.standard.data(forKey: pendingUploadsKey),
           let decoded = try? JSONDecoder().decode([PendingUpload].self, from: data) {
            existing = decoded
        }
        existing.append(pending)
        // Keep max 10 pending uploads to avoid unbounded storage
        if existing.count > 10 {
            let dropped = existing.count - 10
            logger.warning("Retry queue full — dropping \(dropped) oldest pending upload(s)")
            existing = Array(existing.suffix(10))
        }
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: pendingUploadsKey)
        }
    }
}

// MARK: - Float Clamping

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Upload Payloads (Codable → Supabase JSON)

struct ScanSessionPayload: Codable {
    let id: UUID
    let appVersion: String
    let zipCode: String
    let dwellingType: String
    let squareFootage: Int
    let floorCount: Int
    let occupantCount: Int
    let ispName: String
    let ispPromisedDownloadMbps: Double
    let ispPromisedUploadMbps: Double
    let measuredDownloadMbps: Double
    let measuredUploadMbps: Double
    let measuredLatencyMs: Double
    let measuredJitterMs: Double
    let coverageStrongPct: Double
    let coverageModeratePct: Double
    let coverageWeakPct: Double
    let totalPointsSampled: Int
    let hasMeshNetwork: Bool
    let meshNodeCount: Int
    let wifiDeviceCount: Int
    let bleDeviceCount: Int
    let overallGrade: String
    let overallScore: Double
    let roomCount: Int
    let deadZoneCount: Int
}

struct RoomScanPayload: Codable {
    let id: UUID
    let sessionId: UUID
    let roomType: String
    let floorIndex: Int
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let avgSignalDbm: Int
    let minSignalDbm: Int
    let maxSignalDbm: Int
    let signalStdDev: Double
    let pointCount: Int
    let coverageStrongPct: Double
    let coverageModeratePct: Double
    let coverageWeakPct: Double
    let areaSqMeters: Double
    let gradeLetter: String
    let gradeScore: Double
    let deadZoneCount: Int
    let routerCount: Int
    let meshNodeCount: Int
    let deviceCount: Int
}

struct DeadZonePayload: Codable {
    let id: UUID
    let sessionId: UUID
    let roomScanId: UUID
    let severity: String
    let radiusMeters: Double
    let relativeX: Double
    let relativeZ: Double
    let hasDeviceNearby: Bool
    let nearbyDeviceType: String?
}

struct PendingUpload: Codable {
    let session: ScanSessionPayload
    let rooms: [RoomScanPayload]
    let weakSpots: [DeadZonePayload]
}

// MARK: - Ad Response Models

struct AdPlacementResponse: Codable, Identifiable {
    let id: UUID
    let partnerId: UUID
    let headline: String
    let bodyText: String
    let ctaText: String
    let ctaUrl: String
    let discountCode: String?
    let badgeText: String?
    let isHouseAd: Bool

    /// Partner info (joined from ad_partners)
    var partnerName: String?
    var partnerLogoUrl: String?
    var partnerType: String?
}

struct AdImpressionPayload: Codable {
    let placementId: UUID
    let sessionId: UUID?
    let zipCode: String
    let ispName: String?
    let deadZoneCount: Int
    let overallGrade: String
    let deviceHash: String
}

struct AdClickPayload: Codable {
    let impressionId: UUID
    let deviceHash: String
}

struct MatchAdsParams: Codable {
    let pZip: String
    let pIsp: String
    let pDwelling: String
    let pDeadZones: Int
    let pDownloadPct: Double
    let pWeakCoveragePct: Double
}
