import Foundation
import SwiftUI
import Observation

@Observable
final class SignalMonitorViewModel {
    var wifiService = WiFiService()
    var networkMonitor = NetworkMonitorService()
    
    var signalHistory: [SignalDataPoint] = []
    var latencyHistory: [SignalDataPoint] = []
    
    var currentSignalStrength: Int = 0
    var currentLatency: Double = 0
    
    var minSignal: Int = 0
    var maxSignal: Int = 0
    var avgSignal: Double = 0
    
    var minLatency: Double = 0
    var maxLatency: Double = 0
    var avgLatency: Double = 0
    
    var isMonitoring: Bool = false
    
    private var monitoringTask: Task<Void, Never>?
    private let historyMaxDuration: TimeInterval = 60
    
    func startMonitoring() {
        isMonitoring = true
        wifiService.startContinuousMonitoring()
        networkMonitor.startMonitoring()
        
        monitoringTask = Task {
            while !Task.isCancelled && isMonitoring {
                await fetchAndRecordData()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        wifiService.stopMonitoring()
        networkMonitor.stopMonitoring()
    }
    
    private func fetchAndRecordData() async {
        await wifiService.fetchCurrentNetwork()
        let signal = wifiService.signalStrength
        let latency = await measureLatency()
        
        currentSignalStrength = signal
        currentLatency = latency
        
        let now = Date()
        signalHistory.append(SignalDataPoint(date: now, value: Double(signal)))
        latencyHistory.append(SignalDataPoint(date: now, value: latency))
        
        trimHistories()
        updateStatistics()
    }
    
    private func trimHistories() {
        let cutoff = Date().addingTimeInterval(-historyMaxDuration)
        signalHistory.removeAll { $0.date < cutoff }
        latencyHistory.removeAll { $0.date < cutoff }
    }
    
    private func updateStatistics() {
        let signals = signalHistory.map { Int($0.value) }
        if !signals.isEmpty {
            minSignal = signals.min() ?? 0
            maxSignal = signals.max() ?? 0
            avgSignal = Double(signals.reduce(0, +)) / Double(signals.count)
        }
        
        let latencies = latencyHistory.map { $0.value }
        if !latencies.isEmpty {
            minLatency = latencies.min() ?? 0
            maxLatency = latencies.max() ?? 0
            avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        }
    }
    
    func measureLatency() async -> Double {
        let url = URL(string: "https://www.apple.com")!
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(startTime)
            return elapsed * 1000
        } catch {
            return -1
        }
    }
}

struct SignalDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
