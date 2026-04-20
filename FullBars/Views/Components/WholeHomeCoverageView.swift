import SwiftUI
import SwiftData

/// Reusable whole-home coverage breakdown showing signal distribution from walkthrough data.
struct WholeHomeCoverageView: View {
    let points: [HeatmapPoint]

    private let electricCyan = FullBars.Design.Colors.accentCyan

    private var coverage: (strong: Double, moderate: Double, weak: Double) {
        DataCollectionService.coverageBreakdown(from: points)
    }

    private var overallLabel: String {
        DataCollectionService.coverageLabel(strong: coverage.strong, moderate: coverage.moderate, weak: coverage.weak)
    }

    private var overallColor: Color {
        switch overallLabel {
        case "Excellent": return .green
        case "Good": return electricCyan
        case "Moderate": return .orange
        case "Poor", "Weak": return .red
        default: return .secondary
        }
    }

    private var avgSpeed: Double {
        let speeds = points.map(\.downloadSpeed).filter { $0 > 0 }
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    private var avgSignal: Int {
        guard !points.isEmpty else { return 0 }
        return points.map(\.signalStrength).reduce(0, +) / points.count
    }

    private var avgLatency: Double {
        let latencies = points.map(\.latency).filter { $0 > 0 }
        guard !latencies.isEmpty else { return 0 }
        return latencies.reduce(0, +) / Double(latencies.count)
    }

    var body: some View {
        if points.isEmpty {
            emptyState
        } else {
            VStack(spacing: 16) {
                overallCard
                coverageBreakdownCard
                // Speed comparison card removed
                statsRow
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(electricCyan.opacity(0.5))

            Text("No coverage data yet")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            Text("Run a Home Scan to map WiFi strength room by room. You'll see exactly where your signal is strong and where it drops off.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(destination: GuidedWalkthroughView()) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                    Text("Start Walkthrough")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(electricCyan.opacity(0.2))
                .foregroundStyle(electricCyan)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        VStack(spacing: 8) {
            Text("Whole Home Coverage")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            Text(overallLabel)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(overallColor)
                .shadow(color: overallColor.opacity(0.5), radius: 12)

            Text("\(points.count) points sampled across your space")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Coverage Breakdown

    private var coverageBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signal Distribution")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if coverage.strong > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: max(4, geo.size.width * coverage.strong / 100))
                    }
                    if coverage.moderate > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: max(4, geo.size.width * coverage.moderate / 100))
                    }
                    if coverage.weak > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: max(4, geo.size.width * coverage.weak / 100))
                    }
                }
            }
            .frame(height: 24)
            .cornerRadius(6)

            // Legend
            HStack(spacing: 16) {
                coverageLegendItem(color: .green, label: "Strong", percent: coverage.strong)
                coverageLegendItem(color: .orange, label: "Moderate", percent: coverage.moderate)
                coverageLegendItem(color: .red, label: "Weak", percent: coverage.weak)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func coverageLegendItem(color: Color, label: String, percent: Double) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(String(format: "%.0f", percent))%")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Avg Signal", value: "\(avgSignal) dBm", color: Color.forSignalStrength(avgSignal))
            statCard(title: "Avg Latency", value: String(format: "%.0f ms", avgLatency), color: avgLatency < 30 ? .green : .orange)
            statCard(title: "Points", value: "\(points.count)", color: electricCyan)
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}
