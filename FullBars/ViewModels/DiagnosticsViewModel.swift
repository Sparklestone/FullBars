import Foundation
import SwiftUI
import Observation
import SwiftData

@Observable
final class DiagnosticsViewModel {
    var issues: [DiagnosticIssue] = []
    var actionItems: [ActionItem] = []
    var guidedFixes: [GuidedFix] = []
    var congestionReport: ChannelCongestionReport?
    var isAnalyzing: Bool = false
    var lastAnalyzedAt: Date? = nil
    var overallSeverity: IssueSeverity = .info

    var completedCount: Int {
        actionItems.filter { $0.isCompleted }.count
    }

    var pendingCount: Int {
        actionItems.filter { !$0.isCompleted }.count
    }

    func runDiagnostics(
        signalStrength: Int,
        latency: Double,
        jitter: Double,
        packetLoss: Double,
        downloadSpeed: Double,
        uploadSpeed: Double,
        bleDeviceCount: Int,
        connectionType: String
    ) {
        isAnalyzing = true

        issues = DiagnosticsEngine.analyze(
            signalStrength: signalStrength,
            latency: latency,
            jitter: jitter,
            packetLoss: packetLoss,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            bleDeviceCount: bleDeviceCount,
            connectionType: connectionType
        )

        actionItems = DiagnosticsEngine.generateActionItems(from: issues)

        // Generate guided fix suggestions
        guidedFixes = DiagnosticsEngine.generateGuidedFixes(
            from: issues,
            signalStrength: signalStrength,
            downloadSpeed: downloadSpeed,
            bleDeviceCount: bleDeviceCount
        )

        // Generate channel congestion report
        congestionReport = DiagnosticsEngine.analyzeChannelCongestion(
            bleDeviceCount: bleDeviceCount,
            strongSignalDevices: bleDeviceCount // Uses the congestion score from BLEService
        )

        overallSeverity = issues.map { $0.severity }.max() ?? .info

        lastAnalyzedAt = .now
        isAnalyzing = false
    }

    func toggleActionItem(_ item: ActionItem) {
        if let index = actionItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = actionItems[index]
            updatedItem.isCompleted.toggle()
            actionItems[index] = updatedItem
        }
    }

    func exportReport() -> String {
        var report = "FullBars Diagnostics Report\n"
        report += "==============================\n\n"

        if let analyzedAt = lastAnalyzedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            report += "Generated: \(formatter.string(from: analyzedAt))\n"
            report += "Overall Severity: \(overallSeverity)\n\n"
        }

        if !issues.isEmpty {
            report += "Issues Found: \(issues.count)\n"
            report += "---\n"
            for issue in issues {
                report += "\n[Issue] \(issue.title)\n"
                report += "Description: \(issue.description)\n"
                report += "Category: \(issue.category)\n"
                report += "Suggestion: \(issue.suggestion)\n"
            }
        } else {
            report += "No issues detected.\n\n"
        }

        if !guidedFixes.isEmpty {
            report += "\nRecommended Fixes\n"
            report += "---\n"
            for fix in guidedFixes {
                report += "\n[\(fix.impact.rawValue)] \(fix.title)\n"
                report += "Difficulty: \(fix.difficulty.rawValue) | Cost: \(fix.estimatedCost)\n"
                report += "\(fix.description)\n"
                for product in fix.products {
                    report += "  → \(product)\n"
                }
            }
        }

        if let congestion = congestionReport {
            report += "\nChannel Congestion: \(congestion.congestionLevel.rawValue)\n"
            report += "Devices detected: \(congestion.totalDevicesDetected)\n"
            report += "Recommendation: \(congestion.recommendation)\n"
            report += "Suggested band: \(congestion.suggestedBand)\n"
            report += "Channel advice: \(congestion.channelAdvice)\n"
        }

        if !actionItems.isEmpty {
            report += "\nAction Items\n"
            report += "---\n"
            for item in actionItems {
                let status = item.isCompleted ? "[✓]" : "[ ]"
                report += "\n\(status) \(item.title)\n"
                report += "Priority: \(item.priority)/3\n"
                report += "Description: \(item.itemDescription)\n"
            }
        }

        report += "\n\nScanned by FullBars"
        return report
    }
}
