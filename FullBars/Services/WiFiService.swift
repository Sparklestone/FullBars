import Foundation
import NetworkExtension
import CoreLocation
import Observation

@Observable
final class WiFiService: NSObject, CLLocationManagerDelegate {
    var currentSSID: String = "Unknown"
    var currentBSSID: String = ""
    var signalStrength: Int = 0
    var isConnected: Bool = false
    /// Signal strength is estimated from NEHotspotNetwork's 0.0–1.0 range, not raw RSSI.
    var isSignalEstimated: Bool = true
    var locationAuthorized: Bool = false
    
    private var monitoringTask: Task<Void, Never>?
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways
    }
    
    /// Must be called before WiFi data will be available on a real device.
    func requestLocationPermission() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorized = manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
    }
    
    func fetchCurrentNetwork() async {
        do {
            guard let network = try await NEHotspotNetwork.fetchCurrent() else {
                await MainActor.run {
                    self.isConnected = false
                    self.currentSSID = "Unknown"
                    self.currentBSSID = ""
                    self.signalStrength = 0
                }
                return
            }
            
            let ssid = network.ssid
            let bssid = network.bssid
            let strength = network.signalStrength
            
            // Convert strength (0.0-1.0) to dBm estimate: -100 + (strength * 70)
            let signalStrengthDBm = Int(-100 + (strength * 70))
            
            await MainActor.run {
                self.currentSSID = ssid
                self.currentBSSID = bssid
                self.signalStrength = signalStrengthDBm
                self.isConnected = true
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.currentSSID = "Unknown"
                self.currentBSSID = ""
                self.signalStrength = 0
            }
        }
    }
    
    func startContinuousMonitoring() {
        // Location authorization is required for NEHotspotNetwork to return data
        requestLocationPermission()
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await fetchCurrentNetwork()
                
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                } catch {
                    break
                }
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
