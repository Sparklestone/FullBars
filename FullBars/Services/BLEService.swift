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
    private var ageOutTimer: Timer?

    // MARK: - Thresholds

    /// Only count devices with signal stronger than this. -80 dBm filters out
    /// distant devices (neighbour's AirPods, passing cars, etc.) while keeping
    /// anything genuinely close enough to cause 2.4 GHz interference.
    private static let rssiFloor: Int = -80

    /// Remove devices not seen in this many seconds. BLE advertisements are
    /// typically 100ms–1s apart, so 30s is generous for genuinely nearby devices.
    private static let ageOutSeconds: TimeInterval = 30

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
        startAgeOutTimer()
    }

    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        ageOutTimer?.invalidate()
        ageOutTimer = nil
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

        // Ignore devices with very weak signal — they're too far away to matter
        guard rssi >= Self.rssiFloor, rssi < 0 else { return }

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

    // MARK: - Aging

    /// Periodically remove devices that haven't advertised recently.
    private func startAgeOutTimer() {
        ageOutTimer?.invalidate()
        ageOutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.ageOutStaleDevices()
        }
    }

    private func ageOutStaleDevices() {
        let cutoff = Date().addingTimeInterval(-Self.ageOutSeconds)
        discoveredDevices.removeAll { $0.lastSeen < cutoff }
        updateCongestionLevel()
    }

    // MARK: - Congestion

    private func updateCongestionLevel() {
        // Count devices with strong-enough signal to actually cause interference
        let strongSignalDevices = discoveredDevices.filter { $0.rssi > -70 }.count
        congestionScore = strongSignalDevices

        if strongSignalDevices > 30 {
            congestionLevel = "Severe"
        } else if strongSignalDevices > 15 {
            congestionLevel = "High"
        } else if strongSignalDevices > 8 {
            congestionLevel = "Medium"
        } else {
            congestionLevel = "Low"
        }
    }
}
