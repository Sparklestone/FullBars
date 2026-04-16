import SwiftUI

/// Before/After snapshot comparison — lets users mark a "before" state,
/// make changes to their setup, then mark an "after" state and see
/// a side-by-side comparison of improvements.
struct BeforeAfterView: View {
    @Environment(\.displayMode) private var displayMode
    @State private var beforeSnapshot: NetworkSnapshot?
    @State private var afterSnapshot: NetworkSnapshot?
    @State private var isCapturing = false
    @State private var capturePhase: CapturePhase = .ready
    @State private var wifiService = WiFiService()
    @State private var speedTestService = SpeedTestService()
    @State private var bleService = BLEService()
    @State private var showShareSheet = false

    private let electricCyan = FullBars.Design.Colors.accentCyan

    enum CapturePhase: String {
        case ready = "Ready"
        case capturingBefore = "Capturing Before..."
        case waitingForChanges = "Make Your Changes"
        case capturingAfter = "Capturing After..."
        case complete = "Comparison Ready"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status header
                        statusHeader

                        // Instructions or comparison
                        if beforeSnapshot == nil && afterSnapshot == nil {
                            instructionsView
                        }

                        // Before card
                        if let before = beforeSnapshot {
                            snapshotCard(title: "Before", snapshot: before, color: .orange)
                        }

                        // After card
                        if let after = afterSnapshot {
                            snapshotCard(title: "After", snapshot: after, color: .green)
                        }

                        // Comparison results
                        if let before = beforeSnapshot, let after = afterSnapshot {
                            comparisonResults(before: before, after: after)
                        }

                        // Action buttons
                        actionButtons

