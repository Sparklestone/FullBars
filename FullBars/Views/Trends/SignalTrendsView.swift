import SwiftUI
import SwiftData

/// Historical signal trends dashboard — tracks signal quality, speed, and health
/// over days/weeks with mini sparkline charts and trend indicators.
struct SignalTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayMode) private var displayMode
    @Query(sort: \NetworkMetrics.timestamp, order: .reverse) private var allMetrics: [NetworkMetrics]
    @Query(sort: \SpeedTestResult.timestamp, order: .reverse) private var allSpeedTests: [SpeedTestResult]
    @State private var selectedRange: TrendRange = .week

    private let electricCyan = FullBars.Design.Colors.accentCyan

    enum TrendRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"

        var interval: TimeInterval {
            switch self {
            case .day: return 86400
            case .week: return 604800
            case .month: return 2592000
            }
        }
    }

    private var filteredMetrics: [NetworkMetrics] {
        let cutoff = Date().addingTimeInterval(-selectedRange.interval)
        return allMetrics.filter { $0.timestamp > cutoff }
    }

    private var filteredSpeedTests: [SpeedTestResult] {
        let cutoff = Date().addingTimeInterval(-selectedRange.interval)
        return allSpeedTests.filter { $0.timestamp > cutoff }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            ForEach(TrendRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        if filteredMetrics.isEmpty && filteredSpeedTests.isEmpty {
                            emptyState
                        } else {
                            // Signal strength trend
                            if !filteredMetrics.isEmpty {
                                trendCard(
                                    title: "Signal Strength",
                                    icon: "wifi",
                                    currentValue: filteredMetrics.first.map { "\($0.signalStrength) dBm" } ?? "--",
                                    trend: signalTrend,
                                    sparklineData: filteredMetrics.reversed().map { Double($0.signalStrength) },
                                    sparklineColor: signalTrendColor,
                                    detail: displayMode == .technical
                                        ? "Avg: \(averageSignal) dBm | Best: \(bestSignal) dBm | Worst: \(worstSignal) dBm"
                                        : signalTrendMessage
                                )
                            }

                            // Download speed trend
                            if !filteredSpeedTests.isEmpty {
                                trendCard(
                                    title: "Download Speed",
                                    icon: "arrow.down.circle.fill",
                                    currentValue: filteredSpeedTests.first.map { String(format: "%.0f Mbps", $0.downloadSpeed) } ?? "--",
                                    trend: speedTrend,
                                    sparklineData: filteredSpeedTests.reversed().map { $0.downloadSpeed },
                                    sparklineColor: speedTrendColor,
                                    detail: displayMode == .technical
                                        ? "Avg: \(String(format: "%.0f", averageDownload)) Mbps | Peak: \(String(format: "%.0f", peakDownload)) Mbps"
                                        : speedTrendMessage
                                )

                                // Upload speed trend (technical only)
                                if displayMode == .technical {
                                    trendCard(
                                        title: "Upload Speed",
                                        icon: "arrow.up.circle.fill",
                                        currentValue: filteredSpeedTests.first.map { String(format: "%.0f Mbps", $0.uploadSpeed) } ?? "--",
                                        trend: uploadTrend,
                                        sparklineData: filteredSpeedTests.reversed().map { $0.uploadSpeed },
                                        sparklineColor: uploadTrend == .improving ? .green : uploadTrend == .declining ? .red : .secondary,
                                        detail: "Avg: \(String(format: "%.0f", averageUpload)) Mbps"
                                    )
                                }

                                // Latency trend (technical only)
                                if displayMode == .technical {
                                    trendCard(
                                        title: "Latency",
                                        icon: "clock.fill",
                                        currentValue: filteredSpeedTests.first.map { String(format: "%.0f ms", $0.latency) } ?? "--",
                                        trend: latencyTrend,
                                        sparklineData: filteredSpeedTests.reversed().map { $0.latency },
                                        sparklineColor: latencyTrend == .improving ? .green : latencyTrend == .declining ? .red : .secondary,
                                        detail: "Avg: \(String(format: "%.0f", averageLatency)) ms"
                                    )
                                }
                            }

                            // Test count summary
                            summaryCard
                        }

                        Spacer().frame(height: 32)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Signal Trends")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Trend Card

    private func trendCard(title: String, icon: String, currentValue: String, trend: TrendDirection,
                           sparklineData: [Double], sparklineColor: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(electricCyan)
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                trendBadge(trend)
            }

            HStack(alignment: .bottom, spacing: 16) {
                Text(currentValue)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Spacer()

                // Mini sparkline
                if sparklineData.count > 1 {
                    SparklineView(data: sparklineData, color: sparklineColor)
                        .frame(width: 120, height: 40)
                }
            }

            Text(detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func trendBadge(_ trend: TrendDirection) -> some View {
        HStack(spacing: 3) {
            Image(systemName: trend.icon)
                .font(.caption2)
            Text(trend.label)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trend.color.opacity(0.2))
        .foregroundStyle(trend.color)
        .cornerRadius(6)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(filteredMetrics.count)")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(electricCyan)
                Text("Readings")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30).opacity(0.3)

            VStack(spacing: 4) {
                Text("\(filteredSpeedTests.count)")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(electricCyan)
                Text("Speed Tests")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30).opacity(0.3)

            VStack(spacing: 4) {
                Text(selectedRange.rawValue)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(electricCyan)
                Text("Period")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(electricCyan.opacity(0.5))

            Text("No trend data yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            Text("Run speed tests and use the app over time to build up your signal history. Trends will appear here once you have data.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            NavigationLink(destination: SpeedTestView()) {
                HStack(spacing: 6) {
                    Image(systemName: "speedometer")
                    Text("Run a Speed Test")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(electricCyan.opacity(0.2))
                .foregroundStyle(electricCyan)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Computed Trend Values

    private var averageSignal: Int {
        guard !filteredMetrics.isEmpty else { return 0 }
        return filteredMetrics.map(\.signalStrength).reduce(0, +) / filteredMetrics.count
    }
    private var bestSignal: Int { filteredMetrics.map(\.signalStrength).max() ?? 0 }
    private var worstSignal: Int { filteredMetrics.map(\.signalStrength).min() ?? 0 }

    private var averageDownload: Double {
        guard !filteredSpeedTests.isEmpty else { return 0 }
        return filteredSpeedTests.map(\.downloadSpeed).reduce(0, +) / Double(filteredSpeedTests.count)
    }
    private var peakDownload: Double { filteredSpeedTests.map(\.downloadSpeed).max() ?? 0 }
    private var averageUpload: Double {
        guard !filteredSpeedTests.isEmpty else { return 0 }
        return filteredSpeedTests.map(\.uploadSpeed).reduce(0, +) / Double(filteredSpeedTests.count)
    }
    private var averageLatency: Double {
        guard !filteredSpeedTests.isEmpty else { return 0 }
        return filteredSpeedTests.map(\.latency).reduce(0, +) / Double(filteredSpeedTests.count)
    }

    private var signalTrend: TrendDirection { computeTrend(filteredMetrics.reversed().map { Double($0.signalStrength) }) }
    private var speedTrend: TrendDirection { computeTrend(filteredSpeedTests.reversed().map(\.downloadSpeed)) }
    private var uploadTrend: TrendDirection { computeTrend(filteredSpeedTests.reversed().map(\.uploadSpeed)) }
    // For latency, lower is better — invert
    private var latencyTrend: TrendDirection {
        let raw = computeTrend(filteredSpeedTests.reversed().map(\.latency))
        switch raw {
        case .improving: return .declining // latency going up = bad
        case .declining: return .improving // latency going down = good
        case .stable: return .stable
        }
    }

    private var signalTrendColor: Color { signalTrend == .improving ? .green : signalTrend == .declining ? .red : .secondary }
    private var speedTrendColor: Color { speedTrend == .improving ? .green : speedTrend == .declining ? .red : .secondary }

    private var signalTrendMessage: String {
        switch signalTrend {
        case .improving: return "Your signal has been getting stronger."
        case .declining: return "Your signal has been weakening over this period."
        case .stable: return "Your signal has been steady."
        }
    }
    private var speedTrendMessage: String {
        switch speedTrend {
        case .improving: return "Your speeds have been getting faster."
        case .declining: return "Your speeds have been dropping."
        case .stable: return "Your speeds have been consistent."
        }
    }

    private func computeTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 3 else { return .stable }
        let half = values.count / 2
        let firstHalfAvg = values.prefix(half).reduce(0, +) / Double(half)
        let secondHalfAvg = values.suffix(half).reduce(0, +) / Double(half)
        let change = (secondHalfAvg - firstHalfAvg) / max(abs(firstHalfAvg), 1) * 100
        if change > 5 { return .improving }
        if change < -5 { return .declining }
        return .stable
    }
}

// MARK: - Trend Direction

enum TrendDirection {
    case improving, declining, stable

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    var label: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .secondary
        }
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minVal = data.min() ?? 0
            let maxVal = data.max() ?? 1
            let range = max(maxVal - minVal, 1)

            Path { path in
                for (index, value) in data.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                    let y = geo.size.height - (geo.size.height * CGFloat((value - minVal) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    SignalTrendsView()
        .environment(\.displayMode, .technical)
}
