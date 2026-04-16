import Foundation
import ARKit
import CoreMotion
import Observation
import SwiftData
import os

/// Coordinates one end-to-end room scan. Consumes pose from `ARSessionService`,
/// Wi-Fi signal from `WiFiService`, BLE from `BLEService`, and a per-room
/// speed test. Emits grid-indexed painted cells, corner positions, doorways,
/// device placements, and `HeatmapPoint` samples tied to the room.
///
/// Replaces the fake timer-based "spin in place" rotation check with real
/// ARKit pose + CMMotionManager readings.
@Observable
@MainActor
final class RoomScanCoordinator {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "RoomScan")

    // MARK: - Phase

    enum Phase: Equatable {
        case notStarted
        case runningSpeedTest
        case waitingToStartWalk
        case walking
        case reviewingBeforeSave
        case saved
        case failed(String)
    }

    var phase: Phase = .notStarted

    // MARK: - Captured state

    /// Corner positions (x, z) in AR world coordinates (meters). Captured by the
    /// Corner button. Typical room has 4 corners.
    var corners: [SIMD2<Float>] = []

    /// Doorways captured during the walk. Index matches `doorwayConnections`.
    struct DoorwayCapture: Identifiable {
        let id = UUID()
        var position: SIMD2<Float>
        var connectsToOutside: Bool = false
        var connectsToUnknownRoom: Bool = true
        var connectsToRoomId: UUID? = nil
        var pendingRoomTypeRaw: String? = nil
        var pendingRoomName: String? = nil
        var connectsToOutsideTypeRaw: String? = nil
    }
    var doorways: [DoorwayCapture] = []

    /// Device placements (router/mesh nodes) captured during the walk.
    struct DeviceCapture: Identifiable {
        let id = UUID()
        var position: SIMD2<Float>
        var deviceTypeRaw: String = DeviceType.router.rawValue
        var label: String? = nil
        var isPrimaryRouter: Bool = false
    }
    var devices: [DeviceCapture] = []

    /// Grid cells the user has walked over. Gate for "Room Complete" button.
    /// Key: (xIndex, zIndex) using `gridResolution`.
    var paintedCells: Set<GridCell> = []

    /// Grid resolution in meters (0.5m default = 50cm tiles).
    let gridResolution: Float = 0.5

    /// Signal samples captured during the walk.
    struct Sample: Identifiable {
        let id = UUID()
        let timestamp: Date
        let position: SIMD2<Float>
        let signalStrength: Int
        let latency: Double
        let downloadSpeed: Double
    }
    var samples: [Sample] = []

    /// Distinct BLE devices seen during the walk.
    var bleDeviceIds: Set<UUID> = []

    // Speed test results for this room
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var pingMs: Double = 0
    var speedTestCompletedAt: Date? = nil

    // Configuration chosen at the start of the scan
    var roomType: RoomType = .livingRoom
    var customName: String? = nil
    var floorIndex: Int = 0

    // The home this scan belongs to
    var homeId: UUID?

    // Session identifier for this scan
    let sessionId = UUID()
    let roomId = UUID()

    // MARK: - Motion derived state

    /// Total distance walked (meters). Derived from ARKit pose.
    var walkedDistance: Float = 0

    /// Duration of the walk phase.
    var walkStartedAt: Date? = nil
    var walkDuration: TimeInterval {
        guard let start = walkStartedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Estimated room area (m²) from corner polygon — used to show live
    /// coverage percentage during the walk.
    var estimatedRoomArea: Float {
        let pts = corners.map { ($0.x, $0.y) }
        guard pts.count >= 3 else { return 0 }
        var sum: Float = 0
        for i in 0..<pts.count {
            let j = (i + 1) % pts.count
            sum += pts[i].0 * pts[j].1
            sum -= pts[j].0 * pts[i].1
        }
        return abs(sum) / 2
    }

    /// Live painted-coverage fraction (0–1). Gates the "Room Complete" button.
    var paintedCoverageFraction: Double {
        let area = estimatedRoomArea
        guard area > 0 else { return 0 }
        let paintedArea = Float(paintedCells.count) * gridResolution * gridResolution
        return Double(min(1.0, paintedArea / area))
    }

    /// How much coverage we need before Room Complete unlocks.
    let minimumCoverageFraction: Double = 0.30

    var canCompleteRoom: Bool {
        corners.count >= 3 && paintedCoverageFraction >= minimumCoverageFraction
    }

    // MARK: - Services

    private let arService: ARSessionService
    private let wifiService: WiFiService
    private let bleService: BLEService
    private let speedTestService: SpeedTestService

    private let motionManager = CMMotionManager()
    private let pedometer = CMPedometer()

    // Sampling cadence
    private var sampleTimer: Timer?
    private var lastWalkPosition: SIMD2<Float>?
    private var lastSampleTime: Date = .distantPast
    private let sampleInterval: TimeInterval = 1.5   // seconds between signal samples
    private let paintDistanceStep: Float = 0.15       // paint a cell every 15cm walked

    // MARK: - Init

    init(
        arService: ARSessionService = ARSessionService(),
        wifiService: WiFiService = WiFiService(),
        bleService: BLEService = BLEService(),
        speedTestService: SpeedTestService = SpeedTestService()
    ) {
        self.arService = arService
        self.wifiService = wifiService
        self.bleService = bleService
        self.speedTestService = speedTestService
    }

    // MARK: - Public API

    /// Start the room scan. Transitions to speedTest phase.
    func start(home: HomeConfiguration, roomType: RoomType, customName: String?, floorIndex: Int) {
        self.homeId = home.id
        self.roomType = roomType
        self.customName = customName
        self.floorIndex = floorIndex

        wifiService.requestLocationPermission()
        wifiService.startContinuousMonitoring()
        bleService.startScanning()
        arService.startSession()

        phase = .runningSpeedTest
        Task { await runSpeedTest() }
    }

    /// Begin the walking phase. Called after speed test completes and the user
    /// has tapped "Start walk".
    func beginWalk() {
        walkStartedAt = Date()
        lastWalkPosition = currentPosition()
        phase = .walking

        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSample() }
        }

        // Also tick frequently for paint updates
        Task { @MainActor in
            while phase == .walking {
                updatePaint()
                try? await Task.sleep(nanoseconds: 200_000_000) // 5 Hz
            }
        }
    }

    /// Mark the current device pose as a corner.
    func markCorner() {
        guard let p = currentPosition() else { return }
        corners.append(p)
    }

    /// Mark the current pose as a doorway. The caller then fills in connection info.
    @discardableResult
    func markDoorway() -> UUID? {
        guard let p = currentPosition() else { return nil }
        let cap = DoorwayCapture(position: p)
        doorways.append(cap)
        return cap.id
    }

    /// Mark the current pose as a device placement (router or mesh node).
    @discardableResult
    func markDevice(type: DeviceType, isPrimaryRouter: Bool, label: String?) -> UUID? {
        guard let p = currentPosition() else { return nil }
        let cap = DeviceCapture(
            position: p,
            deviceTypeRaw: type.rawValue,
            label: label,
            isPrimaryRouter: isPrimaryRouter
        )
        devices.append(cap)
        return cap.id
    }

    /// Transition to review state. Stops sampling but keeps AR running so the
    /// user can still see their progress.
    func completeWalk() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        phase = .reviewingBeforeSave
    }

    /// Persist the scan to SwiftData. Creates a `Room`, `Doorway`s, `DevicePlacement`s,
    /// and `HeatmapPoint`s all linked by `roomId`/`homeId`.
    func save(into modelContext: ModelContext) {
        guard let homeId else { return }

        let bleCount = bleService.discoveredDevices.count
        let grade = computeGrade()

        // Room
        let room = Room(
            id: roomId,
            homeId: homeId,
            createdAt: Date(),
            lastScannedAt: Date(),
            roomTypeRaw: roomType.rawValue,
            customName: customName,
            floorIndex: floorIndex,
            cornersJSON: encode(corners: corners),
            paintedCellsJSON: encode(cells: paintedCells),
            paintGridResolutionMeters: gridResolution,
            downloadMbps: downloadMbps,
            uploadMbps: uploadMbps,
            pingMs: pingMs,
            speedTestAt: speedTestCompletedAt,
            bleDeviceCount: bleCount,
            sessionId: sessionId,
            gradeScore: grade.score,
            gradeLetterRaw: grade.letter,
            deadZoneCount: grade.deadZoneCount,
            interferenceZoneCount: grade.interferenceCount,
            recommendationCount: grade.recommendationCount
        )
        modelContext.insert(room)

        // Doorways
        for d in doorways {
            let doorway = Doorway(
                roomId: roomId,
                x: d.position.x,
                z: d.position.y,
                connectsToRoomId: d.connectsToRoomId,
                connectsToOutside: d.connectsToOutside,
                connectsToUnknownRoom: d.connectsToUnknownRoom,
                connectsToOutsideTypeRaw: d.connectsToOutsideTypeRaw,
                pendingRoomTypeRaw: d.pendingRoomTypeRaw,
                pendingRoomName: d.pendingRoomName
            )
            modelContext.insert(doorway)
        }

        // Devices
        for dev in devices {
            let placement = DevicePlacement(
                homeId: homeId,
                roomId: roomId,
                x: dev.position.x,
                z: dev.position.y,
                deviceTypeRaw: dev.deviceTypeRaw,
                label: dev.label,
                isPrimaryRouter: dev.isPrimaryRouter
            )
            modelContext.insert(placement)
        }

        // Heatmap points
        for s in samples {
            let point = HeatmapPoint(
                x: s.position.x,
                y: 0,
                z: s.position.y,
                signalStrength: s.signalStrength,
                latency: s.latency,
                downloadSpeed: s.downloadSpeed,
                timestamp: s.timestamp,
                sessionId: sessionId,
                roomName: customName ?? roomType.label,
                floorIndex: floorIndex,
                roomId: roomId,
                homeId: homeId
            )
            modelContext.insert(point)
        }

        try? modelContext.save()
        phase = .saved

        // Stop services
        stopServices()
    }

    /// Cancel the scan and release resources.
    func cancel() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        stopServices()
        phase = .notStarted
    }

    // MARK: - Live readouts

    var currentSignalStrength: Int { wifiService.signalStrength }
    var currentSSID: String { wifiService.currentSSID }
    var currentBLECount: Int { bleService.discoveredDevices.count }

    /// The current device position in the horizontal plane (x, z). Returns
    /// nil if AR tracking is not yet usable.
    func currentPosition() -> SIMD2<Float>? {
        guard let p = arService.currentPosition() else { return nil }
        return SIMD2<Float>(p.x, p.z)
    }

    var isARTracking: Bool {
        switch arService.trackingState {
        case .normal: return true
        default: return false
        }
    }

    // MARK: - Internals

    private func runSpeedTest() async {
        if let result = await speedTestService.runFullTest() {
            downloadMbps = result.downloadSpeed
            uploadMbps = result.uploadSpeed
            pingMs = result.latency
            speedTestCompletedAt = Date()
            phase = .waitingToStartWalk
        } else {
            // Don't fail hard — let the walk proceed even if speed test failed.
            phase = .waitingToStartWalk
        }
    }

    private func stopServices() {
        wifiService.stopMonitoring()
        bleService.stopScanning()
        arService.pauseSession()
    }

    /// Capture a signal sample at the current position. Called by the timer.
    private func tickSample() {
        guard phase == .walking, let position = currentPosition() else { return }

        // Only sample while the user is actually moving, so we don't pile up
        // duplicate samples at one spot.
        if let last = lastWalkPosition {
            let dx = position.x - last.x
            let dy = position.y - last.y
            let moved = sqrt(dx * dx + dy * dy)
            if moved < 0.10 && Date().timeIntervalSince(lastSampleTime) < 4 { return }
        }

        let sample = Sample(
            timestamp: Date(),
            position: position,
            signalStrength: wifiService.signalStrength,
            latency: 0,
            downloadSpeed: downloadMbps
        )
        samples.append(sample)
        lastSampleTime = Date()

        // Track distinct BLE devices seen during the walk
        bleDeviceIds.formUnion(bleService.discoveredDevices.map { $0.id })
    }

    /// Update the painted-grid. Called at ~5 Hz while walking.
    private func updatePaint() {
        guard phase == .walking, let position = currentPosition() else { return }

        // Paint a small disk around the current position (accounts for the fact
        // that the user is standing in roughly a 30cm bubble, not a point).
        let radius: Float = 0.30
        let cellRadius = Int(ceil(radius / gridResolution))
        let cx = Int((position.x / gridResolution).rounded())
        let cz = Int((position.y / gridResolution).rounded())
        for dx in -cellRadius...cellRadius {
            for dz in -cellRadius...cellRadius {
                let dist = sqrt(Float(dx * dx + dz * dz)) * gridResolution
                if dist <= radius {
                    paintedCells.insert(GridCell(x: cx + dx, z: cz + dz))
                }
            }
        }

        // Track cumulative walked distance for display.
        if let last = lastWalkPosition {
            let dx = position.x - last.x
            let dy = position.y - last.y
            let moved = sqrt(dx * dx + dy * dy)
            if moved > 0.02 {
                walkedDistance += moved
                lastWalkPosition = position
            }
        } else {
            lastWalkPosition = position
        }
    }

    // MARK: - Grade calc (room-local)

    private struct RoomGrade {
        var score: Double
        var letter: String
        var deadZoneCount: Int
        var interferenceCount: Int
        var recommendationCount: Int
    }

    private func computeGrade() -> RoomGrade {
        // Simple, transparent formula for v1. CoveragePlanningService does the
        // fancier analysis for the whole-home report.
        let strengths = samples.map { $0.signalStrength }
        guard !strengths.isEmpty else {
            return RoomGrade(score: 0, letter: "F", deadZoneCount: 0, interferenceCount: 0, recommendationCount: 1)
        }
        let avg = Double(strengths.reduce(0, +)) / Double(strengths.count)

        // Convert dBm to 0–100: -45 dBm → 100, -90 dBm → 0
        let signalScore = max(0.0, min(100.0, ((avg + 90) / 45) * 100))

        // Speed component vs a generous baseline (200 Mbps = full points)
        let speedScore = max(0.0, min(100.0, (downloadMbps / 200.0) * 100))

        // BLE congestion penalty (0–15 point deduction)
        let blePenalty = min(15.0, Double(bleDeviceIds.count) * 0.5)

        let combined = (signalScore * 0.65 + speedScore * 0.35) - blePenalty
        let final = max(0, min(100, combined))

        let letter: String
        switch final {
        case 90...:   letter = "A"
        case 80..<90: letter = "B"
        case 70..<80: letter = "C"
        case 60..<70: letter = "D"
        default:      letter = "F"
        }

        let deadZones = strengths.filter { $0 < -80 }.count
        let interference = bleDeviceIds.count > 15 ? 1 : 0
        let recommendations = (final < 80 ? 1 : 0) + (deadZones > 2 ? 1 : 0)

        return RoomGrade(
            score: final,
            letter: letter,
            deadZoneCount: deadZones,
            interferenceCount: interference,
            recommendationCount: recommendations
        )
    }

    // MARK: - Encoding helpers

    private func encode(corners: [SIMD2<Float>]) -> String {
        let arr = corners.map { [$0.x, $0.y] }
        if let data = try? JSONEncoder().encode(arr),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "[]"
    }

    private func encode(cells: Set<GridCell>) -> String {
        let arr = cells.map { [$0.x, $0.z] }
        if let data = try? JSONEncoder().encode(arr),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "[]"
    }
}

// MARK: - Grid Cell

struct GridCell: Hashable {
    let x: Int
    let z: Int
}
