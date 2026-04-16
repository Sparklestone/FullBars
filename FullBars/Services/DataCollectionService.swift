import Foundation
import SwiftData
import os

/// Manages anonymous data collection for aggregate insights.
/// Data is only collected when the user has opted in.
/// All data is anonymized — no PII, no location, no MAC addresses.
final class DataCollectionService {
    static let shared = DataCollectionService()
    private let logger = Logger(subsystem: "com.fullbars.app", category: "DataCollection")
    private let profile = UserProfile()

    var isOptedIn: Bool { profile.dataCollectionOptIn }

    /// Builds an anonymous snapshot from the current session data.
    func createSnapshot(
        measuredDownload: Double,
        measuredUpload: Double,
        measuredLatency: Double,
        measuredJitter: Double,
        coverageStrong: Double,
        coverageModerate: Double,
        coverageWeak: Double,
        totalPoints: Int,
        wifiDevices: Int,
        bleDevices: Int,
        grade: String,
        score: Double
    ) -> AnonymousDataSnapshot? {
        guard isOptedIn else {
            logger.info("Data collection not opted in — skipping snapshot")
            return nil
        }

        let snapshot = AnonymousDataSnapshot(
            dwellingType: profile.dwellingType.rawValue,
            squareFootage: profile.squareFootage.rawValue,
            numberOfFloors: profile.numberOfFloors,
            numberOfPeople: profile.numberOfPeople,
            ispName: profile.ispName,
            ispPromisedSpeedMbps: profile.ispPromisedSpeed,
            measuredDownloadMbps: measuredDownload,
            measuredUploadMbps: measuredUpload,
            measuredLatencyMs: measuredLatency,
            measuredJitterMs: measuredJitter,
            coverageStrongPercent: coverageStrong,
            coverageModeratePercent: coverageModerate,
            coverageWeakPercent: coverageWeak,
            totalPointsSampled: totalPoints,
            wifiDeviceCount: wifiDevices,
            bleDeviceCount: bleDevices,
            overallGrade: grade,
            overallScore: score
        )

        logger.info("Anonymous snapshot created for \(self.profile.dwellingType.rawValue)")
        return snapshot
    }

    /// Computes coverage breakdown from walkthrough heatmap points.
    static func coverageBreakdown(from points: [HeatmapPoint]) -> (strong: Double, moderate: Double, weak: Double) {
        guard !points.isEmpty else { return (0, 0, 0) }
        let total = Double(points.count)
        let strong = Double(points.filter { $0.signalStrength >= -60 }.count) / total * 100
        let moderate = Double(points.filter { $0.signalStrength >= -75 && $0.signalStrength < -60 }.count) / total * 100
        let weak = Double(points.filter { $0.signalStrength < -75 }.count) / total * 100
        return (strong, moderate, weak)
    }

    /// Computes the speed deficit vs ISP promised speed.
    static func speedDeficit(measured: Double, promised: Double) -> Double {
        guard promised > 0 else { return 0 }
        return ((promised - measured) / promised) * 100
    }

    /// Coverage quality label based on percentage
    static func coverageLabel(strong: Double, moderate: Double, weak: Double) -> String {
        if strong >= 70 { return "Excellent" }
        if strong >= 50 { return "Good" }
        if strong + moderate >= 70 { return "Moderate" }
        if weak >= 50 { return "Poor" }
        return "Weak"
    }
}