                        Spacer().frame(height: 32)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Before & After")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showShareSheet) {
                if let before = beforeSnapshot, let after = afterSnapshot {
                    ShareSheet(text: generateComparisonReport(before: before, after: after))
                }
            }
        }
        .onAppear {
            wifiService.startContinuousMonitoring()
            bleService.startScanning()
        }
        .onDisappear {
            wifiService.stopMonitoring()
            bleService.stopScanning()
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 12) {
            // Step indicators
            stepDot(step: 1, label: "Before", isActive: capturePhase == .capturingBefore, isComplete: beforeSnapshot != nil)
            stepLine(isComplete: beforeSnapshot != nil)
            stepDot(step: 2, label: "Change", isActive: capturePhase == .waitingForChanges, isComplete: capturePhase == .capturingAfter || capturePhase == .complete)
            stepLine(isComplete: afterSnapshot != nil)
            stepDot(step: 3, label: "After", isActive: capturePhase == .capturingAfter, isComplete: afterSnapshot != nil)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private func stepDot(step: Int, label: String, isActive: Bool, isComplete: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? electricCyan : isActive ? electricCyan.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                } else {
                    Text("\(step)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(isActive ? electricCyan : .secondary)
                }
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(isActive || isComplete ? .white : .secondary)
        }
    }

    private func stepLine(isComplete: Bool) -> some View {
        Rectangle()
            .fill(isComplete ? electricCyan : Color.white.opacity(0.1))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    // MARK: - Instructions

    private var instructionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 40))
                .foregroundStyle(electricCyan.opacity(0.6))

            Text(displayMode == .basic
                 ? "See how changes improve your WiFi"
                 : "Capture before & after network snapshots"
            )
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                instructionStep(number: 1, text: "Tap \"Capture Before\" to record your current network state")
                instructionStep(number: 2, text: "Make your change — move router, add extender, switch channels, etc.")
                instructionStep(number: 3, text: "Tap \"Capture After\" to see what improved")
            }
            .padding(.horizontal, 16)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.bold)
                .frame(width: 20, height: 20)
                .background(electricCyan.opacity(0.2))
                .foregroundStyle(electricCyan)
                .clipShape(Circle())
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Snapshot Card

    private func snapshotCard(title: String, snapshot: NetworkSnapshot, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text(snapshot.timestamp, style: .time)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if displayMode == .basic {
                HStack(spacing: 20) {
                    snapshotMetric(label: "Signal", value: signalLabel(snapshot.signalStrength), color: signalColor(snapshot.signalStrength))
                    snapshotMetric(label: "Speed", value: String(format: "%.0f Mbps", snapshot.downloadSpeed), color: speedColor(snapshot.downloadSpeed))
                    snapshotMetric(label: "Congestion", value: snapshot.congestionLevel, color: congestionColor(snapshot.congestionLevel))
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    snapshotMetric(label: "Signal", value: "\(snapshot.signalStrength) dBm", color: signalColor(snapshot.signalStrength))
                    snapshotMetric(label: "Download", value: String(format: "%.1f Mbps", snapshot.downloadSpeed), color: speedColor(snapshot.downloadSpeed))
                    snapshotMetric(label: "Upload", value: String(format: "%.1f Mbps", snapshot.uploadSpeed), color: .blue)
                    snapshotMetric(label: "Latency", value: String(format: "%.0f ms", snapshot.latency), color: .amber)
                    snapshotMetric(label: "BLE Devices", value: "\(snapshot.bleDeviceCount)", color: .purple)
                    snapshotMetric(label: "SSID", value: snapshot.ssid, color: electricCyan)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func snapshotMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Comparison Results

    private func comparisonResults(before: NetworkSnapshot, after: NetworkSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(electricCyan)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                comparisonRow(label: "Signal", beforeVal: Double(before.signalStrength), afterVal: Double(after.signalStrength),
                              format: "%.0f dBm", higherIsBetter: true)
                comparisonRow(label: "Download", beforeVal: before.downloadSpeed, afterVal: after.downloadSpeed,
                              format: "%.1f Mbps", higherIsBetter: true)
                comparisonRow(label: "Upload", beforeVal: before.uploadSpeed, afterVal: after.uploadSpeed,
                              format: "%.1f Mbps", higherIsBetter: true)
                comparisonRow(label: "Latency", beforeVal: before.latency, afterVal: after.latency,
                              format: "%.0f ms", higherIsBetter: false)
                comparisonRow(label: "BLE Devices", beforeVal: Double(before.bleDeviceCount), afterVal: Double(after.bleDeviceCount),
                              format: "%.0f", higherIsBetter: false)
            }
            .padding(.horizontal, 16)

            // Overall verdict
            let verdict = overallVerdict(before: before, after: after)
            HStack(spacing: 10) {
                Image(systemName: verdict.icon)
                    .font(.title3)
                    .foregroundStyle(verdict.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verdict.title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(verdict.message)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(verdict.color.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(verdict.color.opacity(0.3), lineWidth: 1))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func comparisonRow(label: String, beforeVal: Double, afterVal: Double, format: String, higherIsBetter: Bool) -> some View {
        let diff = afterVal - beforeVal
        let improved = higherIsBetter ? diff > 0 : diff < 0
        let changed = abs(diff) > 0.1

        return HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(String(format: format, beforeVal))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.orange)
                .frame(width: 70)

            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(String(format: format, afterVal))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.green)
                .frame(width: 70)

            Spacer()

            if changed {
                HStack(spacing: 2) {
                    Image(systemName: improved ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.1f", diff))
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(improved ? .green : .red)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if beforeSnapshot == nil {
                Button(action: { Task { await captureBeforeSnapshot() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: isCapturing ? "hourglass" : "camera.fill")
                        Text(isCapturing ? "Capturing..." : "Capture Before")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .cornerRadius(12)
                }
                .disabled(isCapturing)
            } else if afterSnapshot == nil {
                VStack(spacing: 8) {
                    if capturePhase == .waitingForChanges {
                        Text("Make your network changes now, then capture after.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: { Task { await captureAfterSnapshot() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: isCapturing ? "hourglass" : "camera.fill")
                            Text(isCapturing ? "Capturing..." : "Capture After")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(12)
                    }
                    .disabled(isCapturing)
                }
            }

            if beforeSnapshot != nil || afterSnapshot != nil {
                HStack(spacing: 12) {
                    Button(action: resetComparison) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Start Over")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.secondary)
                        .cornerRadius(12)
                    }

                    if beforeSnapshot != nil && afterSnapshot != nil {
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(electricCyan.opacity(0.2))
                            .foregroundStyle(electricCyan)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Capture Logic

    private func captureBeforeSnapshot() async {
        isCapturing = true
        capturePhase = .capturingBefore

        await wifiService.fetchCurrentNetwork()
        _ = await speedTestService.runFullTest()

        beforeSnapshot = NetworkSnapshot(
            timestamp: Date(),
            ssid: wifiService.currentSSID,
            signalStrength: wifiService.signalStrength,
            downloadSpeed: speedTestService.downloadSpeed,
            uploadSpeed: speedTestService.uploadSpeed,
            latency: speedTestService.latency,
            jitter: speedTestService.jitter,
            packetLoss: speedTestService.packetLoss,
            bleDeviceCount: bleService.discoveredDevices.count,
            congestionLevel: bleService.congestionLevel
        )

        isCapturing = false
        capturePhase = .waitingForChanges
    }

    private func captureAfterSnapshot() async {
        isCapturing = true
        capturePhase = .capturingAfter

        await wifiService.fetchCurrentNetwork()
        _ = await speedTestService.runFullTest()

        afterSnapshot = NetworkSnapshot(
            timestamp: Date(),
            ssid: wifiService.currentSSID,
            signalStrength: wifiService.signalStrength,
            downloadSpeed: speedTestService.downloadSpeed,
            uploadSpeed: speedTestService.uploadSpeed,
            latency: speedTestService.latency,
            jitter: speedTestService.jitter,
            packetLoss: speedTestService.packetLoss,
            bleDeviceCount: bleService.discoveredDevices.count,
            congestionLevel: bleService.congestionLevel
        )

        isCapturing = false
        capturePhase = .complete
    }

    private func resetComparison() {
        beforeSnapshot = nil
        afterSnapshot = nil
        capturePhase = .ready
    }

    // MARK: - Helpers

    private func signalLabel(_ strength: Int) -> String {
        switch strength {
        case -50...(-1): return "Strong"
        case -60...(-51): return "Good"
        case -70...(-61): return "Fair"
        case -80...(-71): return "Weak"
        default: return "Poor"
        }
    }

    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case -50...(-1): return .green
        case -60...(-51): return FullBars.Design.Colors.accentCyan
        case -70...(-61): return .yellow
        case -80...(-71): return .orange
        default: return .red
        }
    }

    private func speedColor(_ speed: Double) -> Color {
        switch speed {
        case 100...: return .green
        case 50..<100: return FullBars.Design.Colors.accentCyan
        case 25..<50: return .yellow
        case 10..<25: return .orange
        default: return .red
        }
    }

    private func congestionColor(_ level: String) -> Color {
        switch level {
        case "Low": return .green
        case "Medium": return .yellow
        case "High": return .orange
        case "Severe": return .red
        default: return .secondary
        }
    }

    private func overallVerdict(before: NetworkSnapshot, after: NetworkSnapshot) -> (icon: String, color: Color, title: String, message: String) {
        var improvements = 0
        var regressions = 0

        if after.signalStrength > before.signalStrength { improvements += 1 } else if after.signalStrength < before.signalStrength { regressions += 1 }
        if after.downloadSpeed > before.downloadSpeed { improvements += 1 } else if after.downloadSpeed < before.downloadSpeed { regressions += 1 }
        if after.uploadSpeed > before.uploadSpeed { improvements += 1 } else if after.uploadSpeed < before.uploadSpeed { regressions += 1 }
        if after.latency < before.latency { improvements += 1 } else if after.latency > before.latency { regressions += 1 }

        if improvements > regressions + 1 {
            return ("checkmark.circle.fill", .green, "Nice Improvement!", "Your changes made a noticeable positive difference.")
        } else if regressions > improvements + 1 {
            return ("xmark.circle.fill", .red, "Things Got Worse", "Your changes may have negatively impacted the network. Consider reverting.")
        } else if improvements > regressions {
            return ("arrow.up.circle.fill", .green, "Slight Improvement", "Small gains detected. You might get more improvement with additional changes.")
        } else if regressions > improvements {
            return ("arrow.down.circle.fill", .orange, "Slight Decline", "Minor regressions detected. This might be within normal variation.")
        } else {
            return ("equal.circle.fill", .secondary, "No Significant Change", "The numbers are about the same. Try a different approach.")
        }
    }

    private func generateComparisonReport(before: NetworkSnapshot, after: NetworkSnapshot) -> String {
        var report = "FullBars — Before & After Comparison\n"
        report += "========================================\n\n"
        report += "BEFORE (\(before.timestamp.formatted())):\n"
        report += "  Signal: \(before.signalStrength) dBm\n"
        report += "  Download: \(String(format: "%.1f", before.downloadSpeed)) Mbps\n"
        report += "  Upload: \(String(format: "%.1f", before.uploadSpeed)) Mbps\n"
        report += "  Latency: \(String(format: "%.0f", before.latency)) ms\n\n"
        report += "AFTER (\(after.timestamp.formatted())):\n"
        report += "  Signal: \(after.signalStrength) dBm\n"
        report += "  Download: \(String(format: "%.1f", after.downloadSpeed)) Mbps\n"
        report += "  Upload: \(String(format: "%.1f", after.uploadSpeed)) Mbps\n"
        report += "  Latency: \(String(format: "%.0f", after.latency)) ms\n\n"
        report += "CHANGES:\n"
        report += "  Signal: \(after.signalStrength - before.signalStrength) dBm\n"
        report += "  Download: \(String(format: "%+.1f", after.downloadSpeed - before.downloadSpeed)) Mbps\n"
        report += "  Upload: \(String(format: "%+.1f", after.uploadSpeed - before.uploadSpeed)) Mbps\n"
        report += "  Latency: \(String(format: "%+.0f", after.latency - before.latency)) ms\n\n"
        report += "Scanned by FullBars"
        return report
    }
}

// MARK: - Network Snapshot Model

struct NetworkSnapshot {
    let timestamp: Date
    let ssid: String
    let signalStrength: Int
    let downloadSpeed: Double
    let uploadSpeed: Double
    let latency: Double
    let jitter: Double
    let packetLoss: Double
    let bleDeviceCount: Int
    let congestionLevel: String
}

#Preview {
    BeforeAfterView()
        .environment(\.displayMode, .basic)
}
