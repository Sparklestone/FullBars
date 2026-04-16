import Foundation
import CoreBluetooth
import Observation

struct BLEDeviceInfo: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var isConnectable: Bool
    var lastSeen: Date
}

@Observable
final class BLEService: NSObject, CBCentralManagerDelegate {
    var discoveredDevices: [BLEDeviceInfo] = []
    var isScanning: Bool = false
    var congestionLevel: String = "Low"
    var congestionScore: Int = 0
    
    private var centralManager: CBCentralManager?
    
    override init() {
        super.init()
    }
    
    func startScanning() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
        }
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? "Unknown"
        let rssi = RSSI.intValue
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
        let uuid = peripheral.identifier
        let now = Date()
        
        if let index = discoveredDevices.firstIndex(where: { $0.id == uuid }) {
            discoveredDevices[index].rssi = rssi
            discoveredDevices[index].lastSeen = now
            discoveredDevices[index].name = name
        } else {
            let device = BLEDeviceInfo(
                id: uuid,
                name: name,
                rssi: rssi,
                isConnectable: isConnectable,
                lastSeen: now
            )
            discoveredDevices.append(device)
        }
        
        updateCongestionLevel()
    }
    
    private func updateCongestionLevel() {
        let strongSignalDevices = discoveredDevices.filter { $0.rssi > -70 }.count
        congestionScore = strongSignalDevices
        
        if strongSignalDevices > 40 {
            congestionLevel = "Severe"
        } else if strongSignalDevices > 20 {
            congestionLevel = "High"
        } else if strongSignalDevices > 10 {
            congestionLevel = "Medium"
        } else {
            congestionLevel = "Low"
        }
    }
}
