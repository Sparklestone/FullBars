import Foundation
import Network
import Observation

@Observable
final class NetworkMonitorService: NSObject {
    var isConnected: Bool = false
    var connectionType: String = "unknown"
    var isExpensive: Bool = false
    var isConstrained: Bool = false
    var interfaceType: String = "other"
    
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.fullbars.networkmonitor")
    
    override init() {
        super.init()
    }
    
    func startMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                
                // Determine interface type
                if path.usesInterfaceType(.wifi) {
                    self?.interfaceType = "wifi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.interfaceType = "cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.interfaceType = "wiredEthernet"
                } else if path.usesInterfaceType(.loopback) {
                    self?.interfaceType = "loopback"
                } else {
                    self?.interfaceType = "other"
                }
                
                // Determine connection type string
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else {
                    self?.connectionType = "unknown"
                }
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
