import Foundation
import os
import SwiftUI

/// Analyzes heatmap data to detect weak spots, recommend mesh/router placement,
/// and identify interference regions. Works across single or multiple floors.
final class CoveragePlanningService {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "CoveragePlanning")

    // MARK: - Thresholds

    private static let weakSpotCriticalThreshold: Int = -85
    private static let weakSpotSevereThreshold: Int = -80
    private static let weakSpotModerateThreshold: Int = -75
    private static let goodSignalThreshold: Int = -65
    private static let clusterRadiusMeters: Float = 2.5   // group nearby weak points
    private static let meshCoverageRadius: Float = 8.0     // typical mesh node reach

    // MARK: - Full Analysis

    /// Run complete coverage analysis on all heatmap points.
    static func analyze(
        points: [HeatmapPoint],
        bleDeviceCount: Int = 0,
        floorLabels: [String] = []
    ) -> CoverageAnalysisResult {
        guard !points.isEmpty else {
            return CoverageAnalysisResult(
                weakSpots: [],
                meshRecommendations: [],
                interferenceZones: [],
                coveragePercentage: 0,
                estimatedRouterPosition: nil,
                floorCount: 0,
                timestamp: .now
            )
        }

        let floors = Set(points.map { $0.floorIndex })
        let weakSpots = detectWeakSpots(points: points)
        let routerPosition = estimateRouterPosition(points: points)
        let meshRecs = recommendMeshPlacement(points: points, weakSpots: weakSpots, routerPosition: routerPosition)
        let interferenceZones = detectInterferenceZones(points: points, bleDeviceCount: bleDeviceCount)
        let coveragePct = calculateCoveragePercentage(points: points)

        logger.info("Coverage analysis: \(weakSpots.count) weak spots, \(meshRecs.count) mesh recommendations, \(String(format: "%.0f", coveragePct))% coverage")

        return CoverageAnalysisResult(
            weakSpots: weakSpots,
            meshRecommendations: meshRecs,
            interferenceZones: interferenceZones,
            coveragePercentage: coveragePct,
            estimatedRouterPosition: routerPosition,
            floorCount: floors.count,
            timestamp: .now
        )
    }

    // MARK: - Weak Spot Detection

    /// Identify clusters of weak-signal points as weak spots.
    static func detectWeakSpots(points: [HeatmapPoint]) -> [WeakSpot] {
        // Filter to weak points
        let weakPoints = points.filter { $0.signalStrength < weakSpotModerateThreshold }
        guard !weakPoints.isEmpty else { return [] }

        // Group by floor
        let byFloor = Dictionary(grouping: weakPoints, by: { $0.floorIndex })
        var weakSpots: [WeakSpot] = []

        for (floor, floorPoints) in byFloor {
            // Cluster nearby weak points
            var unclustered = floorPoints
            while !unclustered.isEmpty {
                let seed = unclustered.removeFirst()
                var cluster = [seed]

                // Find all points within cluster radius
                unclustered = unclustered.filter { point in
                    let dx = point.x - seed.x
                    let dz = point.z - seed.z
                    let dist = sqrt(dx * dx + dz * dz)
                    if dist <= clusterRadiusMeters {
                        cluster.append(point)
                        return false
                    }
                    return true
                }

                // Calculate cluster center and severity
                let avgX = cluster.map { $0.x }.reduce(0, +) / Float(cluster.count)
                let avgZ = cluster.map { $0.z }.reduce(0, +) / Float(cluster.count)
                let avgSignal = cluster.map { $0.signalStrength }.reduce(0, +) / cluster.count

                // Determine radius from point spread
                let maxDist = cluster.map { p -> Float in
                    let dx = p.x - avgX
                    let dz = p.z - avgZ
                    return sqrt(dx * dx + dz * dz)
                }.max() ?? 1.0
                let radius = max(1.0, maxDist + 0.5)

                let severity: WeakSpotSeverity
                if avgSignal < weakSpotCriticalThreshold {
                    severity = .critical
                } else if avgSignal < weakSpotSevereThreshold {
                    severity = .severe
                } else {
                    severity = .moderate
                }

                // Find room name from nearest point
                let roomName = cluster.compactMap { $0.roomName }.first

                weakSpots.append(WeakSpot(
                    centerX: avgX,
                    centerZ: avgZ,
                    radius: radius,
                    floorIndex: floor,
                    averageSignal: avgSignal,
                    pointCount: cluster.count,
                    roomName: roomName,
                    severity: severity
                ))
            }
        }

        return weakSpots.sorted { $0.severity.rawValue < $1.severity.rawValue }
    }

    // MARK: - Router Position Estimation

    /// Estimate current router position as the centroid of strongest-signal points.
    static func estimateRouterPosition(points: [HeatmapPoint]) -> CGPoint? {
        // Top 20% strongest signals suggest proximity to router
        let sorted = points.sorted { $0.signalStrength > $1.signalStrength }
        let topCount = max(3, sorted.count / 5)
        let topPoints = Array(sorted.prefix(topCount))

        guard !topPoints.isEmpty else { return nil }

        // Weighted centroid — stronger signals count more
        var weightedX: Float = 0
        var weightedZ: Float = 0
        var totalWeight: Float = 0

        for point in topPoints {
            let weight = Float(max(1, point.signalStrength + 100)) // shift to positive
            weightedX += point.x * weight
            weightedZ += point.z * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }
        return CGPoint(x: CGFloat(weightedX / totalWeight), y: CGFloat(weightedZ / totalWeight))
    }

    // MARK: - Mesh Placement Recommendations

    /// Recommend optimal positions for mesh nodes or extenders.
    static func recommendMeshPlacement(
        points: [HeatmapPoint],
        weakSpots: [WeakSpot],
        routerPosition: CGPoint?
    ) -> [MeshPlacementRecommendation] {
        var recommendations: [MeshPlacementRecommendation] = []
        var priority = 1

        // If we have a router estimate, include it
        if let router = routerPosition {
            recommendations.append(MeshPlacementRecommendation(
                x: Float(router.x),
                z: Float(router.y),
                floorIndex: 0,
                type: .primaryRouter,
                priority: 0,
                reason: "Estimated current router position based on signal strength pattern",
                expectedImpact: "This is where your router appears to be",
                nearestRoomName: findNearestRoom(x: Float(router.x), z: Float(router.y), points: points)
            ))
        }

        // For each weak spot, recommend placement between router and weak spot
        for weakSpot in weakSpots {
            let wsPoint = CGPoint(x: CGFloat(weakSpot.centerX), y: CGFloat(weakSpot.centerZ))

            // Place mesh node at ~60% of the way from router to weak spot
            // (closer to weak spot, but still within range of router)
            let meshX: Float
            let meshZ: Float

            if let router = routerPosition {
                meshX = Float(router.x + (wsPoint.x - router.x) * 0.6)
                meshZ = Float(router.y + (wsPoint.y - router.y) * 0.6)
            } else {
                // Without router estimate, place near the weak spot edge
                meshX = weakSpot.centerX
                meshZ = weakSpot.centerZ
            }

            let placementType: PlacementType = weakSpot.severity == .critical ? .meshNode : .extender

            let roomName = weakSpot.roomName ?? findNearestRoom(x: meshX, z: meshZ, points: points)
            let impact: String
            if let room = weakSpot.roomName {
                impact = "Eliminates weak spot in \(room)"
            } else {
                impact = "Covers \(weakSpot.severity.label.lowercased()) area (\(weakSpot.averageSignal) dBm)"
            }

            recommendations.append(MeshPlacementRecommendation(
                x: meshX,
                z: meshZ,
                floorIndex: weakSpot.floorIndex,
                type: placementType,
                priority: priority,
                reason: "Weak spot detected: \(weakSpot.severity.label) (\(weakSpot.averageSignal) dBm avg)",
                expectedImpact: impact,
                nearestRoomName: roomName
            ))

            priority += 1
        }

        // Check for large coverage gaps even without weak spots
        let byFloor = Dictionary(grouping: points, by: { $0.floorIndex })
        for (floor, floorPoints) in byFloor {
            let bounds = calculateBounds(points: floorPoints)
            let rangeX = bounds.maxX - bounds.minX
            let rangeZ = bounds.maxZ - bounds.minZ

            // If the floor area is large (> 15m span) and no mesh node is already recommended
            // for this floor, suggest a midpoint mesh
            let floorHasMeshRec = recommendations.contains { $0.floorIndex == floor && $0.type != .primaryRouter }
            if (rangeX > 15 || rangeZ > 15) && !floorHasMeshRec {
                // Find the weakest quadrant
                let midX = (bounds.minX + bounds.maxX) / 2
                let midZ = (bounds.minZ + bounds.maxZ) / 2

                let q1Points = floorPoints.filter { $0.x < midX && $0.z < midZ }
                let q2Points = floorPoints.filter { $0.x >= midX && $0.z < midZ }
                let q3Points = floorPoints.filter { $0.x < midX && $0.z >= midZ }
                let q4Points = floorPoints.filter { $0.x >= midX && $0.z >= midZ }

                var quadrants: [(Float, Float, [HeatmapPoint])] = []
                quadrants.append((bounds.minX + rangeX * 0.25, bounds.minZ + rangeZ * 0.25, q1Points))
                quadrants.append((bounds.minX + rangeX * 0.75, bounds.minZ + rangeZ * 0.25, q2Points))
                quadrants.append((bounds.minX + rangeX * 0.25, bounds.minZ + rangeZ * 0.75, q3Points))
                quadrants.append((bounds.minX + rangeX * 0.75, bounds.minZ + rangeZ * 0.75, q4Points))

                let nonEmptyQuads = quadrants.filter { !$0.2.isEmpty }
                let weakest = nonEmptyQuads.min { q0, q1 in
                    let sum0 = q0.2.map { $0.signalStrength }.reduce(0, +)
                    let sum1 = q1.2.map { $0.signalStrength }.reduce(0, +)
                    let avg0 = sum0 / max(1, q0.2.count)
                    let avg1 = sum1 / max(1, q1.2.count)
                    return avg0 < avg1
                }

                if let weakest = weakest {
                    let sumSig = weakest.2.map { $0.signalStrength }.reduce(0, +)
                    let avgSig = sumSig / max(1, weakest.2.count)
                    if avgSig < goodSignalThreshold {
                        let reason = "Large floor area with weak coverage in this quadrant (\(avgSig) dBm)"
                        let impact = "Improves coverage across this section of the floor"
                        let roomName = findNearestRoom(x: weakest.0, z: weakest.1, points: floorPoints)
                        recommendations.append(MeshPlacementRecommendation(
                            x: weakest.0,
                            z: weakest.1,
                            floorIndex: floor,
                            type: .meshNode,
                            priority: priority,
                            reason: reason,
                            expectedImpact: impact,
                            nearestRoomName: roomName
                        ))
                        priority += 1
                    }
                }
            }
        }

        return recommendations.sorted { $0.priority < $1.priority }
    }

    // MARK: - Interference Detection

    /// Detect zones with high latency/jitter that suggest interference.
    static func detectInterferenceZones(points: [HeatmapPoint], bleDeviceCount: Int) -> [InterferenceZone] {
        var zones: [InterferenceZone] = []

        let byFloor = Dictionary(grouping: points, by: { $0.floorIndex })
        for (floor, floorPoints) in byFloor {
            // Find points with high latency relative to their signal strength
            // (high latency + good signal = interference, not distance)
            let avgLatency = floorPoints.map { $0.latency }.filter { $0 > 0 }.reduce(0, +)
                / max(1, Double(floorPoints.filter { $0.latency > 0 }.count))

            let interferencePoints = floorPoints.filter { point in
                // Good signal but high latency → interference
                point.signalStrength >= -70 && point.latency > avgLatency * 1.5 && point.latency > 50
            }

            guard !interferencePoints.isEmpty else { continue }

            // Cluster interference points
            var unclustered = interferencePoints
            while !unclustered.isEmpty {
                let seed = unclustered.removeFirst()
                var cluster = [seed]

                unclustered = unclustered.filter { point in
                    let dx = point.x - seed.x
                    let dz = point.z - seed.z
                    if sqrt(dx * dx + dz * dz) <= clusterRadiusMeters {
                        cluster.append(point)
                        return false
                    }
                    return true
                }

                let avgX = cluster.map { $0.x }.reduce(0, +) / Float(cluster.count)
                let avgZ = cluster.map { $0.z }.reduce(0, +) / Float(cluster.count)
                let maxDist = cluster.map { p -> Float in
                    let dx = p.x - avgX; let dz = p.z - avgZ
                    return sqrt(dx * dx + dz * dz)
                }.max() ?? 1.0

                let level: InterferenceLevel
                let avgLat = cluster.map { $0.latency }.reduce(0, +) / Double(cluster.count)
                if avgLat > avgLatency * 3 || bleDeviceCount > 20 {
                    level = .high
                } else if avgLat > avgLatency * 2 || bleDeviceCount > 10 {
                    level = .moderate
                } else {
                    level = .low
                }

                var sources: [String] = []
                if bleDeviceCount > 10 { sources.append("Bluetooth devices (\(bleDeviceCount) nearby)") }
                if avgLat > 100 { sources.append("Network congestion") }
                sources.append("Possible microwave or cordless phone interference")

                zones.append(InterferenceZone(
                    centerX: avgX,
                    centerZ: avgZ,
                    radius: max(1.5, maxDist + 0.5),
                    floorIndex: floor,
                    interferenceLevel: level,
                    likelySources: sources,
                    roomName: cluster.compactMap { $0.roomName }.first
                ))
            }
        }

        return zones
    }

    // MARK: - Coverage Percentage

    static func calculateCoveragePercentage(points: [HeatmapPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        let goodCount = points.filter { $0.signalStrength >= goodSignalThreshold }.count
        return Double(goodCount) / Double(points.count) * 100
    }

    // MARK: - Multi-Floor Summary

    static func floorSummaries(points: [HeatmapPoint], floorLabels: [String] = []) -> [FloorCoverageSummary] {
        let byFloor = Dictionary(grouping: points, by: { $0.floorIndex })

        return byFloor.map { (floor, floorPoints) in
            let avgSignal = floorPoints.map { $0.signalStrength }.reduce(0, +) / max(1, floorPoints.count)
            let coverage = calculateCoveragePercentage(points: floorPoints)
            let weakSpots = detectWeakSpots(points: floorPoints)
            let meshNeeded = weakSpots.filter { $0.severity != .moderate }.count

            let label: String
            if floor < floorLabels.count {
                label = floorLabels[floor]
            } else {
                label = floor == 0 ? "Ground Floor" : "Floor \(floor + 1)"
            }

            return FloorCoverageSummary(
                floorIndex: floor,
                floorLabel: label,
                pointCount: floorPoints.count,
                averageSignal: avgSignal,
                coveragePercentage: coverage,
                weakSpotCount: weakSpots.count,
                meshNodesNeeded: meshNeeded,
                grade: GradeLetter.from(score: coverage)
            )
        }.sorted { $0.floorIndex < $1.floorIndex }
    }

    // MARK: - Edge Indicators

    /// Generate edge indicators for zones that are off-screen or notable.
    static func generateEdgeIndicators(
        analysis: CoverageAnalysisResult,
        visibleBounds: CGRect,
        viewSize: CGSize
    ) -> [EdgeIndicator] {
        var indicators: [EdgeIndicator] = []

        // Weak spot indicators
        for dz in analysis.weakSpots {
            let point = dz.center
            // Always show edge indicators for notable zones
            let (edge, position) = edgePosition(for: point, in: visibleBounds, viewSize: viewSize)
            indicators.append(EdgeIndicator(
                type: .weakSpot,
                edge: edge,
                position: position,
                label: dz.severity.label,
                detail: dz.roomName ?? "\(dz.averageSignal) dBm",
                color: dz.severity.color,
                targetPoint: point
            ))
        }

        // Mesh placement indicators
        for rec in analysis.meshRecommendations where rec.type != .primaryRouter {
            let point = rec.position
            let (edge, position) = edgePosition(for: point, in: visibleBounds, viewSize: viewSize)
            indicators.append(EdgeIndicator(
                type: .meshPlacement,
                edge: edge,
                position: position,
                label: rec.type.label,
                detail: rec.nearestRoomName ?? "Priority \(rec.priority)",
                color: rec.type.color,
                targetPoint: point
            ))
        }

        // Interference indicators
        for iz in analysis.interferenceZones where iz.interferenceLevel != .low {
            let point = CGPoint(x: CGFloat(iz.centerX), y: CGFloat(iz.centerZ))
            let (edge, position) = edgePosition(for: point, in: visibleBounds, viewSize: viewSize)
            indicators.append(EdgeIndicator(
                type: .interference,
                edge: edge,
                position: position,
                label: "Interference",
                detail: iz.roomName ?? iz.interferenceLevel.rawValue.capitalized,
                color: iz.interferenceLevel.color,
                targetPoint: point
            ))
        }

        // Router position indicator
        if let router = analysis.estimatedRouterPosition {
            let (edge, position) = edgePosition(for: router, in: visibleBounds, viewSize: viewSize)
            indicators.append(EdgeIndicator(
                type: .routerPosition,
                edge: edge,
                position: position,
                label: "Router",
                detail: "Estimated position",
                color: FullBars.Design.Colors.accentCyan,
                targetPoint: router
            ))
        }

        return indicators
    }

    // MARK: - Helpers

    private static func edgePosition(
        for point: CGPoint,
        in bounds: CGRect,
        viewSize: CGSize
    ) -> (Edge, CGFloat) {
        // Map point to view coordinates
        let normalizedX = (point.x - bounds.minX) / max(1, bounds.width)
        let normalizedY = (point.y - bounds.minY) / max(1, bounds.height)

        // Determine which edge is closest
        let distLeft = normalizedX
        let distRight = 1.0 - normalizedX
        let distTop = normalizedY
        let distBottom = 1.0 - normalizedY

        let minDist = min(distLeft, distRight, distTop, distBottom)

        if minDist == distTop {
            return (.top, max(0.05, min(0.95, normalizedX)))
        } else if minDist == distBottom {
            return (.bottom, max(0.05, min(0.95, normalizedX)))
        } else if minDist == distLeft {
            return (.leading, max(0.05, min(0.95, normalizedY)))
        } else {
            return (.trailing, max(0.05, min(0.95, normalizedY)))
        }
    }

    private static func findNearestRoom(x: Float, z: Float, points: [HeatmapPoint]) -> String? {
        points
            .compactMap { p -> (String, Float)? in
                guard let name = p.roomName else { return nil }
                let dx = p.x - x; let dz = p.z - z
                return (name, sqrt(dx * dx + dz * dz))
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func calculateBounds(points: [HeatmapPoint]) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        guard !points.isEmpty else { return (0, 1, 0, 1) }
        let xs = points.map { $0.x }
        let zs = points.map { $0.z }
        return (xs.min() ?? 0, xs.max() ?? 1, zs.min() ?? 0, zs.max() ?? 1)
    }
}
