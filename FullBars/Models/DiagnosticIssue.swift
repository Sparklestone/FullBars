import Foundation
import SwiftUI

enum IssueSeverity: String, CaseIterable, Codable, Comparable {
    case info
    case warning
    case critical

    // Comparable: info < warning < critical
    static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        let order: [IssueSeverity] = [.info, .warning, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
    
    var color: Color {
        switch self {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .critical:
            return "exclamationmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var label: String {
        switch self {
        case .critical:
            return "Critical"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        }
    }
}

enum IssueCategory: String, CaseIterable, Codable {
    case signalStrength
    case latency
    case packetLoss
    case congestion
    case interference
    case speed
    case general
}

struct DiagnosticIssue: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var severity: IssueSeverity
    var category: IssueCategory
    var suggestion: String
    var fixSteps: [String]
    var detectedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        severity: IssueSeverity = .info,
        category: IssueCategory = .general,
        suggestion: String = "",
        fixSteps: [String] = [],
        detectedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.category = category
        self.suggestion = suggestion
        self.fixSteps = fixSteps
        self.detectedAt = detectedAt
    }

    /// Default fix steps based on issue category
    static func defaultFixSteps(for category: IssueCategory) -> [String] {
        switch category {
        case .signalStrength:
            return [
                "Check your router's location — it should be in a central, elevated spot",
                "Remove obstructions between the router and weak areas (metal shelves, aquariums, mirrors)",
                "If using a mesh system, move or add a node closer to the weak zone",
                "Rescan the room to verify signal improvement",
            ]
        case .latency:
            return [
                "Check if other devices are using heavy bandwidth (streaming, large downloads)",
                "Restart your router — hold the power button for 10 seconds, wait 30 seconds, power on",
                "Switch to 5 GHz band if you're on 2.4 GHz (shorter range but lower latency)",
                "Run a speed test to verify improvement",
            ]
        case .speed:
            return [
                "Run a wired speed test from your router to confirm ISP speeds are correct",
                "If wired speeds are low, contact your ISP — you may not be getting what you pay for",
                "If wired is fine but wireless is slow, your router may need upgrading",
                "Rescan after changes to update your grade",
            ]
        case .interference:
            return [
                "Open the BLE scanner to identify nearby devices causing interference",
                "Move interfering devices (microwaves, baby monitors, Bluetooth speakers) away from your router",
                "Switch your router to a less congested channel (use Auto or try channels 1, 6, or 11 on 2.4 GHz)",
                "Rescan to verify interference has reduced",
            ]
        case .congestion:
            return [
                "Check how many devices are connected to your network",
                "Enable QoS (Quality of Service) on your router to prioritize important traffic",
                "Consider upgrading to WiFi 6/6E which handles many devices better",
                "Rescan after reducing connected devices",
            ]
        case .packetLoss:
            return [
                "Restart your router and modem",
                "Check for firmware updates on your router",
                "If packet loss persists, contact your ISP — it may be a line issue",
                "Run another speed test to verify the problem is resolved",
            ]
        case .general:
            return [
                "Review the specific issue description above",
                "Try restarting your router as a first step",
                "Rescan the affected room after making changes",
            ]
        }
    }
}
