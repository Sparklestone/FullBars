import Foundation
import SwiftUI

// MARK: - Signal Range

struct SignalRange {
    let strongest: Int   // Best signal across all rooms (e.g., -35)
    let weakest: Int     // Worst non-weak-spot signal (e.g., -78)
    
    /// Maps a signal strength to 0.0 (weakest/orange) through 1.0 (strongest/green).
    /// Uses the full range of observed signals — never returns nil.
    func normalizedPosition(_ dBm: Int) -> Double {
        let effectiveWeakest = min(weakest, -90)
        let range = Double(strongest - effectiveWeakest)
        guard range > 0 else { return 1.0 }
        return max(0, min(1, Double(dBm - effectiveWeakest) / range))
    }

    /// Color for a signal value using the relative scale.
    /// Interpolates from orange (weakest) through yellow to green (strongest).
    static func relativeColor(for dBm: Int, range: SignalRange) -> Color {
        let norm = range.normalizedPosition(dBm)
        // Interpolate from orange (0.0) through yellow (0.5) to green (1.0)
        if norm >= 0.5 {
            let t = (norm - 0.5) * 2 // 0..1 within green-yellow
            return Color(
                red: (1 - t) * 1.0,        // yellow→green: red fades
                green: 0.7 + t * 0.3,      // stays high
                blue: 0
            )
        } else {
            let t = norm * 2 // 0..1 within orange-yellow
            return Color(
                red: 1.0,                   // stays at 1
                green: 0.4 + t * 0.3,      // orange→yellow: green increases
                blue: 0
            )
        }
    }
}

// MARK: - Mesh Recommendation

struct MeshRecommendation: Identifiable {
    let id = UUID()
    let bestRoom: String
    let worstRoom: String
    let speedGap: String        // e.g., "120 Mbps vs 25 Mbps"
    let signalGap: String       // e.g., "-42 dBm vs -75 dBm"
    let recommendation: String  // user-facing text
}

// MARK: - Whole-House Recommendation

struct WholeHouseRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let affectedRooms: [String]  // room display names
}

// MARK: - Whole-House Analysis

struct WholeHouseAnalysis {
    let signalRange: SignalRange
    let meshRecommendation: MeshRecommendation?
    let recommendations: [WholeHouseRecommendation]
}

// MARK: - Service

struct WholeHouseAnalysisService {
    
    /// Analyzes all rooms in a house and returns aggregated metrics, mesh recommendations, and whole-house guidance.
    static func analyzeHouse(rooms: [Room], allPoints: [HeatmapPoint]) -> WholeHouseAnalysis {
        let signalRange = computeSignalRange(rooms: rooms, allPoints: allPoints)
        let meshRecommendation = computeMeshRecommendation(rooms: rooms, allPoints: allPoints)
        let recommendations = aggregateRecommendations(rooms: rooms, allPoints: allPoints)
        
        return WholeHouseAnalysis(
            signalRange: signalRange,
            meshRecommendation: meshRecommendation,
            recommendations: recommendations
        )
    }
    
    // MARK: - Capability 1: Relative Heatmap Signal Range

    /// Computes the min and max signal strengths from a set of HeatmapPoints, excluding weak-spot samples below -80 dBm.
    /// Handles edge cases: returns sensible defaults for empty data.
    static func computeSignalRange(points: [HeatmapPoint]) -> SignalRange {
        // Collect all signal strengths (include everything above -95 dBm)
        let validSignals = points
            .filter { $0.signalStrength >= -95 }
            .map { $0.signalStrength }

        if validSignals.isEmpty {
            // No valid signals: default to a neutral range
            // (all points are weak spots, or no data)
            return SignalRange(strongest: -40, weakest: -80)
        }

        if validSignals.count == 1 {
            // Single valid signal: use it as both strongest and weakest,
            // but expand range slightly for gradient visibility
            let signal = validSignals[0]
            return SignalRange(strongest: signal, weakest: signal - 5)
        }

        // Multiple signals: use actual min/max
        let strongest = validSignals.max() ?? -40
        let weakest = validSignals.min() ?? -80

        return SignalRange(strongest: strongest, weakest: weakest)
    }

    /// Computes the min and max signal strengths across ALL rooms, excluding weak-spot samples below -80 dBm.
    /// Handles edge cases: returns sensible defaults for empty data.
    private static func computeSignalRange(rooms: [Room], allPoints: [HeatmapPoint]) -> SignalRange {
        return computeSignalRange(points: allPoints)
    }
    
    // MARK: - Capability 2: Mesh System Recommendation
    
