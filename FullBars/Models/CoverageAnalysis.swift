import Foundation
import SwiftUI

// MARK: - Dead Zone

/// A spatial region with critically weak or no WiFi signal.
struct DeadZone: Identifiable {
    let id = UUID()
    let centerX: Float
    let centerZ: Float
    let radius: Float          // estimated coverage radius in meters
    let floorIndex: Int
    let averageSignal: Int     // dBm
    let pointCount: Int
    let roomName: String?
    let severity: DeadZoneSeverity

    var center: CGPoint { CGPoint(x: CGFloat(centerX), y: CGFloat(centerZ)) }
}

enum DeadZoneSeverity: String, CaseIterable {
    case critical   // < -85 dBm or no signal
    case severe     // -85 to -80 dBm
    case moderate   // -80 to -75 dBm

    var color: Color {
        switch self {
        case .critical: return FullBars.Design.Colors.signalNoSignal
        case .severe:   return FullBars.Design.Colors.signalPoor
        case .moderate: return FullBars.Design.Colors.signalFair
        }
    }

    var icon: String {
        switch self {
        case .critical: return "xmark.circle.fill"
        case .severe:   return "exclamationmark.triangle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .critical: return "No Signal"
        case .severe:   return "Very Weak"
        case .moderate: return "Weak Zone"
        }
    }

    var friendlyDescription: String {
        switch self {
        case .critical: return "This area has almost no WiFi signal. A mesh node or extender is strongly recommended here."
        case .severe:   return "Signal barely reaches this area. Devices here will drop frequently."
        case .moderate: return "Signal is weak here. Streaming and video calls may have issues."
        }
    }
}

// MARK: - Mesh Placement Recommendation

/// A recommended position for a WiFi router, mesh node, or extender.
struct MeshPlacementRecommendation: Identifiable {
    let id = UUID()
    let x: Float
    let z: Float
    let floorIndex: Int
    let type: PlacementType
    let priority: Int           // 1 = highest priority
    let reason: String
    let expectedImpact: String  // e.g. "Eliminates dead zone in Bedroom"
    let nearestRoomName: String?

    var position: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(z)) }
}

enum PlacementType: String, CaseIterable {
    case primaryRouter
    case meshNode
    case extender

    var icon: String {
        switch self {
        case .primaryRouter: return "wifi.router.fill"
        case .meshNode:      return "dot.radiowaves.left.and.right"
        case .extender:      return "wifi.exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .primaryRouter: return FullBars.Design.Colors.accentCyan
        case .meshNode:      return FullBars.Design.Colors.signalGood
        case .extender:      return FullBars.Design.Colors.signalFair
        }
    }

    var label: String {
        switch self {
        case .primaryRouter: return "Router"
        case .meshNode:      return "Mesh Node"
        case .extender:      return "Extender"
        }
    }
}

// MARK: - Interference Zone

/// A region with high BLE or co-channel interference.
struct InterferenceZone: Identifiable {
    let id = UUID()
    let centerX: Float
    let centerZ: Float
    let radius: Float
    let floorIndex: Int
    let interferenceLevel: InterferenceLevel
    let likelySources: [String]
    let roomName: String?
}

enum InterferenceLevel: String, CaseIterable {
    case high
    case moderate
    case low

    var color: Color {
        switch self {
        case .high:     return .purple
        case .moderate: return .purple.opacity(0.6)
        case .low:      return .purple.opacity(0.3)
        }
    }

    var icon: String {
        switch self {
        case .high:     return "antenna.radiowaves.left.and.right"
        case .moderate: return "wave.3.left"
        case .low:      return "wave.3.left.circle"
        }
    }
}

// MARK: - Coverage Analysis Result

/// Complete analysis result combining dead zones, placement recommendations, and interference.
struct CoverageAnalysisResult {
    let deadZones: [DeadZone]
    let meshRecommendations: [MeshPlacementRecommendation]
    let interferenceZones: [InterferenceZone]
    let coveragePercentage: Double       // % of area with good+ signal
    let estimatedRouterPosition: CGPoint? // inferred current router location
    let floorCount: Int
    let timestamp: Date

    var deadZoneCount: Int { deadZones.count }
    var hasCriticalDeadZones: Bool { deadZones.contains { $0.severity == .critical } }
    var meshNodesNeeded: Int { meshRecommendations.filter { $0.type == .meshNode || $0.type == .extender }.count }

    var overallAssessment: String {
        if deadZones.isEmpty && coveragePercentage >= 90 {
            return "Excellent coverage — no dead zones detected."
        } else if deadZones.count <= 2 && coveragePercentage >= 70 {
            return "Good coverage with \(deadZones.count) weak spot\(deadZones.count == 1 ? "" : "s"). A mesh node would help."
        } else if coveragePercentage >= 50 {
            return "Moderate coverage. \(meshNodesNeeded) mesh node\(meshNodesNeeded == 1 ? "" : "s") recommended."
        } else {
            return "Poor coverage with significant dead zones. A mesh system is strongly recommended."
        }
    }

    var assessmentColor: Color {
        if coveragePercentage >= 85 { return FullBars.Design.Colors.signalGood }
        if coveragePercentage >= 65 { return FullBars.Design.Colors.signalFair }
        return FullBars.Design.Colors.signalPoor
    }
}

// MARK: - Edge Indicator

/// An indicator pinned to a screen edge pointing toward an off-screen or notable zone.
struct EdgeIndicator: Identifiable {
    let id = UUID()
    let type: EdgeIndicatorType
    let edge: Edge                // which screen edge it's pinned to
    let position: CGFloat         // normalized 0–1 along that edge
    let label: String
    let detail: String
    let color: Color
    let targetPoint: CGPoint      // the actual point in floor-plan space this points to
}

enum EdgeIndicatorType {
    case deadZone
    case meshPlacement
    case interference
    case routerPosition

    var icon: String {
        switch self {
        case .deadZone:       return "exclamationmark.triangle.fill"
        case .meshPlacement:  return "wifi.router.fill"
        case .interference:   return "antenna.radiowaves.left.and.right"
        case .routerPosition: return "wifi.circle.fill"
        }
    }
}

// MARK: - Floor Summary

/// Per-floor summary for multi-floor analysis.
struct FloorCoverageSummary: Identifiable {
    var id: Int { floorIndex }
    let floorIndex: Int
    let floorLabel: String
    let pointCount: Int
    let averageSignal: Int
    let coveragePercentage: Double
    let deadZoneCount: Int
    let meshNodesNeeded: Int
    let grade: GradeLetter
}
