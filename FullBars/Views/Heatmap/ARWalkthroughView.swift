import SwiftUI
import ARKit
import SceneKit

/// UIViewRepresentable wrapping ARSCNView for the live camera + signal marker experience.
struct ARWalkthroughView: UIViewRepresentable {
    let arService: ARSessionService
    let signalPoints: [HeatmapPoint]
    let displayMode: DisplayMode

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.session = arService.session
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true

        // Show feature points and plane detection in debug
        #if DEBUG
        sceneView.debugOptions = [.showFeaturePoints]
        #endif

        // Dark scene background
        sceneView.scene.background.contents = UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1)

        return sceneView
    }

    func updateUIView(_ sceneView: ARSCNView, context: Context) {
        context.coordinator.updateMarkers(in: sceneView, points: signalPoints, displayMode: displayMode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSCNViewDelegate {
        private var markerNodes: [UUID: SCNNode] = [:]

        func updateMarkers(in sceneView: ARSCNView, points: [HeatmapPoint], displayMode: DisplayMode) {
            // Add new markers for points we haven't rendered yet
            for point in points {
                if markerNodes[point.id] == nil {
                    let node = createMarkerNode(for: point, displayMode: displayMode)
                    sceneView.scene.rootNode.addChildNode(node)
                    markerNodes[point.id] = node
                }
            }
        }

        private func createMarkerNode(for point: HeatmapPoint, displayMode: DisplayMode) -> SCNNode {
            // Sphere marker
            let sphere = SCNSphere(radius: 0.04)
            let color = markerColor(for: point.signalStrength)

            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(0.6)
            material.transparency = 0.85
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(point.x, point.y, point.z)

            // Glow effect: larger transparent outer sphere
            let glowSphere = SCNSphere(radius: 0.08)
            let glowMaterial = SCNMaterial()
            glowMaterial.diffuse.contents = color.withAlphaComponent(0.15)
            glowMaterial.emission.contents = color.withAlphaComponent(0.1)
            glowMaterial.transparency = 0.7
            glowSphere.materials = [glowMaterial]
            let glowNode = SCNNode(geometry: glowSphere)
            node.addChildNode(glowNode)

            // Text label for technical mode
            if displayMode == .technical {
                let text = SCNText(string: "\(point.signalStrength)", extrusionDepth: 0.5)
                text.font = UIFont.systemFont(ofSize: 3, weight: .bold)
                text.firstMaterial?.diffuse.contents = UIColor.white
                let textNode = SCNNode(geometry: text)
                textNode.scale = SCNVector3(0.005, 0.005, 0.005)
                textNode.position = SCNVector3(0.05, 0.03, 0)

                // Billboard constraint so text always faces camera
                let constraint = SCNBillboardConstraint()
                textNode.constraints = [constraint]
                node.addChildNode(textNode)
            }

            // Entry animation
            node.scale = SCNVector3(0, 0, 0)
            node.runAction(SCNAction.scale(to: 1, duration: 0.3))

            return node
        }

        private func markerColor(for signalStrength: Int) -> UIColor {
            switch signalStrength {
            case -50...0:
                return UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1) // green
            case -60..<(-50):
                return UIColor(FullBars.Design.Colors.accentCyan) // cyan
            case -70..<(-60):
                return UIColor(red: 1, green: 0.85, blue: 0, alpha: 1) // yellow
            case -80..<(-70):
                return UIColor(red: 1, green: 0.55, blue: 0, alpha: 1) // orange
            default:
                return UIColor(red: 1, green: 0.15, blue: 0.25, alpha: 1) // red
            }
        }

        // MARK: - ARSCNViewDelegate

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            // Visualize detected planes with a subtle overlay
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

            let planeGeometry = SCNPlane(
                width: CGFloat(planeAnchor.planeExtent.width),
                height: CGFloat(planeAnchor.planeExtent.height)
            )

            let material = SCNMaterial()
            material.diffuse.contents = UIColor(FullBars.Design.Colors.accentCyan).withAlphaComponent(0.08)
            planeGeometry.materials = [material]

            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.eulerAngles.x = -.pi / 2
            node.addChildNode(planeNode)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            if let planeNode = node.childNodes.first,
               let planeGeometry = planeNode.geometry as? SCNPlane {
                planeGeometry.width = CGFloat(planeAnchor.planeExtent.width)
                planeGeometry.height = CGFloat(planeAnchor.planeExtent.height)
            }
        }
    }
}

// MARK: - AR HUD Overlay

struct ARHUDOverlay: View {
    let signalStrength: Int
    let duration: TimeInterval
    let pointCount: Int
    let trackingState: ARCamera.TrackingState
    let displayMode: DisplayMode

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        VStack {
            // Top HUD bar
            HStack(spacing: 16) {
                // Signal indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(signalColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: signalColor.opacity(0.8), radius: 4)

                    if displayMode == .technical {
                        Text("\(signalStrength) dBm (est.)")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    } else {
                        Text(signalLabel)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDuration(duration))
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white.opacity(0.8))

                // Point count
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                    Text("\(pointCount)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(electricCyan)

                // Tracking quality
                trackingIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.8))

            Spacer()
        }
    }

    private var signalColor: Color {
        switch signalStrength {
        case -50...0: return .green
        case -60..<(-50): return FullBars.Design.Colors.accentCyan
        case -70..<(-60): return .yellow
        case -80..<(-70): return .orange
        default: return .red
        }
    }

    private var signalLabel: String {
        switch signalStrength {
        case -50...0: return "Excellent"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        case -80..<(-70): return "Weak"
        default: return "Poor"
        }
    }

    @ViewBuilder
    private var trackingIndicator: some View {
        let (icon, color): (String, Color) = {
            switch trackingState {
            case .normal:
                return ("checkmark.circle.fill", .green)
            case .limited:
                return ("exclamationmark.circle.fill", .yellow)
            case .notAvailable:
                return ("xmark.circle.fill", .red)
            }
        }()

        Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
