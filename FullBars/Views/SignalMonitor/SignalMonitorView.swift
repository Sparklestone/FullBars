import SwiftUI
import SwiftData
import Charts

enum SignalViewTab: String, CaseIterable {
    case current = "Right Now"
    case wholeHome = "Whole Home"
}

struct SignalMonitorView: View {
    @State var viewModel = SignalMonitorViewModel()
    @State private var selectedTab: SignalViewTab = .current
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
                        ForEach(SignalViewTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if selectedTab == .current {
                ScrollView {
                    VStack(spacing: 24) {
                        // Monitoring Toggle
                        monitoringButton

                        if displayMode == .basic {
                            basicSignalView
                        } else {
                            technicalSignalView
                        }

                        Spacer().frame(height: 32)
                    }
                    .padding(.vertical, 16)
                }
                    } else {
                        ScrollView {
                            WholeHomeCoverageView(
                                points: allHeatmapPoints,
                                ispPromisedSpeed: profile.ispPromisedSpeed
                            )
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Signal Monitor")
            .navigationBarTitleDisplayMode(.large)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Monitoring Button

    private var monitoringButton: some View {
        Button(action: {
            if viewModel.isMonitoring {
                viewModel.stopMonitoring()
            } else {
                viewModel.startMonitoring()
            }
        }) {
            HStack(spacing: 8) {
                if viewModel.isMonitoring {
                    ZStack {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(viewModel.isMonitoring ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isMonitoring)
                        Circle()
                            .stroke(primaryColor, lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                            .opacity(viewModel.isMonitoring ? 0.5 : 0)
                            .scaleEffect(viewModel.isMonitoring ? 1.5 : 1.0)
                            .animation(.easeOut(duration: 0.6).repeatForever(autoreverses: false), value: viewModel.isMonitoring)
                    }
                    Text("Stop Monitoring")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                    Text("Start Monitoring")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.isMonitoring ? primaryColor : Color.white.opacity(0.1),
                                lineWidth: viewModel.isMonitoring ? 1.5 : 0
                            )
                    )
            )
            .foregroundStyle(viewModel.isMonitoring ? primaryColor : .white)
            .shadow(color: viewModel.isMonitoring ? primaryColor.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: viewModel.isMonitoring)
    }

    // MARK: - Basic Mode

    private var basicSignalView: some View {
        VStack(spacing: 24) {
            // Simple status indicator
            VStack(spacing: 16) {
                // Animated thermometer-style bar
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 200)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [basicSignalColor, basicSignalColor.opacity(0.6)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 60, height: max(20, CGFloat(signalPercentage) * 2))
                        .shadow(color: basicSignalColor.opacity(0.5), radius: 12)
                        .animation(.spring(response: 0.8), value: viewModel.currentSignalStrength)
                }

                Text(basicSignalLabel)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(basicSignalMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Technical Mode

    private var technicalSignalView: some View {
        VStack(spacing: 24) {
            // Signal Strength Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Signal Strength")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    HStack {
                        Text("Current")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(viewModel.currentSignalStrength) dBm (est.)")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(signalColor(viewModel.currentSignalStrength))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Chart {
                        ForEach(viewModel.signalHistory) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Signal", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [primaryColor.opacity(0.3), primaryColor.opacity(0.05)]),
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Signal", point.value)
                            )
                            .foregroundStyle(primaryColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYScale(domain: -100 ... -20)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel()
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .padding(.horizontal)

                // Stats Row
                HStack(spacing: 12) {
                    GlassMetricCard(title: "Min", value: "\(viewModel.minSignal)", subtitle: "dBm (est.)", icon: "arrow.down", color: .red)
                    GlassMetricCard(title: "Max", value: "\(viewModel.maxSignal)", subtitle: "dBm (est.)", icon: "arrow.up", color: primaryColor)
                    GlassMetricCard(title: "Avg", value: "\(Int(viewModel.avgSignal))", subtitle: "dBm (est.)", icon: "line.horizontal", color: .green)
                }
                .padding(.horizontal)
            }

            // Latency Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Latency")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    HStack {
                        Text("Current")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("\(String(format: "%.0f", viewModel.currentLatency)) ms")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Chart {
                        ForEach(viewModel.latencyHistory) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Latency", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.05)]),
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("Latency", point.value)
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel()
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .padding(.horizontal)

                HStack(spacing: 12) {
                    GlassMetricCard(title: "Min", value: String(format: "%.0f", viewModel.minLatency), subtitle: "ms", icon: "arrow.down", color: .green)
                    GlassMetricCard(title: "Max", value: String(format: "%.0f", viewModel.maxLatency), subtitle: "ms", icon: "arrow.up", color: .red)
                    GlassMetricCard(title: "Avg", value: String(format: "%.0f", viewModel.avgLatency), subtitle: "ms", icon: "line.horizontal", color: .amber)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private var signalPercentage: Double {
        // Map -100..0 dBm to 0..100%
        let clamped = max(-100, min(0, Double(viewModel.currentSignalStrength)))
        return (clamped + 100)
    }

    private var basicSignalColor: Color {
        switch viewModel.currentSignalStrength {
        case -50...0: return .green
        case -65..<(-50): return FullBars.Design.Colors.accentCyan
        case -75..<(-65): return .yellow
        default: return .red
        }
    }

    private var basicSignalLabel: String {
        switch viewModel.currentSignalStrength {
        case -50...0: return "Your signal is strong"
        case -65..<(-50): return "Your signal is good"
        case -75..<(-65): return "Your signal is fair"
        case -85..<(-75): return "Your signal is weak"
        default: return "Your signal is very weak"
        }
    }

    private var basicSignalMessage: String {
        switch viewModel.currentSignalStrength {
        case -50...0: return "You should have a great experience streaming, gaming, and browsing."
        case -65..<(-50): return "Most things will work well. You might see occasional buffering."
        case -75..<(-65): return "Web browsing works but video might buffer. Try moving closer to your router."
        case -85..<(-75): return "Connection is unreliable. Move closer to your router or consider a WiFi extender."
        default: return "You're barely connected. Check your router or move to a different location."
        }
    }

    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case -50...(-1): return primaryColor
        case -60...(-51): return .green
        case -70...(-61): return .amber
        case -80...(-71): return .orange
        default: return .red
        }
    }
}

struct GlassMetricCard: View {
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
        .shadow(color: color.opacity(0.2), radius: 4, x: 0, y: 2)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
    }
}

#Preview {
    SignalMonitorView()
        .environment(\.displayMode, .technical)
}
