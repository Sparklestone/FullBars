import Foundation
import SwiftData
import SwiftUI

enum BLESignalQuality: String, CaseIterable {
    case strong
    case medium
    case weak
    case veryWeak

    var color: Color {
        switch self {
        case .strong:
            return FullBars.Design.Colors.signalExcellent
        case .medium:
            return FullBars.Design.Colors.signalGood
        case .weak:
            return FullBars.Design.Colors.signalFair
        case .veryWeak:
            return FullBars.Design.Colors.signalNoSignal
        }
    }
    
    var label: String {
        switch self {
        case .strong:
            return "Strong"
        case .medium:
            return "Medium"
        case .weak:
            return "Weak"
        case .veryWeak:
            return "Very Weak"
        }
    }
}

@Model
final class BLEDevice {
    var id: UUID
    var name: String
    var identifier: String
    var rssi: Int
    var lastSeen: Date
    var isConnectable: Bool
    var advertisedServices: String
    
    init(
        id: UUID = UUID(),
        name: String = "",
        identifier: String = "",
        rssi: Int = 0,
        lastSeen: Date = .now,
        isConnectable: Bool = false,
        advertisedServices: String = ""
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.rssi = rssi
        self.lastSeen = lastSeen
        self.isConnectable = isConnectable
        self.advertisedServices = advertisedServices
    }
    
    var signalQuality: BLESignalQuality {
        switch rssi {
        case -50...0:
            return .strong
        case -70..<(-50):
            return .medium
        case -85..<(-70):
            return .weak
        default:
            return .veryWeak
        }
    }
}
