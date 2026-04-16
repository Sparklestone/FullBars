import Foundation
import ARKit
import Observation
import os
import UIKit

/// Manages ARSession lifecycle, world tracking, and spatial anchor placement.
@Observable
final class ARSessionService: NSObject {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "ARSession")

    // MARK: - Published State

    var isSessionRunning = false
    var isLiDARAvailable = false
    var trackingState: ARCamera.TrackingState = .notAvailable
    var currentTransform: simd_float4x4?
    var planeCount: Int = 0
    var errorMessage: String?

    // MARK: - Session

    let session = ARSession()
    private var configuration: ARWorldTrackingConfiguration?

    override init() {
        super.init()
        session.delegate = self
        checkLiDARAvailability()
    }

    // MARK: - Configuration

    private func checkLiDARAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    func startSession() {
        let config = ARWorldTrackingConfiguration()

        // Enable plane detection for all devices
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isAutoFocusEnabled = true

        // Enable scene reconstruction on LiDAR devices
        if isLiDARAvailable {
            config.sceneReconstruction = .mesh
        }

        // Enable world alignment
        config.worldAlignment = .gravity

        self.configuration = config
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        errorMessage = nil

        Self.logger.info("AR session started. LiDAR: \(self.isLiDARAvailable)")
    }

    func pauseSession() {
        session.pause()
        isSessionRunning = false
        Self.logger.info("AR session paused")
    }

    func resetSession() {
        guard let config = configuration else { return }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        planeCount = 0
        Self.logger.info("AR session reset")
    }

    // MARK: - Spatial Queries

    /// Get the current camera position in world space
    func currentPosition() -> SIMD3<Float>? {
        guard let transform = currentTransform else { return nil }
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    /// Place a signal measurement anchor at the current position
    func addSignalAnchor(signalStrength: Int, latency: Double) -> ARAnchor? {
        guard let transform = currentTransform else { return nil }

        let anchor = ARAnchor(name: "signal_\(signalStrength)_\(Int(latency))", transform: transform)
        session.add(anchor: anchor)
        return anchor
    }

    // MARK: - Device Capability

    static var isARSupported: Bool {
        ARWorldTrackingConfiguration.isSupported
    }
}

// MARK: - ARSessionDelegate

extension ARSessionService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        currentTransform = frame.camera.transform
        trackingState = frame.camera.trackingState
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let newPlanes = anchors.compactMap { $0 as? ARPlaneAnchor }
        planeCount += newPlanes.count
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        Self.logger.error("AR session failed: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
    }

    func sessionWasInterrupted(_ session: ARSession) {
        Self.logger.warning("AR session interrupted")
        errorMessage = "AR session was interrupted"
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        Self.logger.info("AR session interruption ended")
        errorMessage = nil
        resetSession()
    }
}
