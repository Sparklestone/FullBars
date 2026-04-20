import SwiftUI
import SwiftData

struct DashboardView: View {
    @State var viewModel = DashboardViewModel()
    @State private var showRefreshFeedback = false
    @State private var showGradeExplainer = false
    @State private var showPaywall = false
    @State private var subscription = SubscriptionManager.shared
    @Environment(\.displayMode) private var displayMode
    @Query private var allHeatmapPoints: [HeatmapPoint]
    @Query(sort: \SpeedTestResult.timestamp, order: .reverse) private var speedTestResults: [SpeedTestResult]

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if displayMode == .basic {
                        basicDashboard
                    } else {
                        technicalDashboard
                    }

                    // Assessment Progress — ties all tools together
                    assessmentProgressCard
                        .padding(.horizontal, 16)

                    // Free-tier context banner
                    if !subscription.isPro {
                        freeTierBanner
                            .padding(.horizontal, 16)
                    }

                    // First-run nudge to do a Home Scan
                    if allHeatmapPoints.isEmpty {
                        firstScanBanner
                            .padding(.horizontal, 16)
                    }

                    // Quick Actions
                    quickActionsSection

                    // Recent Issues
                    recentIssuesSection

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(FullBars.Design.Colors.primaryBackground)
            .navigationTitle("FullBars")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refreshData()
                showRefreshFeedback = true
                try? await Task.sleep(nanoseconds: 400_000_000)
                showRefreshFeedback = false
            }
            .sensoryFeedback(.impact(intensity: 0.7), trigger: showRefreshFeedback)
            .sheet(isPresented: $showGradeExplainer) {
                GradeExplainerView()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) { ProPaywallView() }
        .onAppear {
            viewModel.startMonitoring()
            Task { await viewModel.refreshData() }
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Basic Mode Dashboard

    private var basicDashboard: some View {
        VStack(spacing: 16) {
            // Large letter grade
            VStack(spacing: 8) {
                Text(letterGrade)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor)
                    .shadow(color: gradeColor.opacity(0.5), radius: 16)

                Text(friendlyStatus)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(friendlyMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Based on signal coverage, speed, reliability, latency & interference")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 2)

                Button(action: { showGradeExplainer = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                        Text("How is this graded?")
                            .font(.system(.caption, design: .rounded))
                    }
                    .foregroundStyle(electricCyan.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Technical Mode Dashboard

    private var technicalDashboard: some View {
        VStack(spacing: 16) {
            // Connection Details Card (prioritized — most actionable info first)
            ConnectionDetailsCard(
                ssid: viewModel.wifiService.currentSSID,
                connectionType: viewModel.networkMonitor.connectionType,
                signalStrength: viewModel.wifiService.signalStrength,
                signalQuality: viewModel.signalQuality
            )
            .animation(.easeOut(duration: 0.5).delay(0.1), value: viewModel.healthScore)

            // Health Score
            HealthScoreView(
                score: viewModel.healthScore,
                quality: viewModel.signalQuality
            )
            .frame(height: 250)
            .opacity(viewModel.healthScore > 0 ? 1.0 : 0.8)

            // Technical metrics row
            HStack(spacing: 12) {
                MetricCard(
                    title: "Signal",
                    value: "\(viewModel.wifiService.signalStrength)",
                    subtitle: "dBm (est.)",
                    icon: "wifi",
                    color: Color.forSignalStrength(viewModel.wifiService.signalStrength)
                )

                MetricCard(
                    title: "Health",
                    value: "\(viewModel.healthScore)",
                    subtitle: "/ 100",
                    icon: "heart.fill",
                    color: electricCyan
                )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Assessment Progress

    private var hasSpeedTest: Bool { !speedTestResults.isEmpty }
    private var hasHomeScan: Bool { !allHeatmapPoints.isEmpty }
    private var stepsComplete: Int { (hasSpeedTest ? 1 : 0) + (hasHomeScan ? 1 : 0) }

    private var assessmentProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your WiFi Assessment")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if stepsComplete == 2 {
                    Text("Complete")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else {
                    Text("\(stepsComplete)/2 steps")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text("Your grade is based on signal coverage (30%), speed (25%), reliability (20%), latency (15%), and interference (10%). Complete these steps for an accurate grade:")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                assessmentStep(
                    number: "1",
                    title: "Speed Test",
                    subtitle: "Measures download/upload speed (25% of grade)",
                    done: hasSpeedTest,
                    destination: AnyView(SpeedTestView())
                )
                assessmentStep(
                    number: "2",
                    title: "Home Scan",
                    subtitle: "Maps signal room-by-room (30% of grade)",
                    done: hasHomeScan,
                    destination: AnyView(GuidedWalkthroughView())
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        )
    }

    private func assessmentStep(number: String, title: String, subtitle: String, done: Bool, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(done ? Color.green.opacity(0.2) : electricCyan.opacity(0.15))
                        .frame(width: 30, height: 30)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Text(number)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(electricCyan)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(done ? .white.opacity(0.5) : .white)
                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if !done {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(electricCyan.opacity(0.6))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        }
        .disabled(done)
    }

    // MARK: - Free Tier Banner

    private var freeTierBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(electricCyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Plan")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("3 room scans · 1 speed test/day · Signal monitor")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text("Upgrade")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(electricCyan))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(electricCyan.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(electricCyan.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - First Scan Banner

    private var firstScanBanner: some View {
        NavigationLink(destination: FullAssessmentView()) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(electricCyan.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(electricCyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Grade Your WiFi")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Speed test + room-by-room scan. Takes about 5 minutes.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [electricCyan.opacity(0.15), electricCyan.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(electricCyan.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontDesign(.rounded)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: SignalMonitorView()) {
                    QuickActionCard(
                        title: displayMode == .basic ? "Check Signal" : "Signal Monitor",
                        icon: "waveform.path.ecg",
                        color: .blue,
                        subtitle: displayMode == .basic ? "Is my signal strong?" : "Real-time tracking"
                    )
                }

                NavigationLink(destination: SpeedTestView()) {
                    QuickActionCard(
                        title: displayMode == .basic ? "Check Speed" : "Speed Test",
                        icon: "speedometer",
                        color: .green,
                        subtitle: displayMode == .basic ? "How fast is my internet?" : "Check bandwidth"
                    )
                }

                NavigationLink(destination: BLEScannerView()) {
                    QuickActionCard(
                        title: displayMode == .basic ? "Interference Check" : "BLE Scanner",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .purple,
                        subtitle: displayMode == .basic ? "Nearby devices affecting WiFi (10% of grade)" : "Detect BLE interference"
                    )
                }

                NavigationLink(destination: GuidedWalkthroughView()) {
                    QuickActionCard(
                        title: "Home Scan",
                        icon: "figure.walk.motion",
                        color: .orange,
                        subtitle: displayMode == .basic ? "Walk & check every room" : "Guided room-by-room capture"
                    )
                }

                if subscription.isPro {
                    NavigationLink(destination: HeatmapView()) {
                        QuickActionCard(
                            title: "AR Floor Plan",
                            icon: "camera.viewfinder",
                            color: .pink,
                            subtitle: "LiDAR iPhones only"
                        )
                    }
                } else {
                    Button { showPaywall = true } label: {
                        QuickActionCard(
                            title: "AR Floor Plan",
                            icon: "camera.viewfinder",
                            color: .pink,
                            subtitle: "Pro"
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .padding(8)
                        }
                    }
                }

                if subscription.isPro {
                    NavigationLink(destination: DiagnosticsView()) {
                        QuickActionCard(
                            title: displayMode == .basic ? "Diagnose Problems" : "Diagnostics",
                            icon: "stethoscope",
                            color: .red,
                            subtitle: displayMode == .basic ? "Find what's wrong" : "System health report"
                        )
                    }
                } else {
                    Button { showPaywall = true } label: {
                        QuickActionCard(
                            title: displayMode == .basic ? "Diagnose Problems" : "Diagnostics",
                            icon: "stethoscope",
                            color: .red,
                            subtitle: "Pro"
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .padding(8)
                        }
                    }
                }

                if subscription.isPro {
                    NavigationLink(destination: CoveragePlannerView()) {
                        QuickActionCard(
                            title: displayMode == .basic ? "Coverage Planner" : "Mesh Planner",
                            icon: "map.fill",
                            color: .indigo,
                            subtitle: displayMode == .basic ? "Find weak spots & fix them" : "Weak spots & mesh placement"
                        )
                    }
                } else {
                    Button { showPaywall = true } label: {
                        QuickActionCard(
                            title: displayMode == .basic ? "Coverage Planner" : "Mesh Planner",
                            icon: "map.fill",
                            color: .indigo,
                            subtitle: "Pro"
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .padding(8)
                        }
                    }
                }

                if subscription.isPro {
                    NavigationLink(destination: MultiFloorWeakSpotView()) {
                        QuickActionCard(
                            title: displayMode == .basic ? "Weak Spot Check" : "Weak Spot Diagnosis",
                            icon: "building.2.fill",
                            color: .teal,
                            subtitle: displayMode == .basic ? "Multi-floor signal check" : "Cross-floor analysis"
                        )
                    }
                } else {
                    Button { showPaywall = true } label: {
                        QuickActionCard(
                            title: displayMode == .basic ? "Weak Spot Check" : "Weak Spot Diagnosis",
                            icon: "building.2.fill",
                            color: .teal,
                            subtitle: "Pro"
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .padding(8)
                        }
                    }
                }

                NavigationLink(destination: SignalTrendsView()) {
                    QuickActionCard(
                        title: displayMode == .basic ? "View Trends" : "Signal Trends",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan,
                        subtitle: displayMode == .basic ? "How's my WiFi over time?" : "Historical analysis"
                    )
                }

                NavigationLink(destination: BeforeAfterView()) {
                    QuickActionCard(
                        title: displayMode == .basic ? "Compare Changes" : "Before & After",
                        icon: "arrow.left.arrow.right",
                        color: .mint,
                        subtitle: displayMode == .basic ? "Did my fix work?" : "Snapshot comparison"
                    )
                }
            }
            .padding(.horizontal)
        }
        .animation(.easeOut(duration: 0.5).delay(0.2), value: viewModel.healthScore)
    }

    // MARK: - Recent Issues

    private var recentIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayMode == .basic ? "Status" : "Recent Issues")
                .font(.headline)
                .fontDesign(.rounded)
                .padding(.horizontal)

            if viewModel.recentIssues.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.green, .green.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.5), radius: 8)

                    Text(displayMode == .basic ? "Everything looks good!" : "No issues detected")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(white: 1, opacity: 0.15), Color(white: 1, opacity: 0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.recentIssues.prefix(3)) { issue in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(issue.severity.color)
                                .frame(width: 12, height: 12)
                                .shadow(color: issue.severity.color.opacity(0.6), radius: 6)

                            Image(systemName: issue.severity.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(issue.severity.color)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayMode == .basic ? issue.suggestion : issue.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)

                                if displayMode == .technical {
                                    Text(issue.suggestion)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [issue.severity.color.opacity(0.2), issue.severity.color.opacity(0.05)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .animation(.easeOut(duration: 0.5).delay(0.3), value: viewModel.healthScore)
    }

    // MARK: - Basic Mode Helpers

    private var letterGrade: String {
        GradeLetter.from(score: Double(viewModel.healthScore)).rawValue
    }

    private var gradeColor: Color {
        GradeLetter.from(score: Double(viewModel.healthScore)).color
    }

    private var friendlyStatus: String {
        switch viewModel.signalQuality {
        case .excellent: return "Your network is excellent"
        case .good: return "Your network is good"
        case .fair: return "Your network is fair"
        case .poor: return "Your network is poor"
        case .noSignal: return "No network detected"
        }
    }

    private var friendlyMessage: String {
        switch viewModel.signalQuality {
        case .excellent: return "Everything is running smoothly. Enjoy your connection!"
        case .good: return "Your connection is solid with only minor fluctuations."
        case .fair: return "You might notice some slowness. Try moving closer to your router."
        case .poor: return "Your connection has issues. Consider restarting your router."
        case .noSignal: return "Check that your WiFi is turned on and you're in range."
        }
    }
}

#Preview {
    DashboardView()
        .environment(\.displayMode, .basic)
}
