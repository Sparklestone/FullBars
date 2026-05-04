import Foundation
import os

/// Evaluates walkthrough data and produces an A-F space grade.
final class GradingService {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "Grading")

    // MARK: - Grade Calculation

    /// Calculate a SpaceGrade from collected heatmap points and optional BLE data.
    static func grade(
        points: [HeatmapPoint],
        bleDeviceCount: Int = 0,
        sessionId: UUID,
        durationSeconds: Double
    ) -> SpaceGrade {
        guard !points.isEmpty else {
            return SpaceGrade(sessionId: sessionId, durationSeconds: durationSeconds)
        }

        let signalCoverage = calculateSignalCoverage(points: points)
        let speedPerformance = calculateSpeedPerformance(points: points)
        let reliability = calculateReliability(points: points)
        let latency = calculateLatencyScore(points: points)
        let interference = calculateInterferenceScore(bleDeviceCount: bleDeviceCount)

        // Weighted overall score
        let overall = signalCoverage * 0.30
            + speedPerformance * 0.25
            + reliability * 0.20
            + latency * 0.15
            + interference * 0.10

        let avgSignal = points.map(\.signalStrength).reduce(0, +) / max(1, points.count)
        let latencyValues = points.map(\.latency).filter { $0 > 0 }
        let latencySum = latencyValues.reduce(0, +)
        let avgLatency = latencySum / max(1, Double(latencyValues.count))

        let downloadValues = points.map(\.downloadSpeed).filter { $0 > 0 }
        let downloadSum = downloadValues.reduce(0, +)
        let avgDownload = downloadSum / max(1, Double(downloadValues.count))

        let grade = SpaceGrade(
            sessionId: sessionId,
            overallScore: min(100, max(0, overall)),
            signalCoverageScore: signalCoverage,
            speedPerformanceScore: speedPerformance,
            reliabilityScore: reliability,
            latencyScore: latency,
            interferenceScore: interference,
            pointCount: points.count,
            durationSeconds: durationSeconds,
            averageSignalStrength: avgSignal,
            averageLatency: avgLatency,
            averageDownloadSpeed: avgDownload
        )

        logger.info("Grade calculated: \(grade.grade.rawValue) (\(String(format: "%.1f", overall)))")
        return grade
    }

    // MARK: - Category Calculations

    /// Signal Coverage (30%): Percentage of points with "good or better" signal,
    /// with additional penalty for detected weak spots.
    private static func calculateSignalCoverage(points: [HeatmapPoint]) -> Double {
        let goodThreshold = AppConstants.Signal.good      // -65
        let fairThreshold = AppConstants.Signal.fair       // -75
        let goodCount = points.filter { $0.signalStrength >= goodThreshold }.count
        let fairCount = points.filter { $0.signalStrength >= fairThreshold && $0.signalStrength < goodThreshold }.count
        let total = Double(points.count)

        // Good points worth full marks, fair points worth half
        var score = (Double(goodCount) + Double(fairCount) * 0.5) / max(1, total) * 100

        // Weak spot penalty: detect clusters of very weak signal and penalize
        let weakSpots = CoveragePlanningService.detectWeakSpots(points: points)
        let criticalCount = weakSpots.filter { $0.severity == .critical }.count
        let severeCount = weakSpots.filter { $0.severity == .severe }.count
        score -= Double(criticalCount) * 8  // -8 per critical weak spot
        score -= Double(severeCount) * 4    // -4 per severe weak spot

        return min(100, max(0, score))
    }

    /// Speed Performance (25%): Average download speed mapped to thresholds
    private static func calculateSpeedPerformance(points: [HeatmapPoint]) -> Double {
        let speeds = points.map(\.downloadSpeed).filter { $0 > 0 }
        guard !speeds.isEmpty else { return 50 } // Neutral default when speed not measured

        let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)

        // Thresholds: 100+ Mbps = perfect, 50+ = good, 25+ = fair, 10+ = poor
        switch avgSpeed {
        case 100...: return 100
        case 50..<100: return 80 + (avgSpeed - 50) / 50 * 20
        case 25..<50: return 65 + (avgSpeed - 25) / 25 * 15
        case 10..<25: return 50 + (avgSpeed - 10) / 15 * 15
        default: return max(0, avgSpeed / 10 * 50)
        }
    }

    /// Reliability (20%): Based on latency consistency (jitter proxy) and packet loss proxy
    private static func calculateReliability(points: [HeatmapPoint]) -> Double {
        let latencies = points.map(\.latency).filter { $0 > 0 }
        guard latencies.count >= 2 else { return 50 } // Neutral default

        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)

        // Calculate jitter as standard deviation of latency
        let variance = latencies.map { pow($0 - avgLatency, 2) }.reduce(0, +) / Double(latencies.count)
        let jitter = sqrt(variance)

        // Failed measurements (latency == -1) count as packet loss
        let failedCount = points.filter { $0.latency < 0 }.count
        let packetLossRate = Double(failedCount) / max(1, Double(points.count))

        var score: Double = 100

        // Penalize for jitter
        if jitter > 50 { score -= 30 }
        else if jitter > 20 { score -= 15 }
        else if jitter > 10 { score -= 5 }

        // Penalize for packet loss
        score -= packetLossRate * 100

        return min(100, max(0, score))
    }

    /// Latency (15%): Median and worst-case latency (median is more robust than mean)
    private static func calculateLatencyScore(points: [HeatmapPoint]) -> Double {
        let latencies = points.map(\.latency).filter { $0 > 0 }.sorted()
        guard !latencies.isEmpty else { return 50 } // Neutral default

        // Use median instead of mean to reduce outlier sensitivity
        let medianLatency: Double
        if latencies.count % 2 == 0 {
            medianLatency = (latencies[latencies.count / 2 - 1] + latencies[latencies.count / 2]) / 2
        } else {
            medianLatency = latencies[latencies.count / 2]
        }
        let worstLatency = latencies.last ?? 0

        var score: Double = 100

        // Median latency penalties
        switch medianLatency {
        case 0..<20: break // excellent
        case 20..<50: score -= 10
        case 50..<100: score -= 25
        case 100..<200: score -= 40
        default: score -= 60
        }

        // Worst-case penalty (smaller weight)
        if worstLatency > 500 { score -= 15 }
        else if worstLatency > 200 { score -= 8 }

        return min(100, max(0, score))
    }

    /// Interference (10%): BLE congestion and competing networks
    private static func calculateInterferenceScore(bleDeviceCount: Int) -> Double {
        switch bleDeviceCount {
        case 0..<5: return 100
        case 5..<10: return 85
        case 10..<20: return 70
        case 20..<30: return 55
        default: return 40
        }
    }
}
