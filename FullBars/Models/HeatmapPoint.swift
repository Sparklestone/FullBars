import Foundation
import SwiftData
import SwiftUI

@Model
final class HeatmapPoint {
    var id: UUID
    var x: Double
    var y: Double
    var z: Double
    var signalStrength: Int
    var latency: Double
    var downloadSpeed: Double
    var timestamp: Date
    var sessionId: UUID
    var roomName: String?
    var floorIndex: Int = 0
    var roomId: UUID?             // NEW — ties a point to a specific Room
    var homeId: UUID?             // NEW — ties a point to a specific Home

    init(
        id: UUID = UUID(),
        x: Double = 0,
        y: Double = 0,
        z: Double = 0,
        signalStrength: Int = 0,
        latency: Double = 0,
        downloadSpeed: Double = 0,
        timestamp: Date = .now,
        sessionId: UUID = UUID(),
        roomName: String? = nil,
        floorIndex: Int = 0,
        roomId: UUID? = nil,
        homeId: UUID? = nil
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.z = z
        self.signalStrength = signalStrength
        self.latency = latency
        self.downloadSpeed = downloadSpeed
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.roomName = roomName
        self.floorIndex = floorIndex
        self.roomId = roomId
        self.homeId = homeId
    }
    
    var color: Color {
        switch signalStrength {
        case -50...0:
            return .green
        case -60..<(-50):
            return .blue
        case -70..<(-60):
            return .yellow
        case -80..<(-70):
            return .orange
        default:
            return .red
        }
    }
}
