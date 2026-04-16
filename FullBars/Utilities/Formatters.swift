import Foundation

class ReportGenerator {
    static func generateISPReport(
        speedTests: [SpeedTestResult],
        issues: [DiagnosticIssue]
    ) -> String {
        var report = ""
        
        report += "=== ISP EVIDENCE REPORT ===\n"
        report += "Generated: \(ISO8601DateFormatter().string(from: .now))\n\n"
        
        // Speed Test Summary
        report += "--- SPEED TEST RESULTS ---\n"
        if speedTests.isEmpty {
            report += "No speed tests available.\n"
        } else {
            for (index, test) in speedTests.enumerated() {
                report += "\nTest \(index + 1):\n"
                report += "  Date: \(ISO8601DateFormatter().string(from: test.timestamp))\n"
                report += "  Download: \(String(format: "%.2f", test.downloadSpeed)) Mbps\n"
                report += "  Upload: \(String(format: "%.2f", test.uploadSpeed)) Mbps\n"
                report += "  Latency: \(String(format: "%.1f", test.latency)) ms\n"
                report += "  Jitter: \(String(format: "%.1f", test.jitter)) ms\n"
                report += "  Packet Loss: \(String(format: "%.1f", test.packetLoss))%\n"
                report += "  Server: \(test.serverName) (\(test.serverLocation))\n"
            }
        }
        
        // Diagnostic Issues
        report += "\n--- DIAGNOSTIC ISSUES ---\n"
        if issues.isEmpty {
            report += "No issues detected.\n"
        } else {
            for issue in issues {
                report += "\n[\(issue.severity.label)] \(issue.title)\n"
                report += "Category: \(issue.category.rawValue)\n"
                report += "Description: \(issue.description)\n"
                report += "Suggestion: \(issue.suggestion)\n"
                report += "Detected: \(ISO8601DateFormatter().string(from: issue.detectedAt))\n"
            }
        }
        
        report += "\n=== END OF REPORT ===\n"
        return report
    }
}
