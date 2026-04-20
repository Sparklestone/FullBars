import SwiftUI
import SwiftData

enum SpeedViewTab: String, CaseIterable {
    case current = "Right Now"
    case wholeHome = "Whole Home"
}

struct SpeedTestView: View {
    @State var viewModel = SpeedTestViewModel()
    @State private var showShareSheet = false
    @State private var resultAnimation = false
    @State private var settingsVM = SettingsViewModel()
    @State private var selectedTab: SpeedViewTab = .current
    @State private var showPaywall = false
    @State private var showRewardedAd = false
    @State private var subscription = SubscriptionManager.shared
    @Query(sort: \HeatmapPoint.timestamp, order: .reverse) private var allHeatmapPoints: [HeatmapPoint]
    @Environment(\.displayMode) private var displayMode

    let primaryColor = FullBars.Design.Colors.accentCyan
    private let profile = UserProfile()

    var body: some View {
        NavigationStack {
            ZStack {
                FullBars.Design.Colors.primaryBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("View", selection: $selectedTab) {
                        ForEach(SpeedViewTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .accessibilityIdentifier(AccessibilityID.SpeedTest.tabPicker)

                    if selectedTab == .current {
                ScrollView {
                    VStack(spacing: 24) {
                        // Speed Gauge or Results
                        if viewModel.speedTestService.isRunning {
                            runningView
                        } else if let result = viewModel.currentResult {
                            if displayMode == .basic {
                                basicResultView(result: result)
                            } else {
                                technicalResultView(result: result)
                            }
                        } else {
                            emptyView
                        }

                        // ISP Comparison (if configured)
                        

                        // Free-tier limit banner
                        speedTestLimitBanner

                        // Start/Stop Button
                        startStopButton

                        // History
                        if !viewModel.testHistory.isEmpty && displayMode == .technical {
                            historySection
                        }

                        // What's Next nudge
                        if viewModel.currentResult != nil && allHeatmapPoints.isEmpty {
                            NavigationLink(destination: GuidedWalkthroughView()) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Speed captured — now map your home")
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        Text("Your speed score is 25% of your WiFi grade. Walk your home next to measure coverage (30%).")
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(primaryColor.opacity(0.6))
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(primaryColor.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 12).stroke(primaryColor.opacity(0.2))))
                            }
                            .padding(.horizontal)
                        }

                        // Share
                        if viewModel.currentResult != nil {
                            shareButton
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        Spacer().frame(height: 32)
                    }
                    .padding(.vertical, 16)
                }
                    } else {
                        ScrollView {
                            WholeHomeCoverageView(points: allHeatmapPoints)
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Speed Test")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: viewModel.generateReport())
            }
            .sheet(isPresented: $showPaywall) { ProPaywallView() }
        }
    }

    // MARK: - Free-Tier Limit Banner

    private var speedTestLimitBanner: some View {
        Group {
            if !subscription.isPro && !subscription.canRunFreeSpeedTest {
                VStack(spacing: 10) {
                    Text("You've used today's free test")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Free users get 1 speed test per day. Want another? Watch a quick video or go Pro for unlimited tests anytime.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button {
                            // Rewarded video placeholder — grant one extra test
                            subscription.freeSpeedTestsUsedToday = 0
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                Text("Watch Ad")
                            }
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(primaryColor))
                        }
                        Button { showPaywall = true } label: {
                            Text("Go Pro")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().stroke(primaryColor, lineWidth: 1))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(primaryColor.opacity(0.3)))
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Running State

    private var runningView: some View {
        VStack(spacing: 16) {
            SpeedGaugeView(
                speed: Double(viewModel.speedTestService.progress) * 100,
                maxSpeed: 100,
                label: "Testing...",
                color: primaryColor
            )
            VStack(spacing: 8) {
                Text(viewModel.speedTestService.currentPhase)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                ProgressView(value: viewModel.speedTestService.progress)
                    .tint(primaryColor)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: viewModel.speedTestService.isRunning)
    }

    // MARK: - Basic Result View

    private func basicResultView(result: SpeedTestResult) -> some View {
        VStack(spacing: 24) {
            // Simple speed rating
            let speedLabel = speedRating(result.downloadSpeed)

            VStack(spacing: 12) {
                Text(speedLabel.label)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(speedLabel.color)
                    .shadow(color: speedLabel.color.opacity(0.4), radius: 12)

                Text(speedLabel.message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Big friendly numbers
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text(String(format: "%.0f", result.downloadSpeed))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mbps down")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(primaryColor)
                    Text(String(format: "%.0f", result.uploadSpeed))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mbps up")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            // Only show issues if there's a problem worth flagging
            if result.packetLoss > 1 || result.jitter > 30 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(result.packetLoss > 1
                        ? "Some data is being lost in transit — this can cause buffering."
                        : "Your connection is a bit unstable — video calls may be choppy."
                    )
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Technical Result View

    private func technicalResultView(result: SpeedTestResult) -> some View {
        VStack(spacing: 12) {
            SpeedGaugeView(
                speed: result.downloadSpeed,
                maxSpeed: 200,
                label: "Download",
                color: .green
            )
            .padding(.horizontal)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    GlassSpeedMetricCard(title: "Download", value: String(format: "%.1f", result.downloadSpeed), subtitle: "Mbps", icon: "arrow.down.circle.fill", color: .green)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeOut(duration: 0.5).delay(0.05), value: resultAnimation)

                    GlassSpeedMetricCard(title: "Upload", value: String(format: "%.1f", result.uploadSpeed), subtitle: "Mbps", icon: "arrow.up.circle.fill", color: primaryColor)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: resultAnimation)
                }

                HStack(spacing: 12) {
                    GlassSpeedMetricCard(title: "Latency", value: String(format: "%.0f", result.latency), subtitle: "ms", icon: "clock.fill", color: .amber)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: resultAnimation)

                    GlassSpeedMetricCard(title: "Jitter", value: String(format: "%.1f", result.jitter), subtitle: "ms", icon: "waveform.path", color: .purple)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: resultAnimation)
                }

                HStack(spacing: 12) {
                    GlassSpeedMetricCard(title: "Packet Loss", value: String(format: "%.2f", result.packetLoss), subtitle: "%", icon: "exclamationmark.circle.fill", color: result.packetLoss > 0 ? .red : .green)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: resultAnimation)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .onAppear { resultAnimation = true }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "speedometer")
                .font(.system(size: 48))
                .foregroundStyle(primaryColor)
            VStack(spacing: 4) {
                Text(displayMode == .basic ? "Check Your Speed" : "Run Speed Test")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(displayMode == .basic ? "Find out how fast your internet is" : "Check your internet speed")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Buttons

    private var startStopButton: some View {
        Button(action: {
            if !viewModel.speedTestService.isRunning {
                if subscription.canRunFreeSpeedTest {
                    subscription.recordFreeSpeedTest()
                    resultAnimation = false
                    Task { await viewModel.runTest() }
                } else {
                    showPaywall = true
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.speedTestService.isRunning ? "stop.circle.fill" : "play.circle.fill")
                Text(viewModel.speedTestService.isRunning ? "Stop Test" : "Start Test")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.speedTestService.isRunning ? Color.red : primaryColor, lineWidth: viewModel.speedTestService.isRunning ? 1.5 : 0)
                    )
            )
            .foregroundStyle(viewModel.speedTestService.isRunning ? .red : primaryColor)
            .shadow(color: viewModel.speedTestService.isRunning ? Color.red.opacity(0.3) : primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(viewModel.speedTestService.isRunning && viewModel.currentResult == nil)
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: viewModel.speedTestService.isRunning)
        .accessibilityIdentifier(viewModel.speedTestService.isRunning ? AccessibilityID.SpeedTest.stopButton : AccessibilityID.SpeedTest.startButton)
    }

    private var shareButton: some View {
        Button(action: { showShareSheet = true }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Report")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .foregroundStyle(primaryColor)
        }
        .padding(.horizontal)
        .accessibilityIdentifier(AccessibilityID.SpeedTest.shareButton)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test History")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(viewModel.testHistory.prefix(5)) { result in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: result.timestamp))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(String(format: "%.1f", result.downloadSpeed)) Mbps ↓ | \(String(format: "%.1f", result.uploadSpeed)) Mbps ↑")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal)
        }
    }


    // MARK: - Helpers

    private func speedRating(_ speed: Double) -> (label: String, color: Color, message: String) {
        switch speed {
        case 100...: return ("Fast", .green, "Great for streaming, gaming, and video calls!")
        case 50..<100: return ("Good", FullBars.Design.Colors.accentCyan, "Handles most tasks well. Multiple devices should be fine.")
        case 25..<50: return ("Average", .yellow, "Okay for browsing and light streaming. May buffer 4K video.")
        case 10..<25: return ("Slow", .orange, "Basic browsing works but streaming may be choppy.")
        default: return ("Very Slow", .red, "You'll have trouble with most online activities.")
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct GlassSpeedMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .shadow(color: color.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
    }
}

#Preview {
    SpeedTestView()
        .environment(\.displayMode, .basic)
}
