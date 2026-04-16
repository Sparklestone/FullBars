import Foundation
import Observation

@Observable
final class SpeedTestService: NSObject {
    var isRunning: Bool = false
    var progress: Double = 0.0
    var currentPhase: String = ""
    var downloadSpeed: Double = 0.0
    var uploadSpeed: Double = 0.0
    var latency: Double = 0.0
    var jitter: Double = 0.0
    var packetLoss: Double = 0.0
    
    private let session = URLSession.shared
    private let pingTargets = [
        "https://www.apple.com",
        "https://www.google.com",
        "https://one.one.one.one"
    ]
    
    func runFullTest() async -> SpeedTestResult? {
        await MainActor.run {
            self.isRunning = true
            self.progress = 0.0
        }
        
        defer {
            Task { @MainActor in
                self.isRunning = false
            }
        }
        
        do {
            // Phase 1: Measure Latency
            await measureLatency()
            await MainActor.run { self.progress = 0.33 }
            
            // Phase 2: Measure Download Speed
            await measureDownloadSpeed()
            await MainActor.run { self.progress = 0.66 }
            
            // Phase 3: Measure Upload Speed
            await measureUploadSpeed()
            await MainActor.run { self.progress = 1.0 }
            
            // Create and return result - match SpeedTestResult init parameter order
            let result = SpeedTestResult(
                timestamp: Date(),
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                latency: latency,
                jitter: jitter,
                packetLoss: packetLoss,
                serverName: "Cloudflare",
                serverLocation: "Auto"
            )
            return result
        } catch {
            return nil
        }
    }
    
    private func measureLatency() async {
        await MainActor.run { self.currentPhase = "Measuring Latency..." }
        
        var latencies: [Double] = []
        let pingCount = 10
        var failedPings = 0
        
        for target in pingTargets {
            for _ in 0..<(pingCount / pingTargets.count) {
                let startTime = Date()
                do {
                    var request = URLRequest(url: URL(string: target)!)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0
                    let _ = try await session.data(for: request)
                    let latency = Date().timeIntervalSince(startTime) * 1000 // ms
                    latencies.append(latency)
                } catch {
                    failedPings += 1
                }
            }
        }
        
        let avgLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let jitterValue = calculateJitter(latencies)
        let packetLossPercent = Double(failedPings) / Double(pingCount) * 100
        
        await MainActor.run {
            self.latency = avgLatency
            self.jitter = jitterValue
            self.packetLoss = packetLossPercent
        }
    }
    
    private func measureDownloadSpeed() async {
        await MainActor.run { self.currentPhase = "Measuring Download Speed..." }
        
        do {
            let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!
            let startTime = Date()
            
            let (data, _) = try await session.data(from: downloadURL)
            let totalBytes = data.count
            
            let elapsedSeconds = Date().timeIntervalSince(startTime)
            let megabits = Double(totalBytes) * 8 / 1_000_000
            let mbps = elapsedSeconds > 0 ? megabits / elapsedSeconds : 0
            
            await MainActor.run { self.downloadSpeed = mbps }
        } catch {
            await MainActor.run { self.downloadSpeed = 0 }
        }
    }
    
    private func measureUploadSpeed() async {
        await MainActor.run { self.currentPhase = "Measuring Upload Speed..." }
        
        do {
            let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
            let uploadData = Data(count: 5_000_000)
            
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.httpBody = uploadData
            
            let startTime = Date()
            let _ = try await session.data(for: request)
            let elapsedSeconds = Date().timeIntervalSince(startTime)
            
            let megabits = Double(uploadData.count) * 8 / 1_000_000
            let mbps = elapsedSeconds > 0 ? megabits / elapsedSeconds : 0
            
            await MainActor.run { self.uploadSpeed = mbps }
        } catch {
            await MainActor.run { self.uploadSpeed = 0 }
        }
    }
    
    private func calculateJitter(_ latencies: [Double]) -> Double {
        guard latencies.count > 1 else { return 0 }
        let mean = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.reduce(0) { $0 + pow($1 - mean, 2) } / Double(latencies.count)
        return sqrt(variance)
    }
}
