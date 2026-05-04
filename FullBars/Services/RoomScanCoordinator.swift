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
        case atEntrance           // Step 1: stand at the room entrance
        case markingCorners       // Step 2: walk to each corner (RSSI snapshot at each)
        case walkToCenter         // Step 3a: walk to approximate center
        case runningSpeedTest     // Step 3b: speed test at center
        case routerQuestion       // Step 4: "Is there a router/mesh in this room?"
        case placingRouter        // Step 4b: pin the router location
        case deepScan             // Optional Pro step: paint the floor for high-res data
        case reviewingBeforeSave
        case saved
        case failed(String)
    }

    /// Total number of standard steps (excluding optional deep scan).
    let totalSteps = 4

    var phase: Phase = .notStarted

    /// The current guided step number (1–4) for the step indicator.
    var currentStepNumber: Int {
        switch phase {
        case .atEntrance: return 1
        case .markingCorners: return 2
        case .walkToCenter, .runningSpeedTest: return 3
        case .routerQuestion, .placingRouter: return 4
        case .deepScan: return 5  // bonus step
        default: return 0
        }
    }

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
    let gridResolution: Double = 0.5

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
        let paintedArea = Double(paintedCells.count) * gridResolution * gridResolution
        return min(1.0, paintedArea / Double(area))
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

    /// Start the room scan. Begins AR/WiFi/BLE services and enters Step 1 (entrance).
    func start(home: HomeConfiguration, roomType: RoomType, customName: String?, floorIndex: Int) {
        self.homeId = home.id
        self.roomType = roomType
        self.customName = customName
        self.floorIndex = floorIndex

        wifiService.requestLocationPermission()
        wifiService.startContinuousMonitoring()
        bleService.startScanning()
        arService.startSession()

        walkStartedAt = Date()
        lastWalkPosition = currentPosition()
        phase = .atEntrance

        // Start signal sampling immediately — we collect data across all walk steps
        startSampling()
        // Start paint tracking from the very beginning so we capture coverage
        // as the user walks between steps
        startBackgroundPainting()
    }

    /// User pressed "Begin Scan" at the entrance — capture entrance sample and move to corners.
    func beginFromEntrance() {
        // Capture an RSSI snapshot at the entrance
        captureRSSISnapshot(label: "entrance")
        phase = .markingCorners
    }

    /// Transition from Step 2 (corners) to Step 3 (walk to center).
    func finishCorners() {
        phase = .walkToCenter
    }

    /// User is at the approximate center — begin speed test.
    func confirmAtCenter() {
        // Capture an RSSI snapshot at center
        captureRSSISnapshot(label: "center")
        phase = .runningSpeedTest
        Task { await runSpeedTest() }
    }

    /// Answer "No" to router question — skip to review (or deep scan offer).
    func noRouterInRoom() {
        finishStandardScan()
    }

    /// Answer "Yes" to router question — show pin placement.
    func yesRouterInRoom() {
        phase = .placingRouter
    }

    /// Finish placing router pin — move to review (or deep scan offer).
    func finishRouterPlacement() {
        finishStandardScan()
    }

    /// Begin the optional Pro deep scan (paint the floor).
    func beginDeepScan() {
        phase = .deepScan
    }

    /// Finish the deep scan and go to review.
    func finishDeepScan() {
        stopBackgroundPainting()
        phase = .reviewingBeforeSave
    }

    /// Skip deep scan and go straight to review.
    func skipDeepScan() {
        stopBackgroundPainting()
        phase = .reviewingBeforeSave
    }

    /// Whether this scan is eligible for the deep scan option.
    /// Set by the view based on subscription status.
    var deepScanAvailable: Bool = false

    /// Whether the deep scan offer has been shown (to avoid re-showing on back nav).
    var deepScanOffered: Bool = false

    /// Go back one step.
    func goBackOneStep() {
        switch phase {
        case .atEntrance:
            cancel()
        case .markingCorners:
            phase = .atEntrance
        case .walkToCenter:
            phase = .markingCorners
        case .routerQuestion:
            // Can't go back past the speed test, go to walkToCenter
            phase = .walkToCenter
        case .placingRouter:
            phase = .routerQuestion
        case .deepScan:
            phase = .routerQuestion
        default:
            break
        }
    }

    // MARK: - Background painting

    private var paintingTask: Task<Void, Never>?

    private func startBackgroundPainting() {
        paintingTask = Task { @MainActor in
            while !Task.isCancelled {
                updatePaint()
                try? await Task.sleep(nanoseconds: 200_000_000) // 5 Hz
            }
        }
    }

    private func stopBackgroundPainting() {
        paintingTask?.cancel()
        paintingTask = nil
    }

    // MARK: - RSSI snapshots at key points

    /// Quick signal reading at a specific location (entrance, corner, center).
    private func captureRSSISnapshot(label: String) {
        guard let position = currentPosition() else { return }
        let sample = Sample(
            timestamp: Date(),
            position: position,
            signalStrength: wifiService.signalStrength,
            latency: 0,
            downloadSpeed: 0
        )
        samples.append(sample)
    }

    /// Whether the deep scan offer should be shown (set by finishStandardScan, read by the view).
    var showDeepScanOffer: Bool = false

    /// Called when standard scan steps are done — decides whether to offer deep scan or go to review.
    private func finishStandardScan() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        stopBackgroundPainting()
        if !deepScanOffered {
            deepScanOffered = true
            showDeepScanOffer = true
        }
        phase = .reviewingBeforeSave
    }

    private func startSampling() {
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSample() }
        }
    }

    /// Capture an RSSI snapshot at a corner position (called by the view after marking a corner).
    func captureCornerSignal() {
        captureRSSISnapshot(label: "corner")
    }

    /// Mark the current device pose as a corner.
    func markCorner() {
        guard let p = currentPosition() else { return }
        corners.append(p)
        if corners.count >= 3 {
            corners = sortedConvexPolygon(corners)
        }
    }

    /// Sort points by angle from centroid to prevent self-intersecting (hourglass) polygons
    /// when users tap corners out of order.
    private func sortedConvexPolygon(_ pts: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let cx = pts.map(\.x).reduce(0, +) / Float(pts.count)
        let cy = pts.map(\.y).reduce(0, +) / Float(pts.count)
        return pts.sorted { a, b in
            atan2(a.y - cy, a.x - cx) < atan2(b.y - cy, b.x - cx)
        }
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

    // MARK: - Removal (long-press delete)

    func removeCorner(at index: Int) {
        guard corners.indices.contains(index) else { return }
        corners.remove(at: index)
    }

    func removeDoorway(id: UUID) {
        doorways.removeAll { $0.id == id }
    }

    func removeDevice(id: UUID) {
        devices.removeAll { $0.id == id }
    }

    /// Whether the floor has enough painted coverage for the deep scan Done button.
    var canFinishPainting: Bool {
        corners.count >= 3 && paintedCoverageFraction >= minimumCoverageFraction
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
            deadZoneCount: grade.weakSpotCount,
            interferenceZoneCount: grade.interferenceCount,
            recommendationCount: grade.recommendationCount
        )
        modelContext.insert(room)

        // Doorways
        for d in doorways {
            let doorway = Doorway(
                roomId: roomId,
                x: Double(d.position.x),
                z: Double(d.position.y),
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
                x: Double(dev.position.x),
                z: Double(dev.position.y),
                deviceTypeRaw: dev.deviceTypeRaw,
                label: dev.label,
                isPrimaryRouter: dev.isPrimaryRouter
            )
            modelContext.insert(placement)
        }

        // Heatmap points
        for s in samples {
            let point = HeatmapPoint(
                x: Double(s.position.x),
                y: 0,
                z: Double(s.position.y),
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
        stopBackgroundPainting()
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
        }
        // Move to router question (step 4)
        phase = .routerQuestion
    }

    private func stopServices() {
        wifiService.stopMonitoring()
        bleService.stopScanning()
        arService.pauseSession()
    }

    /// Capture a signal sample at the current position. Called by the timer.
    /// Samples are collected during ALL walk phases (entrance, corners, center, router, deep scan).
    private func tickSample() {
        let walkPhases: [Phase] = [.atEntrance, .markingCorners, .walkToCenter, .routerQuestion, .placingRouter, .deepScan]
        guard walkPhases.contains(phase), let position = currentPosition() else { return }

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
    /// Now runs during ALL walk phases so we capture coverage passively.
    private func updatePaint() {
        let paintPhases: [Phase] = [.atEntrance, .markingCorners, .walkToCenter, .routerQuestion, .placingRouter, .deepScan]
        guard paintPhases.contains(phase), let position = currentPosition() else { return }

        // Paint a small disk around the current position (accounts for the fact
        // that the user is standing in roughly a 30cm bubble, not a point).
        let radius: Double = 0.30
        let cellRadius = Int(ceil(radius / gridResolution))
        let cx = Int((Double(position.x) / gridResolution).rounded())
        let cz = Int((Double(position.y) / gridResolution).rounded())
        for dx in -cellRadius...cellRadius {
            for dz in -cellRadius...cellRadius {
                let dist = sqrt(Double(dx * dx + dz * dz)) * gridResolution
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

    private struct ScanRoomGrade {
        var score: Double
        var letter: String
        var weakSpotCount: Int
        var interferenceCount: Int
        var recommendationCount: Int
    }

    private func computeGrade() -> ScanRoomGrade {
        // Consolidated grading formula — aligned with GradingService weights.
        // Signal 40%, Speed 30%, Latency 20%, BLE interference 10%.
        let strengths = samples.map { $0.signalStrength }
        guard !strengths.isEmpty else {
            return ScanRoomGrade(score: 0, letter: "F", weakSpotCount: 0, interferenceCount: 0, recommendationCount: 1)
        }
        let avg = Double(strengths.reduce(0, +)) / Double(strengths.count)

        // Signal score: -30 dBm → 100 (excellent), -85 dBm → 0 (dead)
        let signalScore = max(0.0, min(100.0, ((avg + 85) / 55) * 100))

        // Speed score: 100+ Mbps = 100, scaled linearly to 0
        let speedScore: Double
        if downloadMbps > 0 {
            switch downloadMbps {
            case 100...: speedScore = 100
            case 50..<100: speedScore = 80 + (downloadMbps - 50) / 50 * 20
            case 25..<50: speedScore = 65 + (downloadMbps - 25) / 25 * 15
            case 10..<25: speedScore = 50 + (downloadMbps - 10) / 15 * 15
            default: speedScore = max(0, downloadMbps / 10 * 50)
            }
        } else {
            speedScore = 50 // Neutral default when no speed test run
        }

        // Latency score from ping
        let latencyScore: Double
        if pingMs > 0 {
            switch pingMs {
            case 0..<20: latencyScore = 100
            case 20..<50: latencyScore = 85
            case 50..<100: latencyScore = 70
            case 100..<200: latencyScore = 50
            default: latencyScore = 30
            }
        } else {
            latencyScore = 70 // Default when ping not measured
        }

        // BLE interference: fewer is better (0–5 = great, 30+ = congested)
        let bleScore: Double
        switch bleDeviceIds.count {
        case 0..<5: bleScore = 100
        case 5..<10: bleScore = 85
        case 10..<20: bleScore = 70
        case 20..<30: bleScore = 55
        default: bleScore = 40
        }

        // Weighted combination: signal 40%, speed 30%, latency 20%, BLE 10%
        let combined = signalScore * 0.40 + speedScore * 0.30 + latencyScore * 0.20 + bleScore * 0.10
        let finalScore = max(0, min(100, combined))

        let letter: String
        switch finalScore {
        case 90...:   letter = "A"
        case 80..<90: letter = "B"
        case 70..<80: letter = "C"
        case 60..<70: letter = "D"
        default:      letter = "F"
        }

        let weakSpots = strengths.filter { $0 < -75 }.count
        let interference = bleDeviceIds.count > 15 ? 1 : 0
        let recommendations = (finalScore < 80 ? 1 : 0) + (weakSpots > 2 ? 1 : 0)

        return ScanRoomGrade(
            score: finalScore,
            letter: letter,
            weakSpotCount: weakSpots,
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
