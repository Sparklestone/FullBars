import Foundation
import SwiftUI
import Observation
import SwiftData

@Observable
final class SpeedTestViewModel {
    var speedTestService = SpeedTestService()
    
    var currentResult: SpeedTestResult? = nil
    var testHistory: [SpeedTestResult] = []
    var errorMessage: String? = nil
    
    var isRunning: Bool {
        speedTestService.isRunning
    }
    
    var progress: Double {
        speedTestService.progress
    }
    
    var currentPhase: String {
        speedTestService.currentPhase
    }
    
    func runTest() async {
        errorMessage = nil
        
        if let result = await speedTestService.runFullTest() {
            currentResult = result
            testHistory.insert(result, at: 0)
        } else {
            errorMessage = "Speed test failed. Please check your connection."
        }
    }
    
    func loadHistory(context: ModelContext) {
        let descriptor = FetchDescriptor<SpeedTestResult>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let allResults = try context.fetch(descriptor)
            testHistory = Array(allResults.prefix(20))
        } catch {
            errorMessage = "Failed to load history: \(error.localizedDescription)"
        }
    }
    
    func generateReport() -> String {
        var reportText = "Speed Test Report\n"
        reportText += "==================\n\n"
        
        if let current = currentResult {
            reportText += "Latest Test Results:\n"
            reportText += String(format: "Download: %.2f Mbps\n", current.downloadSpeed)
            reportText += String(format: "Upload: %.2f Mbps\n", current.uploadSpeed)
            reportText += String(format: "Latency: %.2f ms\n", current.latency)
            reportText += String(format: "Jitter: %.2f ms\n", current.jitter)
            reportText += String(format: "Packet Loss: %.2f%%\n\n", current.packetLoss)
        }
        
        if !testHistory.isEmpty {
            reportText += "Average Performance (Last \(testHistory.count) tests):\n"
            let avgDownload = testHistory.map { $0.downloadSpeed }.reduce(0, +) / Double(testHistory.count)
            let avgUpload = testHistory.map { $0.uploadSpeed }.reduce(0, +) / Double(testHistory.count)
            let avgLatency = testHistory.map { $0.latency }.reduce(0, +) / Double(testHistory.count)
            
            reportText += String(format: "Avg Download: %.2f Mbps\n", avgDownload)
            reportText += String(format: "Avg Upload: %.2f Mbps\n", avgUpload)
            reportText += String(format: "Avg Latency: %.2f ms\n", avgLatency)
        }
        
        return reportText
    }
}
