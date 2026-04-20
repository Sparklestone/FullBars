import Foundation
import SwiftUI
import Observation
import SwiftData
import os

@Observable
final class SettingsViewModel {
    private static let logger = Logger(subsystem: "com.fullbars.app", category: "Settings")
    var appVersion: String = "1.0.0"
    var buildNumber: String = "1"
    
    private let userDefaults = UserDefaults.standard
    
    var isDarkMode: Bool {
        get {
            if userDefaults.object(forKey: "isDarkMode") == nil { return true }
            return userDefaults.bool(forKey: "isDarkMode")
        }
        set { userDefaults.set(newValue, forKey: "isDarkMode") }
    }
    
    var measurementUnit: String {
        get { userDefaults.string(forKey: "measurementUnit") ?? "metric" }
        set { userDefaults.set(newValue, forKey: "measurementUnit") }
    }
    
    var notifyOnSignalDrop: Bool {
        get {
            if userDefaults.object(forKey: "notifyOnSignalDrop") == nil { return true }
            return userDefaults.bool(forKey: "notifyOnSignalDrop")
        }
        set { userDefaults.set(newValue, forKey: "notifyOnSignalDrop") }
    }
    
    var signalDropThreshold: Int {
        get { userDefaults.integer(forKey: "signalDropThreshold") == 0 ? -75 : userDefaults.integer(forKey: "signalDropThreshold") }
        set { userDefaults.set(newValue, forKey: "signalDropThreshold") }
    }
    
    var dataRetentionDays: Int {
        get { userDefaults.integer(forKey: "dataRetentionDays") == 0 ? 30 : userDefaults.integer(forKey: "dataRetentionDays") }
        set { userDefaults.set(newValue, forKey: "dataRetentionDays") }
    }
    
    var autoRefreshInterval: Int {
        get { userDefaults.integer(forKey: "autoRefreshInterval") == 0 ? 5 : userDefaults.integer(forKey: "autoRefreshInterval") }
        set { userDefaults.set(newValue, forKey: "autoRefreshInterval") }
    }
    
    var showAdvancedMetrics: Bool {
        get { userDefaults.bool(forKey: "showAdvancedMetrics") }
        set { userDefaults.set(newValue, forKey: "showAdvancedMetrics") }
    }

    var ispPromisedSpeed: Double {
        get { userDefaults.double(forKey: "ispPromisedSpeed") }
        set { userDefaults.set(newValue, forKey: "ispPromisedSpeed") }
    }

    var ispName: String {
        get { userDefaults.string(forKey: "ispName") ?? "" }
        set { userDefaults.set(newValue, forKey: "ispName") }
    }

    var displayMode: DisplayMode {
        get {
            let raw = userDefaults.string(forKey: "displayMode") ?? DisplayMode.basic.rawValue
            return DisplayMode(rawValue: raw) ?? .basic
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: "displayMode")
        }
    }
    
    func resetToDefaults() {
        userDefaults.set(true, forKey: "isDarkMode")
        userDefaults.set("metric", forKey: "measurementUnit")
        userDefaults.set(true, forKey: "notifyOnSignalDrop")
        userDefaults.set(-75, forKey: "signalDropThreshold")
        userDefaults.set(30, forKey: "dataRetentionDays")
        userDefaults.set(5, forKey: "autoRefreshInterval")
        userDefaults.set(false, forKey: "showAdvancedMetrics")
        userDefaults.set(DisplayMode.basic.rawValue, forKey: "displayMode")
        userDefaults.synchronize()
    }
    
    func clearAllData(context: ModelContext) {
        do {
            try context.delete(model: NetworkMetrics.self)
            try context.delete(model: SpeedTestResult.self)
            try context.delete(model: HeatmapPoint.self)
            try context.delete(model: ActionItem.self)
            try context.delete(model: SpaceGrade.self)
            try context.delete(model: WalkthroughSession.self)
            try context.delete(model: Room.self)
            try context.delete(model: Doorway.self)
            try context.delete(model: DevicePlacement.self)
            try context.delete(model: HomeConfiguration.self)
            try context.delete(model: AnonymousDataSnapshot.self)
            try context.save()
            // Also clear onboarding so user starts fresh
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "lastUsedFloorIndex")
        } catch {
            Self.logger.error("Error clearing data: \(error.localizedDescription)")
        }
    }
    
    func exportDiagnosticData(context: ModelContext) -> String {
        var export = "{\n"
        export += "  \"exportDate\": \"\(ISO8601DateFormatter().string(from: .now))\",\n"
        export += "  \"appVersion\": \"\(appVersion)\",\n"
        export += "  \"settings\": {\n"
        export += "    \"isDarkMode\": \(isDarkMode),\n"
        export += "    \"measurementUnit\": \"\(measurementUnit)\",\n"
        export += "    \"notifyOnSignalDrop\": \(notifyOnSignalDrop),\n"
        export += "    \"signalDropThreshold\": \(signalDropThreshold),\n"
        export += "    \"dataRetentionDays\": \(dataRetentionDays),\n"
        export += "    \"autoRefreshInterval\": \(autoRefreshInterval),\n"
        export += "    \"showAdvancedMetrics\": \(showAdvancedMetrics)\n"
        export += "  },\n"
        export += "  \"recentData\": {\n"
        
        do {
            let metricsDescriptor = FetchDescriptor<NetworkMetrics>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let metrics = try context.fetch(metricsDescriptor).prefix(5)
            export += "    \"networkMetrics\": \(metrics.count),\n"
            
            let speedDescriptor = FetchDescriptor<SpeedTestResult>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let speedTests = try context.fetch(speedDescriptor).prefix(5)
            export += "    \"speedTests\": \(speedTests.count),\n"
            
            let heatmapDescriptor = FetchDescriptor<HeatmapPoint>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let heatmapPoints = try context.fetch(heatmapDescriptor).prefix(100)
            export += "    \"heatmapPoints\": \(heatmapPoints.count)\n"
        } catch {
            export += "    \"error\": \"Failed to fetch data\"\n"
        }
        
        export += "  }\n"
        export += "}\n"
        
        return export
    }
}
