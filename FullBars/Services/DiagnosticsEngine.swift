import Foundation
import SwiftUI

struct DiagnosticsEngine {

    static func analyze(
        signalStrength: Int,
        latency: Double,
        jitter: Double,
        packetLoss: Double,
        downloadSpeed: Double,
        uploadSpeed: Double,
        bleDeviceCount: Int,
        connectionType: String
    ) -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []

        // Signal Strength Analysis
        if signalStrength < -80 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Weak WiFi Signal",
                description: "WiFi signal strength is below -80 dBm, which indicates poor connection quality.",
                severity: .critical,
                category: .signalStrength,
                suggestion: "Move closer to the WiFi router or remove obstacles blocking the signal.",
                detectedAt: Date()
            ))
        } else if signalStrength >= -80 && signalStrength < -70 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Fair WiFi Signal",
                description: "WiFi signal strength is between -80 and -70 dBm, which may affect performance.",
                severity: .warning,
                category: .signalStrength,
                suggestion: "Consider moving closer to the router for improved signal quality.",
                detectedAt: Date()
            ))
        }

        // Latency Analysis
        if latency > 200 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Very High Latency",
                description: "Network latency exceeds 200ms, causing noticeable delays.",
                severity: .critical,
                category: .latency,
                suggestion: "Check for network congestion or background applications consuming bandwidth.",
                detectedAt: Date()
            ))
        } else if latency >= 100 && latency <= 200 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Elevated Latency",
                description: "Network latency is between 100-200ms, which may affect real-time activities.",
                severity: .warning,
                category: .latency,
                suggestion: "Monitor network usage and consider optimizing your connection.",
                detectedAt: Date()
            ))
        }

        // Jitter Analysis
        if jitter > 50 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "High Jitter Detected",
                description: "Network jitter (latency variance) is above 50ms.",
                severity: .warning,
                category: .latency,
                suggestion: "Jitter can affect VoIP and streaming. Reduce network interference and congestion.",
                detectedAt: Date()
            ))
        }

        // Packet Loss Analysis
        if packetLoss > 5 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Significant Packet Loss",
                description: "Packet loss exceeds 5%, indicating unreliable connection.",
                severity: .critical,
                category: .packetLoss,
                suggestion: "Check signal quality and network stability. Consider switching channels or routers.",
                detectedAt: Date()
            ))
        } else if packetLoss >= 1 && packetLoss <= 5 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Minor Packet Loss",
                description: "Packet loss between 1-5% may impact performance.",
                severity: .warning,
                category: .packetLoss,
                suggestion: "Monitor connection stability and reduce environmental interference.",
                detectedAt: Date()
            ))
        }

        // Download Speed Analysis
        if downloadSpeed < 5 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Very Slow Download Speed",
                description: "Download speed is below 5 Mbps.",
                severity: .critical,
                category: .speed,
                suggestion: "Upgrade your internet plan or improve WiFi signal strength.",
                detectedAt: Date()
            ))
        } else if downloadSpeed >= 5 && downloadSpeed < 25 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Below Average Download Speed",
                description: "Download speed is between 5-25 Mbps.",
                severity: .warning,
                category: .speed,
                suggestion: "Consider optimizing your network setup or contacting your ISP.",
                detectedAt: Date()
            ))
        }

        // Upload Speed Analysis
        if uploadSpeed < 2 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Very Slow Upload Speed",
                description: "Upload speed is below 2 Mbps.",
                severity: .critical,
                category: .speed,
                suggestion: "Upload speed is critical for video calls and file uploads. Optimize your connection.",
                detectedAt: Date()
            ))
        } else if uploadSpeed >= 2 && uploadSpeed < 10 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Below Average Upload Speed",
                description: "Upload speed is between 2-10 Mbps.",
                severity: .warning,
                category: .speed,
                suggestion: "Upload performance could be improved through network optimization.",
                detectedAt: Date()
            ))
        }

        // BLE Congestion Analysis
        if bleDeviceCount > 40 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "Critical 2.4GHz Congestion",
                description: "More than 40 BLE devices detected, indicating severe 2.4GHz band congestion.",
                severity: .critical,
                category: .interference,
                suggestion: "Move away from congested areas or use 5GHz WiFi if available.",
                detectedAt: Date()
            ))
        } else if bleDeviceCount > 20 {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "High 2.4GHz Congestion",
                description: "More than 20 BLE devices detected on the 2.4GHz band.",
                severity: .warning,
                category: .interference,
                suggestion: "Consider switching to 5GHz WiFi or changing WiFi channels.",
                detectedAt: Date()
            ))
        }

        // Connection Type Analysis
        if connectionType.lowercased() == "cellular" {
            issues.append(DiagnosticIssue(
                id: UUID(),
                title: "On Cellular Network",
                description: "Device is currently connected via cellular data.",
                severity: .info,
                category: .general,
                suggestion: "For better performance on data-intensive tasks, connect to WiFi when possible.",
                detectedAt: Date()
            ))
        }

        return issues
    }

    static func generateActionItems(from issues: [DiagnosticIssue]) -> [ActionItem] {
        return issues.compactMap { issue in
            guard issue.severity == .critical || issue.severity == .warning else { return nil }

            let priority = issue.severity == .critical ? 1 : 2
            return ActionItem(
                id: UUID(),
                title: issue.title,
                itemDescription: issue.suggestion,
                priority: priority,
                isCompleted: false,
                createdAt: Date()
            )
        }
    }

    static func calculateHealthScore(
        signalStrength: Int,
        latency: Double,
        packetLoss: Double,
        downloadSpeed: Double
    ) -> Int {
        var score: Double = 100

        // Signal strength: 30%
        let signalScore: Double = {
            if signalStrength >= -50 { return 100 }
            if signalStrength >= -70 { return 80 }
            if signalStrength >= -80 { return 50 }
            return 20
        }()
        score -= (100 - signalScore) * 0.30

        // Latency: 25%
        let latencyScore: Double = {
            if latency <= 50 { return 100 }
            if latency <= 100 { return 80 }
            if latency <= 200 { return 50 }
            return 20
        }()
        score -= (100 - latencyScore) * 0.25

        // Packet Loss: 25%
        let packetLossScore: Double = {
            if packetLoss < 1 { return 100 }
            if packetLoss < 5 { return 70 }
            if packetLoss < 10 { return 40 }
            return 10
        }()
        score -= (100 - packetLossScore) * 0.25

        // Download Speed: 20%
        let speedScore: Double = {
            if downloadSpeed >= 100 { return 100 }
            if downloadSpeed >= 25 { return 80 }
            if downloadSpeed >= 5 { return 50 }
            return 20
        }()
        score -= (100 - speedScore) * 0.20

        return max(0, min(100, Int(score)))
    }

    // MARK: - Guided Fix Suggestions

    /// Generates specific, actionable fix suggestions with product recommendations
    /// based on the detected issues. Goes beyond "move closer to router" with
    /// real solutions users can act on.
    static func generateGuidedFixes(from issues: [DiagnosticIssue], signalStrength: Int, downloadSpeed: Double, bleDeviceCount: Int) -> [GuidedFix] {
        var fixes: [GuidedFix] = []

        // Weak signal fixes
        let hasWeakSignal = issues.contains { $0.category == .signalStrength && $0.severity == .critical }
        let hasFairSignal = issues.contains { $0.category == .signalStrength && $0.severity == .warning }

        if hasWeakSignal {
            fixes.append(GuidedFix(
                title: "Add a WiFi Mesh System",
                description: "Your signal is very weak in this area. A mesh WiFi system places multiple access points around your home to eliminate weak spots.",
                icon: "wifi.circle",
                category: .hardware,
                difficulty: .moderate,
                estimatedCost: "$150–$350",
                products: [
                    "TP-Link Deco (budget-friendly, easy setup)",
                    "Google Nest WiFi Pro (great for most homes)",
                    "Eero Pro 6E (premium performance)"
                ],
                impact: .high
            ))

            fixes.append(GuidedFix(
                title: "Reposition Your Router",
                description: "Place your router in a central, elevated location. Avoid closets, floors, and spots behind TVs. WiFi signals radiate outward and downward — higher is better.",
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                category: .placement,
                difficulty: .easy,
                estimatedCost: "Free",
                products: [],
                impact: .medium
            ))
        }

        if hasFairSignal || hasWeakSignal {
            fixes.append(GuidedFix(
                title: "Add a WiFi Extender",
                description: "Place a WiFi extender halfway between your router and the weak zone. This extends your existing network's reach.",
                icon: "antenna.radiowaves.left.and.right",
                category: .hardware,
                difficulty: .easy,
                estimatedCost: "$25–$80",
                products: [
                    "TP-Link RE315 (budget, covers 1,500 sq ft)",
                    "Netgear EAX15 (mid-range, WiFi 6)",
                    "TP-Link RE605X (WiFi 6, good range)"
                ],
                impact: .medium
            ))

            fixes.append(GuidedFix(
                title: "Remove Signal Obstacles",
                description: "Thick walls, mirrors, metal objects, and fish tanks significantly weaken WiFi. Check for obstructions between your router and this area.",
                icon: "xmark.shield",
                category: .environment,
                difficulty: .easy,
                estimatedCost: "Free",
                products: [],
                impact: .medium
            ))
        }

        // Speed fixes
        let hasSlowSpeed = issues.contains { $0.category == .speed && $0.severity == .critical }
        let hasBelowAvgSpeed = issues.contains { $0.category == .speed && $0.severity == .warning }

        if hasSlowSpeed {
            fixes.append(GuidedFix(
                title: "Upgrade Your Internet Plan",
                description: "Your download speed is very low. Check if your ISP offers faster tiers — many have upgraded their networks without notifying existing customers.",
                icon: "arrow.up.circle",
                category: .isp,
                difficulty: .easy,
                estimatedCost: "Varies by ISP",
                products: [
                    "Call your ISP and ask about current promotions",
                    "Check if fiber is available at your address",
                    "Compare plans on BroadbandNow.com"
                ],
                impact: .high
            ))

            fixes.append(GuidedFix(
                title: "Use a Wired Connection",
                description: "For devices that need maximum speed (gaming console, work desktop, streaming box), use an Ethernet cable. Wired connections are always faster than WiFi.",
                icon: "cable.connector",
                category: .hardware,
                difficulty: .easy,
                estimatedCost: "$5–$20",
                products: [
                    "Cat 6 Ethernet cable (any length you need)",
                    "Powerline adapter if router is far away"
                ],
                impact: .high
            ))
        }

        if hasBelowAvgSpeed || hasSlowSpeed {
            fixes.append(GuidedFix(
                title: "Restart Your Router",
                description: "Unplug your router for 30 seconds, then plug it back in. This clears memory and resets connections — it resolves more issues than you'd expect.",
                icon: "power",
                category: .quick,
                difficulty: .easy,
                estimatedCost: "Free",
                products: [],
                impact: .medium
            ))

            fixes.append(GuidedFix(
                title: "Check for Bandwidth Hogs",
                description: "Other devices streaming, downloading, or backing up can slow your connection. Check for devices running updates, cloud backups, or 4K streaming.",
                icon: "desktopcomputer",
                category: .environment,
                difficulty: .easy,
                estimatedCost: "Free",
                products: [],
                impact: .medium
            ))
        }

        // Congestion fixes
        let hasCongestion = issues.contains { $0.category == .interference }

        if hasCongestion {
            fixes.append(GuidedFix(
                title: "Switch to 5GHz Band",
                description: "The 2.4GHz band is congested in your area. Connect to your router's 5GHz network (often labeled with \"5G\" or \"_5GHz\"). It's faster and less crowded.",
                icon: "wifi",
                category: .settings,
                difficulty: .easy,
                estimatedCost: "Free",
                products: [
                    "Look for a network name ending in _5G or _5GHz",
                    "If your router combines both bands, check router settings to enable band steering"
                ],
                impact: .high
            ))

            fixes.append(GuidedFix(
                title: "Change Your WiFi Channel",
                description: "Your router might be on the same channel as neighbors. Log into your router's admin page and try channels 1, 6, or 11 for 2.4GHz, or use auto-channel selection for 5GHz.",
                icon: "slider.horizontal.3",
                category: .settings,
                difficulty: .moderate,
                estimatedCost: "Free",
                products: [
                    "Access router admin at 192.168.1.1 or 192.168.0.1",
                    "For 2.4GHz: try channels 1, 6, or 11 (non-overlapping)",
                    "For 5GHz: enable auto-channel or DFS channels"
                ],
                impact: .high
            ))
        }

        // Latency fixes
        let hasHighLatency = issues.contains { $0.category == .latency && $0.severity == .critical }

        if hasHighLatency {
            fixes.append(GuidedFix(
                title: "Enable QoS on Your Router",
                description: "Quality of Service (QoS) prioritizes important traffic like video calls over background downloads. Most modern routers have this setting.",
                icon: "arrow.up.arrow.down.circle",
                category: .settings,
                difficulty: .moderate,
                estimatedCost: "Free",
                products: [
                    "Check router admin panel for QoS or Traffic Management",
                    "Prioritize: video conferencing, gaming, VoIP"
                ],
                impact: .medium
            ))
        }

        // Packet loss fixes
        let hasPacketLoss = issues.contains { $0.category == .packetLoss }

        if hasPacketLoss {
            fixes.append(GuidedFix(
                title: "Check Your Cable Connections",
                description: "Loose or damaged Ethernet cables between your modem and router can cause packet loss. Inspect and reseat all cable connections.",
                icon: "cable.connector",
                category: .hardware,
                difficulty: .easy,
                estimatedCost: "Free–$10",
                products: [],
                impact: .medium
            ))

            fixes.append(GuidedFix(
                title: "Update Router Firmware",
                description: "Outdated router firmware can cause instability and packet loss. Check your router's admin page for available updates.",
                icon: "arrow.triangle.2.circlepath",
                category: .settings,
                difficulty: .moderate,
                estimatedCost: "Free",
                products: [
                    "Log into your router admin panel",
                    "Look for Firmware Update or System Update section"
                ],
                impact: .medium
            ))
        }

        // Sort by impact (high first) then difficulty (easy first)
        return fixes.sorted { a, b in
            if a.impact != b.impact { return a.impact.sortOrder < b.impact.sortOrder }
            return a.difficulty.sortOrder < b.difficulty.sortOrder
        }
    }

    // MARK: - Channel Congestion Analysis

    /// Analyzes BLE device data to infer 2.4GHz channel congestion and
    /// provide WiFi channel recommendations.
    static func analyzeChannelCongestion(bleDeviceCount: Int, strongSignalDevices: Int) -> ChannelCongestionReport {
        let congestionLevel: CongestionLevel
        let recommendation: String
        let suggestedBand: String
        let channelAdvice: String

        if strongSignalDevices > 40 {
            congestionLevel = .severe
            recommendation = "Critical congestion detected. Strongly recommend switching to 5GHz immediately."
            suggestedBand = "5GHz"
            channelAdvice = "For 5GHz, use DFS channels (52-144) if your router supports them — they're typically empty. Otherwise, channels 36-48 or 149-165 are good options."
        } else if strongSignalDevices > 20 {
            congestionLevel = .high
            recommendation = "High congestion on 2.4GHz. Switching to 5GHz will significantly improve performance."
            suggestedBand = "5GHz preferred"
            channelAdvice = "If you must use 2.4GHz, try channel 1, 6, or 11. For 5GHz, auto-channel selection usually picks the best option."
        } else if strongSignalDevices > 10 {
            congestionLevel = .moderate
            recommendation = "Moderate congestion. Performance may vary. Consider 5GHz for bandwidth-heavy tasks."
            suggestedBand = "5GHz for streaming/calls"
            channelAdvice = "Check if your current 2.4GHz channel overlaps with neighbors. Non-overlapping channels are 1, 6, and 11. Switch to whichever has the least competition."
        } else {
            congestionLevel = .low
            recommendation = "Low congestion. Both 2.4GHz and 5GHz should perform well."
            suggestedBand = "Either band"
            channelAdvice = "Your 2.4GHz environment looks clean. Use 2.4GHz for range and IoT devices, 5GHz for speed-sensitive tasks."
        }

        return ChannelCongestionReport(
            totalDevicesDetected: bleDeviceCount,
            strongSignalDevices: strongSignalDevices,
            congestionLevel: congestionLevel,
            recommendation: recommendation,
            suggestedBand: suggestedBand,
            channelAdvice: channelAdvice
        )
    }
}

