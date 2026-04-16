import Foundation
import Observation
import os

#if canImport(RoomPlan)
import RoomPlan
#endif

// MARK: - Room Data Structures (works on all devices)

struct DetectedRoom: Identifiable, Codable {
    var id = UUID()
    var name: String
    var corners: [CGPoint]
    var area: Double // sq meters

    var center: CGPoint {
        guard !corners.isEmpty else { return .zero }
        let sumX = corners.map(\.x).reduce(0, +)
        let sumY = corners.map(\.y).reduce(0, +)
        return CGPoint(x: sumX / CGFloat(corners.count), y: sumY / CGFloat(corners.count))
    }
}

struct DetectedWall: Identifiable, Codable {
    var id = UUID()
    var start: CGPoint
    var end: CGPoint
}

struct DetectedDoor: Identifiable, Codable {
    var id = UUID()
    var position: CGPoint
    var width: Double
}

struct DetectedWindow: Identifiable, Codable {
    var id = UUID()
    var position: CGPoint
    var width: Double
}

/// Wraps RoomPlan API for LiDAR devices and provides a simpler plane-based
/// fallback for non-LiDAR iPhones.
@Observable
final class RoomPlanServiceWrapper: NSObject {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "RoomPlan")

    var isScanning = false
    var rooms: [DetectedRoom] = []
    var walls: [DetectedWall] = []
    var doors: [DetectedDoor] = []
    var windows: [DetectedWindow] = []
    var isLiDARAvailable = false
    var errorMessage: String?

    #if canImport(RoomPlan)
    private var roomCaptureSession: RoomCaptureSession?
    #endif

    override init() {
        super.init()
        #if canImport(RoomPlan)
        checkAvailability()
        #endif
    }

    #if canImport(RoomPlan)
    private func checkAvailability() {
        if #available(iOS 17.0, *) {
            isLiDARAvailable = RoomCaptureSession.isSupported
        }
    }
    #endif

    func startScanning() {
        rooms.removeAll()
        walls.removeAll()
        doors.removeAll()
        windows.removeAll()
        isScanning = true
        errorMessage = nil

        #if canImport(RoomPlan)
        if isLiDARAvailable {
            startRoomPlanCapture()
            return
        }
        #endif

        Self.logger.info("RoomPlan not available; using plane detection fallback")
    }

    func stopScanning() {
        isScanning = false

        #if canImport(RoomPlan)
        roomCaptureSession?.stop()
        #endif
    }

    // MARK: - Plane Detection Fallback

    /// Called from ARSessionService when new planes are detected (non-LiDAR path)
    func addDetectedPlane(center: CGPoint, extent: CGSize, isVertical: Bool) {
        if isVertical {
            // Treat vertical planes as walls
            let halfWidth = extent.width / 2
            let wall = DetectedWall(
                start: CGPoint(x: center.x - halfWidth, y: center.y),
                end: CGPoint(x: center.x + halfWidth, y: center.y)
            )
            walls.append(wall)
        }
        // Horizontal planes contribute to room boundary estimation
    }

    // MARK: - RoomPlan Integration (LiDAR)

    #if canImport(RoomPlan)
    private func startRoomPlanCapture() {
        let session = RoomCaptureSession()
        session.delegate = self
        self.roomCaptureSession = session

        let config = RoomCaptureSession.Configuration()
        session.run(configuration: config)

        Self.logger.info("RoomPlan capture started")
    }
    #endif
}

// MARK: - RoomCaptureSessionDelegate

#if canImport(RoomPlan)
extension RoomPlanServiceWrapper: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        // Convert CapturedRoom structures to our models
        processRoom(room)
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: (any Error)?) {
        isScanning = false
        if let error = error {
            Self.logger.error("RoomPlan ended with error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        Self.logger.info("RoomPlan capture ended. Walls: \(self.walls.count), Doors: \(self.doors.count)")
    }

    private func processRoom(_ room: CapturedRoom) {
        // Process walls
        walls = room.walls.map { wall in
            let center = wall.transform.columns.3
            let extent = wall.dimensions
            return DetectedWall(
                start: CGPoint(x: Double(center.x - extent.x / 2), y: Double(center.z)),
                end: CGPoint(x: Double(center.x + extent.x / 2), y: Double(center.z))
            )
        }

        // Process doors
        doors = room.doors.map { door in
            let center = door.transform.columns.3
            return DetectedDoor(
                position: CGPoint(x: Double(center.x), y: Double(center.z)),
                width: Double(door.dimensions.x)
            )
        }

        // Process windows
        windows = room.windows.map { window in
            let center = window.transform.columns.3
            return DetectedWindow(
                position: CGPoint(x: Double(center.x), y: Double(center.z)),
                width: Double(window.dimensions.x)
            )
        }
    }
}
#endif
