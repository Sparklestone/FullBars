import SwiftUI

struct DiagnosticsView: View {
    @State var viewModel = DiagnosticsViewModel()
    @State private var wifiService = WiFiService()
    @State private var networkMonitor = NetworkMonitorService()
    @State private var bleService = BLEService()
    @State private var showShareSheet = false
    @State private var showPaywall = false
    @State private var issueAnimation: [UUID: Bool] = [:]
    @State private var selectedFixIssue: DiagnosticIssue?
    @State private var hasInitialized = false
    @State private var subscription = SubscriptionManager.shared
    @Environment(\.displayMode) private var displayMode

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Run Diagnostics
                        Button(action: {
                            Task {
                                await wifiService.fetchCurrentNetwork()
                                viewModel.runDiagnostics(
                                    signalStrength: wifiService.signalStrength,
                                    latency: 0, jitter: 0, packetLoss: 0,
                                    downloadSpeed: 0, uploadSpeed: 0,
                                    bleDeviceCount: bleService.congestionScore,
                                    connectionType: networkMonitor.connectionType
                                )
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isAnalyzing ? "hourglass" : "stethoscope")
                                Text(viewModel.isAnalyzing
                                    ? "Analyzing..."
                                    : (displayMode == .basic ? "Check My Network" : "Run Diagnostics")
                                )
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(electricCyan.opacity(0.2))
                            .foregroundStyle(electricCyan)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isAnalyzing)
                        .padding(.horizontal, 16)

                        if viewModel.isAnalyzing {
                            VStack(spacing: 12) {
                                ProgressView().tint(electricCyan)
                                Text(displayMode == .basic ? "Checking your network..." : "Analyzing your network...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 16)
                        }

                        if !viewModel.issues.isEmpty || viewModel.lastAnalyzedAt != nil {
                            if displayMode == .basic {
                                basicDiagnosticsView
                            } else {
                                technicalDiagnosticsView
                            }

                            // Guided Fix Suggestions
                            if !viewModel.guidedFixes.isEmpty {
                                guidedFixesSection
                            }

                            // Channel Congestion Analysis
                            if let congestionReport = viewModel.congestionReport {
                                channelCongestionSection(report: congestionReport)
                            }

                            // Export
                            Button(action: { showShareSheet = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(displayMode == .basic ? "Share Results" : "Export Report")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(electricCyan.opacity(0.2))
                                .foregroundStyle(electricCyan)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                            .shadow(color: electricCyan.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else if !viewModel.isAnalyzing {
                            VStack(spacing: 16) {
                                Image(systemName: "stethoscope")
                                    .font(.system(size: 48))
                                    .foregroundStyle(electricCyan.opacity(0.5))

                                Text(displayMode == .basic
                                    ? "Find out what's wrong with your WiFi"
                                    : "Run diagnostics to analyze your network"
                                )
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(.white)

                                Text("We'll check your signal, speed, latency, and nearby interference to identify issues and suggest fixes.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(displayMode == .basic ? "Network Check" : "Diagnostics")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: viewModel.exportReport())
            }
            .sheet(isPresented: $showPaywall) { ProPaywallView() }
            .sheet(item: $selectedFixIssue) { issue in
                FixGuideView(issue: issue)
            }
            .overlay {
                if !subscription.isPro {
                    // Blur the content and show a soft upgrade prompt instead of blocking immediately
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 16) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 44))
                                .foregroundStyle(electricCyan)
                            Text("Full Diagnostics")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Get a detailed health report for your WiFi — latency, interference, channel analysis, and personalized fix suggestions.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button { showPaywall = true } label: {
                                Text("Unlock with Pro")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: 240)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(electricCyan))
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            if !hasInitialized {
                wifiService.startContinuousMonitoring()
                networkMonitor.startMonitoring()
                bleService.startScanning()
                hasInitialized = true
            }
        }
        .onDisappear {
            wifiService.stopMonitoring()
            networkMonitor.stopMonitoring()
            bleService.stopScanning()
        }
    }

    // MARK: - Basic Mode

    private var basicDiagnosticsView: some View {
        VStack(spacing: 16) {
            // Overall status
            VStack(spacing: 8) {
                Image(systemName: viewModel.issues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.issues.isEmpty ? .green : .orange)
                    .shadow(color: (viewModel.issues.isEmpty ? Color.green : Color.orange).opacity(0.5), radius: 12)

                Text(viewModel.issues.isEmpty ? "Your network looks good!" : "We found some issues")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 8)

            // Plain-language cards
            if !viewModel.issues.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.issues.sorted { $0.severity.rawValue < $1.severity.rawValue }) { issue in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(issue.severity.color)
                                    .frame(width: 10, height: 10)
                                    .shadow(color: issue.severity.color.opacity(0.6), radius: 4)
                                Text(issue.suggestion)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Action items as simple checklist
            if !viewModel.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What you can do")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(electricCyan)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        ForEach(viewModel.actionItems.sorted { $0.priority > $1.priority }) { item in
                            HStack(spacing: 12) {
                                Button(action: { viewModel.toggleActionItem(item) }) {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isCompleted ? electricCyan : .gray)
                                        .font(.system(size: 18))
                                }
                                Text(item.title)
                                    .font(.system(.subheadline, design: .rounded))
                                    .strikethrough(item.isCompleted)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                Spacer()
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: DiagnosticIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: issue.severity.icon)
                    .foregroundStyle(issue.severity.color)
                    .frame(width: 24)
                    .scaleEffect(issueAnimation[issue.id] == true ? 1.15 : 1.0)
                    .onAppear {
                        if issue.severity == .critical {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                    issueAnimation[issue.id] = true
                                }
                            }
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    Text(issue.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            if !issue.suggestion.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(issue.suggestion)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 32)
            }

            // Fix This button
            Button {
                selectedFixIssue = issue
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2)
                    Text("Fix This")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(electricCyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(electricCyan.opacity(0.12))
                .cornerRadius(8)
            }
            .padding(.leading, 32)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: issue.severity.color.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var sortedIssues: [DiagnosticIssue] {
        viewModel.issues.sorted { $0.severity.rawValue < $1.severity.rawValue }
    }

    // MARK: - Technical Mode

    private var technicalDiagnosticsView: some View {
        VStack(spacing: 16) {
            // Overall Severity Badge
            HStack(spacing: 12) {
                Image(systemName: viewModel.overallSeverity.icon)
                    .foregroundStyle(viewModel.overallSeverity.color)
                    .font(.system(.headline, design: .rounded))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Overall Status")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(viewModel.overallSeverity.label)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(dateFormatter.string(from: viewModel.lastAnalyzedAt ?? Date()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: viewModel.overallSeverity.color.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)

            // Issues
            if !viewModel.issues.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Issues Found")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(electricCyan)
                        .padding(.horizontal, 16)

                    ForEach(sortedIssues) { issue in
                        issueRow(issue)
                    }
                }
            }

            // Action Items
            if !viewModel.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Action Items")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(electricCyan)
                        Spacer()
                        Text("\(viewModel.completedCount)/\(viewModel.actionItems.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        ForEach(viewModel.actionItems.sorted { $0.priority > $1.priority }) { item in
                            HStack(spacing: 12) {
                                Button(action: { viewModel.toggleActionItem(item) }) {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isCompleted ? electricCyan : .gray)
                                        .font(.system(size: 18))
                                        .scaleEffect(item.isCompleted ? 1.1 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.isCompleted)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .strikethrough(item.isCompleted)
                                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                    if !item.itemDescription.isEmpty {
                                        Text(item.itemDescription)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(item.priorityLabel)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(item.priorityColor.opacity(0.2))
                                    .foregroundStyle(item.priorityColor)
                                    .cornerRadius(4)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(color: electricCyan.opacity(0.05), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Guided Fixes Section

    private var guidedFixesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(electricCyan)
                Text(displayMode == .basic ? "How to Fix It" : "Guided Fix Suggestions")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(electricCyan)
            }
            .padding(.horizontal, 16)

            ForEach(viewModel.guidedFixes.prefix(displayMode == .basic ? 3 : 6)) { fix in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: fix.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(electricCyan)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fix.title)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                Text(fix.difficulty.rawValue)
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(fix.difficulty.color.opacity(0.2))
                                    .foregroundStyle(fix.difficulty.color)
                                    .cornerRadius(4)

                                Text(fix.impact.rawValue)
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(fix.impact.color.opacity(0.2))
                                    .foregroundStyle(fix.impact.color)
                                    .cornerRadius(4)

                                if !fix.estimatedCost.isEmpty {
                                    Text(fix.estimatedCost)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    Text(fix.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if displayMode == .technical && !fix.products.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(fix.products, id: \.self) { product in
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(electricCyan.opacity(0.6))
                                    Text(product)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Channel Congestion Section

    private func channelCongestionSection(report: ChannelCongestionReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(electricCyan)
                Text(displayMode == .basic ? "WiFi Crowding" : "Channel Congestion Analysis")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(electricCyan)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
                // Congestion meter
                HStack(spacing: 12) {
                    Image(systemName: report.congestionLevel.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(report.congestionLevel.color)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(report.congestionLevel.rawValue)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(report.congestionLevel.color)
                            Text("Congestion")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if displayMode == .technical {
                            Text("\(report.strongSignalDevices) nearby devices (of \(report.totalDevicesDetected) detected)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Visual meter
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < congestionBars(report.congestionLevel)
                                      ? report.congestionLevel.color
                                      : Color.white.opacity(0.1))
                                .frame(width: 12, height: 20 + CGFloat(i) * 4)
                        }
                    }
                }

                Text(report.recommendation)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)

                if displayMode == .technical {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi")
                                .font(.caption)
                                .foregroundStyle(electricCyan)
                            Text("Recommended: \(report.suggestedBand)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        Text(report.channelAdvice)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(electricCyan.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func congestionBars(_ level: CongestionLevel) -> Int {
        switch level {
        case .low: return 1
        case .moderate: return 2
        case .high: return 3
        case .severe: return 4
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    DiagnosticsView()
        .environment(\.displayMode, .basic)
}