// MARK: - Guided Fix Model

struct GuidedFix: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: FixCategory
    let difficulty: FixDifficulty
    let estimatedCost: String
    let products: [String]
    let impact: FixImpact

    enum FixCategory: String {
        case hardware = "Hardware"
        case placement = "Placement"
        case environment = "Environment"
        case settings = "Settings"
        case isp = "ISP"
        case quick = "Quick Fix"
    }

    enum FixDifficulty: String {
        case easy = "Easy"
        case moderate = "Moderate"
        case advanced = "Advanced"

        var sortOrder: Int {
            switch self { case .easy: return 0; case .moderate: return 1; case .advanced: return 2 }
        }

        var color: Color {
            switch self { case .easy: return .green; case .moderate: return .orange; case .advanced: return .red }
        }
    }

    enum FixImpact: String {
        case high = "High Impact"
        case medium = "Medium Impact"
        case low = "Low Impact"

        var sortOrder: Int {
            switch self { case .high: return 0; case .medium: return 1; case .low: return 2 }
        }

        var color: Color {
            switch self { case .high: return .green; case .medium: return .amber; case .low: return .secondary }
        }
    }
}

// MARK: - Channel Congestion Report

struct ChannelCongestionReport {
    let totalDevicesDetected: Int
    let strongSignalDevices: Int
    let congestionLevel: CongestionLevel
    let recommendation: String
    let suggestedBand: String
    let channelAdvice: String
}

enum CongestionLevel: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case severe = "Severe"

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .severe: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }
}
