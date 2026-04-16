import XCTest
@testable import FullBars

/// Unit tests for DiagnosticsEngine — pure issue-detection rules.
final class DiagnosticsEngineTests: XCTestCase {

    /// Shorthand: run analyze with healthy defaults, overriding only the
    /// fields each test cares about.
    private func analyze(
        signalStrength: Int = -55,
        latency: Double = 25,
        jitter: Double = 5,
        packetLoss: Double = 0,
        downloadSpeed: Double = 150,
        uploadSpeed: Double = 30,
        bleDeviceCount: Int = 2,
        connectionType: String = "wifi"
    ) -> [DiagnosticIssue] {
        DiagnosticsEngine.analyze(
            signalStrength: signalStrength,
            latency: latency,
            jitter: jitter,
            packetLoss: packetLoss,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            bleDeviceCount: bleDeviceCount,
            connectionType: connectionType
        )
    }

    // MARK: - Healthy baseline

    func testHealthyNetworkProducesNoCriticalIssues() {
        let issues = analyze()
        let critical = issues.filter { $0.severity == .critical }
        XCTAssertTrue(critical.isEmpty, "Healthy baseline should not flag any critical issues: \(critical.map(\.title))")
    }

    // MARK: - Signal strength

    func testVeryWeakSignalFlaggedCritical() {
        let issues = analyze(signalStrength: -85)
        let sig = issues.filter { $0.category == .signalStrength }
        XCTAssertTrue(sig.contains { $0.severity == .critical }, "Expected critical signal issue at -85 dBm")
    }

    func testFairSignalFlaggedWarning() {
        let issues = analyze(signalStrength: -75)
        let sig = issues.filter { $0.category == .signalStrength }
        XCTAssertTrue(sig.contains { $0.severity == .warning }, "Expected warning-level signal issue in -80...-70 range")
        XCTAssertFalse(sig.contains { $0.severity == .critical })
    }

    func testStrongSignalNotFlagged() {
        let issues = analyze(signalStrength: -50)
        XCTAssertTrue(issues.filter { $0.category == .signalStrength }.isEmpty)
    }

    // MARK: - Latency

    func testHighLatencyFlaggedCritical() {
        let issues = analyze(latency: 250)
        let lat = issues.filter { $0.category == .latency && $0.title.contains("Latency") }
        XCTAssertTrue(lat.contains { $0.severity == .critical })
    }

    func testElevatedLatencyFlaggedWarning() {
        let issues = analyze(latency: 150)
        let lat = issues.filter { $0.category == .latency && $0.title.contains("Latency") }
        XCTAssertTrue(lat.contains { $0.severity == .warning })
    }

    // MARK: - Jitter

    func testHighJitterProducesWarning() {
        let issues = analyze(jitter: 80)
        XCTAssertTrue(issues.contains { $0.title.contains("Jitter") })
    }

    // MARK: - Identity / suggestions

    func testEveryIssueHasNonEmptySuggestionAndTitle() {
        let issues = analyze(signalStrength: -90, latency: 300, jitter: 100, packetLoss: 15)
        XCTAssertFalse(issues.isEmpty, "A broken network should surface issues")
        for issue in issues {
            XCTAssertFalse(issue.title.isEmpty, "Issue with empty title")
            XCTAssertFalse(issue.suggestion.isEmpty, "Issue '\(issue.title)' has no suggestion")
        }
    }

    func testIssueIDsAreUnique() {
        let issues = analyze(signalStrength: -90, latency: 300, jitter: 100, packetLoss: 15)
        let ids = Set(issues.map(\.id))
        XCTAssertEqual(ids.count, issues.count, "Issue IDs must be unique")
    }

    // MARK: - Severity ordering

    func testSeverityIsComparable() {
        XCTAssertLessThan(IssueSeverity.info, IssueSeverity.warning)
        XCTAssertLessThan(IssueSeverity.warning, IssueSeverity.critical)
    }
}