    /// Recommends a mesh system if rooms have significantly uneven coverage.
    /// Criteria:
    ///  - Best room download > 2x worst room download, OR
    ///  - Signal spread > 15 dBm
    private static func computeMeshRecommendation(rooms: [Room], allPoints: [HeatmapPoint]) -> MeshRecommendation? {
        guard !rooms.isEmpty else { return nil }
        
        // Compute average speed and signal for each room
        var roomMetrics: [(room: Room, avgSpeed: Double, avgSignal: Double)] = []
        
        for room in rooms {
            let roomPoints = allPoints.filter { $0.roomId == room.id }
            
            // Average download speed — exclude zero-speed samples (collected during walking, before speed test)
            let avgSpeed: Double
            let nonZeroSpeeds = roomPoints.map { $0.downloadSpeed }.filter { $0 > 0 }
            if !nonZeroSpeeds.isEmpty {
                avgSpeed = nonZeroSpeeds.reduce(0, +) / Double(nonZeroSpeeds.count)
            } else {
                avgSpeed = room.downloadMbps // fallback to room's overall metric
            }
            
            // Average signal (only non-weak-spot)
            let avgSignal: Double
            let validSignals = roomPoints
                .filter { $0.signalStrength >= -80 }
                .map { Double($0.signalStrength) }
            
            if validSignals.isEmpty {
                // No valid signals for this room; use a weak default
                avgSignal = -75.0
            } else {
                avgSignal = validSignals.reduce(0, +) / Double(validSignals.count)
            }
            
            roomMetrics.append((room: room, avgSpeed: avgSpeed, avgSignal: avgSignal))
        }
        
        if roomMetrics.isEmpty { return nil }
        
        // Find best and worst rooms
        let sortedBySpeed = roomMetrics.sorted { $0.avgSpeed > $1.avgSpeed }
        let bestBySpeed = sortedBySpeed.first?.room ?? rooms[0]
        let worstBySpeed = sortedBySpeed.last?.room ?? rooms[0]
        
        let sortedBySignal = roomMetrics.sorted { $0.avgSignal > $1.avgSignal }
        let bestBySignal = sortedBySignal.first?.room ?? rooms[0]
        let worstBySignal = sortedBySignal.last?.room ?? rooms[0]
        
        // Fetch metrics for best/worst
        let bestSpeedMetric = roomMetrics.first { $0.room.id == bestBySpeed.id }?.avgSpeed ?? 0
        let worstSpeedMetric = roomMetrics.first { $0.room.id == worstBySpeed.id }?.avgSpeed ?? 0
        let bestSignalMetric = roomMetrics.first { $0.room.id == bestBySignal.id }?.avgSignal ?? -40
        let worstSignalMetric = roomMetrics.first { $0.room.id == worstBySignal.id }?.avgSignal ?? -80
        
        // Check criteria
        let speedGap = worstSpeedMetric > 0 ? (bestSpeedMetric / worstSpeedMetric) : 1.0
        let signalSpread = bestSignalMetric - worstSignalMetric
        
        let recommendMesh = (speedGap > 2.0) || (signalSpread > 15.0)
        
        guard recommendMesh else { return nil }
        
        // Format metrics with friendly labels
        let speedGapStr = String(format: "%.0f Mbps vs %.0f Mbps", bestSpeedMetric, worstSpeedMetric)
        let bestLabel = signalLabel(Int(bestSignalMetric))
        let worstLabel = signalLabel(Int(worstSignalMetric))
        let signalGapStr = "\(bestLabel) vs \(worstLabel)"
        
        let recommendationText: String
        if speedGap > 2.0 && signalSpread > 15.0 {
            recommendationText = "Your home has significant WiFi coverage gaps. A mesh system will extend your network to weak spots and improve overall speed consistency."
        } else if speedGap > 2.0 {
            recommendationText = "Download speeds vary significantly between rooms. A mesh system can help equalize performance across your home."
        } else {
            recommendationText = "Signal strength varies significantly between rooms. A mesh system will improve coverage in weaker areas."
        }
        
        return MeshRecommendation(
            bestRoom: bestBySpeed.displayName,
            worstRoom: worstBySpeed.displayName,
            speedGap: speedGapStr,
            signalGap: signalGapStr,
            recommendation: recommendationText
        )
    }
    
    // MARK: - Capability 3: Whole-House Recommendations
    
    /// Aggregates room-level recommendations into whole-house guidance.
    /// Deduplicates by recommendation type and adjusts language for home-level context.
    private static func aggregateRecommendations(rooms: [Room], allPoints: [HeatmapPoint]) -> [WholeHouseRecommendation] {
        // Collect per-room recommendations
        var recommendationsByType: [String: (title: String, icon: String, color: Color, affectedRooms: [String])] = [:]
        
        for room in rooms {
            let roomRecs = buildRoomRecommendations(room: room, allPoints: allPoints)
            
            for rec in roomRecs {
                if recommendationsByType[rec.key] != nil {
                    // Dedup: add room to existing recommendation type
                    recommendationsByType[rec.key]?.affectedRooms.append(room.displayName)
                } else {
                    // First room with this recommendation type
                    recommendationsByType[rec.key] = (
                        title: rec.title,
                        icon: rec.icon,
                        color: rec.color,
                        affectedRooms: [room.displayName]
                    )
                }
            }
        }
        
        // Convert to WholeHouseRecommendation with adjusted language
        var wholeHouseRecs: [WholeHouseRecommendation] = []
        
        for (key, data) in recommendationsByType {
            let detail = formatWholeHouseDetail(key: key, affectedRooms: data.affectedRooms)
            wholeHouseRecs.append(
                WholeHouseRecommendation(
                    title: data.title,
                    detail: detail,
                    icon: data.icon,
                    color: data.color,
                    affectedRooms: data.affectedRooms
                )
            )
        }
        
        // Sort by severity type first, then by affected room count within same type
        let keyOrder = ["weak_spots", "slow_speeds", "high_latency", "ble_interference", "rescan_coverage"]
        wholeHouseRecs.sort { rec1, rec2 in
            // Find the key from the title to determine severity order
            let idx1 = keyOrder.firstIndex(where: { formatKeyTitle($0) == rec1.title }) ?? keyOrder.count
            let idx2 = keyOrder.firstIndex(where: { formatKeyTitle($0) == rec2.title }) ?? keyOrder.count
            if idx1 != idx2 { return idx1 < idx2 }
            // Within same type, more affected rooms = higher priority
            return rec1.affectedRooms.count > rec2.affectedRooms.count
        }
        
        return wholeHouseRecs
    }
    
