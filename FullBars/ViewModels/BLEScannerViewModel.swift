import Foundation
import SwiftUI
import Observation

@Observable
final class BLEScannerViewModel {
    var bleService = BLEService()
    
    var isScanning: Bool {
        bleService.isScanning
    }
    
    var devices: [BLEDeviceInfo] {
        bleService.discoveredDevices.sorted { $0.rssi > $1.rssi }
    }
    
    var congestionLevel: String {
        bleService.congestionLevel
    }
    
    var congestionScore: Int {
        bleService.congestionScore
    }
    
    var deviceCount: Int {
        devices.count
    }
    
    var strongDeviceCount: Int {
        devices.filter { $0.rssi > -60 }.count
    }
    
    var interferenceRisk: String {
        switch deviceCount {
        case 0...5:
            return "Low"
        case 6...15:
            return "Medium"
        case 16...30:
            return "High"
        default:
            return "Severe"
        }
    }
    
    func startScan() {
        bleService.startScanning()
    }
    
    func stopScan() {
        bleService.stopScanning()
    }
    
    func toggleScan() {
        if isScanning {
            stopScan()
        } else {
            startScan()
        }
    }
}
