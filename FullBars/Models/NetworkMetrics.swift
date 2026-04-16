import Foundation
import SwiftData
import SwiftUI

enum SignalQuality: String, CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case noSignal

    var color: Color {
        switch self {
        case .excellent:
            return FullBars.Design.Colors.signalExcellent
        case .good:
            return FullBars.Design.Colors.signalGood
        case .fair:
            return FullBars.Design.Colors.signalFair
        case .poor:
            return FullBars.Design.Colors.signalPoor
        case .noSignal:
            return FullBars.Design.Colors.signalNoSignal
        }
    }
    
    var label: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .noSignal:
            return "No Signal"
        }
    }
    
    var score: Int {
        switch self {
        case .excellent:
            return 100
        case .good:
            return 75
        case .fair:
            return 50
        case .poor:
            return 25
        case .noSignal:
            return 0
        }
    }
}

@Model
final class NetworkMetrics {
    var id: UUID
    var timestamp: Date
    var ssid: String
    var bssid: String
    var signalStrength: Int
    var linkSpeed: Double
    var latency: Double
    var jitter: Double
    var packetLoss: Double
    var connectionType: String
    var downloadSpeed: Double
    var uploadSpeed: Double
    
    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        ssid: String = "",
        bssid: String = "",
        signalStrength: Int = 0,
        linkSpeed: Double = 0,
        latency: Double = 0,
        jitter: Double = 0,
        packetLoss: Double = 0,
        connectionType: String = "unknown",
        downloadSpeed: Double = 0,
        uploadSpeed: Double = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.ssid = ssid
        self.bssid = bssid
        self.signalStrength = signalStrength
        self.linkSpeed = linkSpeed
        self.latency = latency
        self.jitter = jitter
        self.packetLoss = packetLoss
        self.connectionType = connectionType
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
    }
    
    var signalQuality: SignalQuality {
        switch signalStrength {
        case -50...0:
            return .excellent
        case -60..<(-50):
            return .good
        case -70..<(-60):
            return .fair
        case -80..<(-70):
            return .poor
        default:
            return .noSignal
        }
    }
}
