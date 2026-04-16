import Foundation
import SwiftUI
import Observation
import SwiftData

@Observable
final class DashboardViewModel {
    var networkMonitor = NetworkMonitorService()
    var wifiService = WiFiService()
    
    var healthScore: Int = 0
    var signalQuality: SignalQuality = .noSignal
    var recentIssues: [DiagnosticIssue] = []
    var isLoading: Bool = true
    var metricsHistory: [NetworkMetrics] = []
    
    func startMonitoring() {
        networkMonitor.startMonitoring()
        wifiService.startContinuousMonitoring()
        
        Task {
            await refreshData()
            isLoading = false
        }
    }
    
    func stopMonitoring() {
        networkMonitor.stopMonitoring()
        wifiService.stopMonitoring()
    }
    
    func refreshDiagnostics() {
        let signalStrength = wifiService.signalStrength
        
        healthScore = DiagnosticsEngine.calculateHealthScore(
            signalStrength: signalStrength,
            latency: 0,
            packetLoss: 0,
            downloadSpeed: 0
        )
        
        signalQuality = determineSignalQuality(from: signalStrength)
        
        recentIssues = DiagnosticsEngine.analyze(
            signalStrength: signalStrength,
            latency: 0,
            jitter: 0,
            packetLoss: 0,
            downloadSpeed: 0,
            uploadSpeed: 0,
            bleDeviceCount: 0,
            connectionType: networkMonitor.connectionType
        )
    }
    
    func refreshData() async {
        await wifiService.fetchCurrentNetwork()
        refreshDiagnostics()
    }
    
    private func determineSignalQuality(from signalStrength: Int) -> SignalQuality {
        switch signalStrength {
        case -30...0:
            return .excellent
        case -67..<(-30):
            return .good
        case -70..<(-67):
            return .fair
        case -80..<(-70):
            return .poor
        default:
            return .noSignal
        }
    }
}
