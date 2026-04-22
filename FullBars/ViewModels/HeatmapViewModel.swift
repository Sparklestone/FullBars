import Foundation
import SwiftUI
import Observation
import SwiftData
import ARKit
import os

enum WalkthroughMode: String, CaseIterable {
    case ar = "AR Camera"
    case floorPlan = "Floor Plan"
}

@Observable
final class HeatmapViewModel {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "Heatmap")

    // Services
    var wifiService = WiFiService()
    var locationService = LocationService()
    var arService = ARSessionService()
    var roomPlanService = RoomPlanServiceWrapper()

    // State
    var heatmapPoints: [HeatmapPoint] = []
    var isRecording: Bool = false
    var sessionId: UUID = UUID()
    var walkthroughMode: WalkthroughMode = .ar

    var currentSignalStrength: Int = 0
    var currentLatency: Double = 0
    var recordingDuration: TimeInterval = 0

    // Grading
    var currentGrade: SpaceGrade?
    var showGradeResult = false
    var isGrading = false

    // AR specific
    var isARAvailable: Bool { ARSessionService.isARSupported }
    var markerPlacedFeedback = false

    var pointCount: Int { heatmapPoints.count }

    private var recordingTask: Task<Void, Never>?
    private var startTime: Date?
    private let recordingInterval: TimeInterval = 1.5

    // MARK: - Recording Controls

    func startRecording() {
        sessionId = UUID()
        isRecording = true
        startTime = .now
        recordingDuration = 0
        heatmapPoints.removeAll()
        currentGrade = nil
        showGradeResult = false

        wifiService.startContinuousMonitoring()

        if walkthroughMode == .ar && isARAvailable {
            arService.startSession()
            roomPlanService.startScanning()
        } else {
            locationService.startUpdating()
        }

        recordingTask = Task {
            while !Task.isCancelled && isRecording {
                await recordDataPoint()
                try? await Task.sleep(nanoseconds: UInt64(recordingInterval * 1_000_000_000))
            }
        }

        Self.logger.info("Recording started in \(self.walkthroughMode.rawValue) mode")
    }

    func stopRecording(bleDeviceCount: Int = 0) {
        isRecording = false
        recordingTask?.cancel()
        recordingTask = nil
        wifiService.stopMonitoring()

        if walkthroughMode == .ar {
            arService.pauseSession()
            roomPlanService.stopScanning()
        } else {
            locationService.stopUpdating()
        }

        // Auto-grade the session
        if !heatmapPoints.isEmpty {
            calculateGrade(bleDeviceCount: bleDeviceCount)
        }

        Self.logger.info("Recording stopped. Points: \(self.heatmapPoints.count)")
    }

    // MARK: - Data Collection

    private func recordDataPoint() async {
        await wifiService.fetchCurrentNetwork()
        let latency = await measureLatency()

        await MainActor.run {
            currentSignalStrength = wifiService.signalStrength
            currentLatency = latency
        }

        // Get position from AR or location
        let position: SIMD3<Float>
        if walkthroughMode == .ar, let arPos = arService.currentPosition() {
            position = arPos
        } else {
            // Fallback: use location-based approximation
            let heading = locationService.currentHeading?.trueHeading ?? 0
            let elapsed = Float(recordingDuration)
            let speed: Float = 0.8 // approximate walking speed m/s
            let x = cos(Float(heading) * .pi / 180) * speed * elapsed / 10
            let z = sin(Float(heading) * .pi / 180) * speed * elapsed / 10
            position = SIMD3<Float>(x, 0, z)
        }

        // downloadSpeed is intentionally 0 during walkthrough recording.
        // Running a full speed test at each sample point would add ~5s latency
        // per point and interfere with the real-time AR experience. The grading
        // engine handles this gracefully with default scores when speed is absent.
        let point = HeatmapPoint(
            x: Double(position.x),
            y: Double(position.y),
            z: Double(position.z),
            signalStrength: wifiService.signalStrength,
            latency: latency,
            downloadSpeed: 0,
            timestamp: .now,
            sessionId: sessionId
        )

        await MainActor.run {
            heatmapPoints.append(point)
            markerPlacedFeedback.toggle()

            if let startTime = startTime {
                recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        // Place AR anchor
        if walkthroughMode == .ar {
            _ = arService.addSignalAnchor(
                signalStrength: wifiService.signalStrength,
                latency: latency
            )
        }
    }

    // MARK: - Grading

    func calculateGrade(bleDeviceCount: Int = 0) {
        isGrading = true

        let grade = GradingService.grade(
            points: heatmapPoints,
            bleDeviceCount: bleDeviceCount,
            sessionId: sessionId,
            durationSeconds: recordingDuration
        )

        currentGrade = grade
        isGrading = false
        showGradeResult = true
    }

    // MARK: - Session Management

    func addPoint(x: Float, y: Float, z: Float, signalStrength: Int, latency: Double) {
        let point = HeatmapPoint(
            x: Double(x), y: Double(y), z: Double(z),
            signalStrength: signalStrength,
            latency: latency,
            downloadSpeed: 0,
            timestamp: .now,
            sessionId: sessionId
        )
        heatmapPoints.append(point)
    }

    func clearSession() {
        heatmapPoints.removeAll()
        sessionId = UUID()
        currentGrade = nil
        showGradeResult = false
    }

    func saveSession(context: ModelContext) {
        // Save heatmap points to SwiftData
        for point in heatmapPoints {
            context.insert(point)
        }

        // Save grade if available
        if let grade = currentGrade {
            context.insert(grade)
        }

        // Save session metadata
        let session = WalkthroughSession(
            id: sessionId,
            durationSeconds: recordingDuration,
            pointCount: heatmapPoints.count,
            gradeId: currentGrade?.id,
            minX: heatmapPoints.map(\.x).min() ?? 0,
            maxX: heatmapPoints.map(\.x).max() ?? 0,
            minY: heatmapPoints.map(\.z).min() ?? 0,
            maxY: heatmapPoints.map(\.z).max() ?? 0
        )
        context.insert(session)

        do {
            try context.save()
            Self.logger.info("Session saved: \(self.heatmapPoints.count) points")
        } catch {
            Self.logger.error("Failed to save session: \(error.localizedDescription)")
        }
    }

    // MARK: - Latency

    private func measureLatency() async -> Double {
        let url = URL(string: "https://www.apple.com")!
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            return Date().timeIntervalSince(startTime) * 1000
        } catch {
            return -1
        }
    }
}