    /// Builds recommendations for a single room (mirrors RoomDetailView logic).
    /// Returns tuples with (key, title, icon, color) for deduplication.
    private static func buildRoomRecommendations(room: Room, allPoints: [HeatmapPoint]) -> [(key: String, title: String, icon: String, color: Color)] {
        var recs: [(key: String, title: String, icon: String, color: Color)] = []

        let roomPoints = allPoints.filter { $0.roomId == room.id }

        // Check for weak spots (matches RoomDetailView: signalStrength < -80)
        let weakSpots = roomPoints.filter { $0.signalStrength < -80 }
        if !weakSpots.isEmpty {
            recs.append((
                key: "weak_spots",
                title: "Address Weak Spots",
                icon: "dot.radiowaves.left.and.right",
                color: .purple
            ))
        }

        // Check for slow speeds (uses room's measured downloadMbps, matching RoomDetailView)
        if room.downloadMbps < 25 {
            recs.append((
                key: "slow_speeds",
                title: "Improve Download Speed",
                icon: "speedometer",
                color: .orange
            ))
        }

        // Check for high latency (uses room's measured pingMs, matching RoomDetailView)
        if room.pingMs > 60 {
            recs.append((
                key: "high_latency",
                title: "Reduce Latency",
                icon: "clock.fill",
                color: .yellow
            ))
        }

        // Check for BLE interference
        if room.bleDeviceCount > 15 {
            recs.append((
                key: "ble_interference",
                title: "Reduce BLE Interference",
                icon: "antenna.radiowaves.left.and.right",
                color: .orange
            ))
        }

        // Check for coverage gaps (low painted fraction)
        if room.paintedCoverageFraction < 0.45 {
            recs.append((
                key: "rescan_coverage",
                title: "Rescan for Better Accuracy",
                icon: "arrow.clockwise",
                color: Color(red: 0, green: 0.8, blue: 0.8) // cyan
            ))
        }

        return recs
    }
    
    /// Maps a recommendation key to its display title (used for sorting).
    private static func formatKeyTitle(_ key: String) -> String {
        switch key {
        case "weak_spots": return "Address Weak Spots"
        case "slow_speeds": return "Improve Download Speed"
        case "high_latency": return "Reduce Latency"
        case "ble_interference": return "Reduce BLE Interference"
        case "rescan_coverage": return "Rescan for Better Accuracy"
        default: return ""
        }
    }

    /// Returns a user-friendly label for a signal strength value.
    private static func signalLabel(_ dBm: Int) -> String {
        switch dBm {
        case -50...0: return "Strong"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        case -80..<(-70): return "Weak"
        default: return "Very weak"
        }
    }

    /// Formats whole-house detail text based on recommendation type and affected rooms.
    private static func formatWholeHouseDetail(key: String, affectedRooms: [String]) -> String {
        let roomList = affectedRooms.count > 2
            ? affectedRooms.dropLast().joined(separator: ", ") + ", and " + affectedRooms.last!
            : affectedRooms.joined(separator: " and ")
        
        switch key {
        case "weak_spots":
            if affectedRooms.count == 1 {
                return "Weak spots detected in your \(roomList). Consider adding a mesh node nearby."
            }
            return "Weak spots detected in \(roomList). A mesh WiFi system would extend coverage to these areas."
        case "slow_speeds":
            if affectedRooms.count == 1 {
                return "Download speed is slow in your \(roomList). Try moving your router closer or check for obstructions."
            }
            return "Download speeds are below 25 Mbps in \(roomList). Consider upgrading your plan or adding a mesh node."
        case "high_latency":
            if affectedRooms.count == 1 {
                return "High latency detected in your \(roomList). This may cause lag in video calls and games."
            }
            return "High latency detected in \(roomList). Check for network congestion or interference."
        case "ble_interference":
            return "High Bluetooth device congestion in \(roomList). Consider switching your router to 5 GHz for these areas."
        case "rescan_coverage":
            return "Low floor coverage in \(roomList). Rescan these rooms for more accurate results."
        default:
            return "Check WiFi coverage in \(roomList)."
        }
    }
}
