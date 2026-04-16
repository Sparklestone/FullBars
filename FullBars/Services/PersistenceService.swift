import Foundation
import SwiftData
import os

final class PersistenceService {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "Persistence")
    static let shared = PersistenceService()

    let container: ModelContainer

    private init() {
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(
                for: NetworkMetrics.self, SpeedTestResult.self, BLEDevice.self, ActionItem.self,
                     HeatmapPoint.self, SpaceGrade.self, WalkthroughSession.self,
                configurations: modelConfiguration
            )
        } catch {
            Self.logger.error("Could not initialize ModelContainer: \(error.localizedDescription). Falling back to in-memory store.")
            // Fallback to in-memory container so the app doesn't crash
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(
                    for: NetworkMetrics.self, SpeedTestResult.self, BLEDevice.self, ActionItem.self,
                         HeatmapPoint.self, SpaceGrade.self, WalkthroughSession.self,
                    configurations: fallbackConfig
                )
            } catch {
                Self.logger.critical("In-memory ModelContainer also failed: \(error.localizedDescription)")
                // Last resort: create a minimal container
                container = try! ModelContainer(
                    for: NetworkMetrics.self, SpeedTestResult.self, BLEDevice.self, ActionItem.self,
                        HeatmapPoint.self, SpaceGrade.self, WalkthroughSession.self
                )
            }
        }
    }
    
    // MARK: - Metrics Operations
    
    static func saveMetricsSnapshot(
        ssid: String,
        bssid: String,
        signalStrength: Int,
        linkSpeed: Double,
        latency: Double,
        jitter: Double,
        packetLoss: Double,
        connectionType: String,
        downloadSpeed: Double,
        uploadSpeed: Double,
        context: ModelContext
    ) {
        let metrics = NetworkMetrics(
            timestamp: Date(),
            ssid: ssid,
            bssid: bssid,
            signalStrength: signalStrength,
            linkSpeed: linkSpeed,
            latency: latency,
            jitter: jitter,
            packetLoss: packetLoss,
            connectionType: connectionType,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed
        )
        
        context.insert(metrics)
        
        do {
            try context.save()
        } catch {
            Self.logger.error("Failed to save metrics snapshot: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Cleanup
    
    static func clearOldData(olderThan date: Date, context: ModelContext) {
        do {
            try context.delete(model: NetworkMetrics.self, where: #Predicate { metric in
                metric.timestamp < date
            })
            
            try context.delete(model: SpeedTestResult.self, where: #Predicate { result in
                result.timestamp < date
            })
            
            try context.save()
        } catch {
            Self.logger.error("Failed to clear old data: \(error.localizedDescription)")
        }
    }
}
