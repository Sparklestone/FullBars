import Foundation
import SwiftData

@Model
final class SpeedTestResult {
    var id: UUID
    var timestamp: Date
    var downloadSpeed: Double
    var uploadSpeed: Double
    var latency: Double
    var jitter: Double
    var packetLoss: Double
    var serverName: String
    var serverLocation: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        downloadSpeed: Double = 0,
        uploadSpeed: Double = 0,
        latency: Double = 0,
        jitter: Double = 0,
        packetLoss: Double = 0,
        serverName: String = "",
        serverLocation: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.latency = latency
        self.jitter = jitter
        self.packetLoss = packetLoss
        self.serverName = serverName
        self.serverLocation = serverLocation
    }
}
