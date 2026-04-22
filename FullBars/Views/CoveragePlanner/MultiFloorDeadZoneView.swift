import SwiftUI
import SwiftData

/// Multi-floor signal weak spot diagnosis view.
/// Shows a stacked floor-by-floor overview with coverage grades,
/// weak spot counts, and mesh node recommendations per floor.
struct MultiFloorWeakSpotView: View {
    @Query(sort: \HeatmapPoint.timestamp, order: .reverse) private var allPoints: [HeatmapPoint]
    @State private var floorSummaries: [FloorCoverageSummary] = []
    @State private var expandedFloor: Int?
    @State private var analysis: CoverageAnalysisResult?

    @Environment(\.displayMode) private var displayMode
    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if allPoints.isEmpty {
                    emptyState
                } else {
                    // Building overview
                    buildingOverview

                    // 3D-ish stacked floor visualization
                    stackedFloorVisualization
                        .padding(.horizontal, 16)

                    // Per-floor detail cards
                    floorDetailCards

                    // Recommendations summary
                    if let analysis, !analysis.meshRecommendations.isEmpty {
                        recommendationsSummary(analysis)
                    }

                    Spacer(minLength: 40)
                }
            }
            .padding(.vertical, 16)
        }
        .background(FullBars.Design.Colors.primaryBackground)
        .navigationTitle("Weak Spot Diagnosis")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { runAnalysis() }
        .onChange(of: allPoints.count) { _, _ in runAnalysis() }
    }

    private func runAnalysis() {
        guard !allPoints.isEmpty else { return }
        analysis = CoveragePlanningService.analyze(points: allPoints)
        floorSummaries = CoveragePlanningService.floorSummaries(points: allPoints)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)

            ZStack {
                Circle()
                    .fill(electricCyan.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(electricCyan)
            }

            Text("No Multi-Floor Data")
                .font(FullBars.Design.Typography.title)
                .foregroundStyle(.white)

            Text("Scan multiple floors during your Home Scan to see cross-floor signal analysis and weak spot diagnosis.")
                .font(FullBars.Design.Typography.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            NavigationLink(destination: GuidedWalkthroughView()) {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                    Text("Start Home Scan")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Capsule().fill(electricCyan))
            }

            Spacer(minLength: 60)
        }
    }

    // MARK: - Building Overview

    private var buildingOverview: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Building Signal Health")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(floorSummaries.count) floor\(floorSummaries.count == 1 ? "" : "s") scanned · \(allPoints.count) data points")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()

                if let analysis {
                    VStack(spacing: 2) {
                        Text("\(Int(analysis.coveragePercentage))%")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(analysis.assessmentColor)
                        Text("Coverage")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            // Signal flow diagram: shows signal strength dropping per floor
            if floorSummaries.count > 1 {
                signalFlowDiagram
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FullBars.Design.Colors.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        )
        .padding(.horizontal, 16)
    }

    private var signalFlowDiagram: some View {
        VStack(spacing: 8) {
            Text("Signal Degradation Across Floors")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 0) {
                ForEach(floorSummaries) { summary in
                    VStack(spacing: 4) {
                        // Signal strength bar
                        let normalized = CGFloat(max(0, min(100, summary.averageSignal + 100))) / 100
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.forSignalStrength(summary.averageSignal))
                            .frame(width: 28, height: max(12, normalized * 60))

                        Text("\(summary.averageSignal)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(summary.floorLabel)
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)

                    if summary.floorIndex < floorSummaries.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            if floorSummaries.count >= 2 {
                let drop = floorSummaries.first!.averageSignal - floorSummaries.last!.averageSignal
                if drop > 0 {
                    Text("Signal drops \(drop) dBm from \(floorSummaries.first!.floorLabel) to \(floorSummaries.last!.floorLabel)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Stacked Floor Visualization

    private var stackedFloorVisualization: some View {
        VStack(spacing: 0) {
            ForEach(floorSummaries.reversed()) { summary in
                stackedFloorRow(summary: summary)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(FullBars.Design.Colors.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
        )
    }

    @ViewBuilder
    private func stackedFloorRow(summary: FloorCoverageSummary) -> some View {
        let isExpanded = expandedFloor == summary.floorIndex

        Button {
            withAnimation(.spring(response: 0.3)) {
                expandedFloor = isExpanded ? nil : summary.floorIndex
            }
        } label: {
            stackedFloorRowContent(summary: summary, isExpanded: isExpanded)
        }
        .buttonStyle(.plain)

        // Expanded mini floor plan
        if isExpanded {
            let floorPoints = allPoints.filter { $0.floorIndex == summary.floorIndex }
            miniFloorPlan(points: floorPoints, floorIndex: summary.floorIndex)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .background(FullBars.Design.Colors.cardSurface)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }

        if summary.floorIndex > 0 {
            stackedFloorSeparator
        }
    }

    @ViewBuilder
    private func stackedFloorRowContent(summary: FloorCoverageSummary, isExpanded: Bool) -> some View {
        HStack(spacing: 12) {
            // Floor grade badge
            stackedFloorGradeBadge(summary: summary)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.floorLabel)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label("\(Int(summary.coveragePercentage))%", systemImage: "wifi")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.forSignalStrength(summary.averageSignal))

                    if summary.weakSpotCount > 0 {
                        Label("\(summary.weakSpotCount) weak spot\(summary.weakSpotCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(FullBars.Design.Colors.signalPoor)
                    }

                    if summary.meshNodesNeeded > 0 {
                        Label("\(summary.meshNodesNeeded) node\(summary.meshNodesNeeded == 1 ? "" : "s") needed", systemImage: "wifi.router.fill")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(electricCyan)
                    }
                }
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 12 : 0)
                .fill(FullBars.Design.Colors.cardSurface)
        )
    }

    @ViewBuilder
    private func stackedFloorGradeBadge(summary: FloorCoverageSummary) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(summary.grade.color.opacity(0.2))
                .frame(width: 40, height: 40)
            Text(summary.grade.rawValue)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(summary.grade.color)
        }
    }

    private var stackedFloorSeparator: some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
    }

    private func miniFloorPlan(points: [HeatmapPoint], floorIndex: Int) -> some View {
        GeometryReader { geo in
            let size = geo.size
            let bounds = pointBounds(points)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(FullBars.Design.Colors.primaryBackground)

                // Signal dots
                ForEach(points) { point in
                    let pos = mapToView(x: point.x, y: point.z, bounds: bounds, size: size)
                    Circle()
                        .fill(Color.forSignalStrength(point.signalStrength))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.forSignalStrength(point.signalStrength).opacity(0.4), radius: 2)
                        .position(pos)
                }

                // Weak spot markers
                if let analysis {
                    ForEach(analysis.weakSpots.filter { $0.floorIndex == floorIndex }) { dz in
                        let pos = mapToView(x: dz.centerX, y: dz.centerZ, bounds: bounds, size: size)
                        ZStack {
                            Circle()
                                .fill(dz.severity.color.opacity(0.2))
                                .frame(width: 20, height: 20)
                            Image(systemName: dz.severity.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(dz.severity.color)
                        }
                        .position(pos)
                    }

                    // Mesh placement markers
                    ForEach(analysis.meshRecommendations.filter { $0.floorIndex == floorIndex && $0.type != .primaryRouter }) { rec in
                        let pos = mapToView(x: rec.x, y: rec.z, bounds: bounds, size: size)
                        ZStack {
                            Circle()
                                .fill(rec.type.color.opacity(0.3))
                                .frame(width: 16, height: 16)
                            Image(systemName: rec.type.icon)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(rec.type.color)
                        }
                        .position(pos)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
        }
        .frame(height: 140)
    }

    // MARK: - Floor Detail Cards

    private var floorDetailCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Floor-by-Floor Analysis")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)

            ForEach(floorSummaries) { summary in
                floorDetailCard(summary: summary)
            }
        }
    }

    @ViewBuilder
    private func floorDetailCard(summary: FloorCoverageSummary) -> some View {
        NavigationLink(destination: CoveragePlannerView()) {
            HStack(spacing: 12) {
                floorCoverageRing(summary: summary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.floorLabel)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text("\(Int(summary.coveragePercentage))% coverage · \(summary.averageSignal) dBm avg · \(summary.pointCount) pts")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    if summary.weakSpotCount > 0 || summary.meshNodesNeeded > 0 {
                        floorDetailBadges(summary: summary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(FullBars.Design.Colors.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)))
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func floorCoverageRing(summary: FloorCoverageSummary) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                .frame(width: 44, height: 44)
            Circle()
                .trim(from: 0, to: summary.coveragePercentage / 100)
                .stroke(summary.grade.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))
            Text(summary.grade.rawValue)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(summary.grade.color)
        }
    }

    @ViewBuilder
    private func floorDetailBadges(summary: FloorCoverageSummary) -> some View {
        HStack(spacing: 8) {
            if summary.weakSpotCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(FullBars.Design.Colors.signalPoor)
                    Text("\(summary.weakSpotCount) weak spot\(summary.weakSpotCount == 1 ? "" : "s")")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(FullBars.Design.Colors.signalPoor)
                }
            }
            if summary.meshNodesNeeded > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "wifi.router.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(electricCyan)
                    Text("\(summary.meshNodesNeeded) mesh node\(summary.meshNodesNeeded == 1 ? "" : "s") recommended")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(electricCyan)
                }
            }
        }
    }

    // MARK: - Recommendations Summary

    private func recommendationsSummary(_ analysis: CoverageAnalysisResult) -> some View {
        let actionableRecs = analysis.meshRecommendations.filter { $0.type != .primaryRouter }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Recommendations")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                if analysis.hasCriticalWeakSpots {
                    recommendationRow(
                        icon: "exclamationmark.octagon.fill",
                        color: FullBars.Design.Colors.signalNoSignal,
                        text: "Critical weak spots detected. A mesh WiFi system is strongly recommended for full coverage."
                    )
                }

                if actionableRecs.count > 0 {
                    recommendationRow(
                        icon: "wifi.router.fill",
                        color: electricCyan,
                        text: "Add \(actionableRecs.count) mesh node\(actionableRecs.count == 1 ? "" : "s") to achieve optimal coverage. See the Coverage Planner for exact placement."
                    )
                }

                if analysis.floorCount > 1 {
                    let worstFloor = floorSummaries.min { $0.coveragePercentage < $1.coveragePercentage }
                    if let worst = worstFloor, worst.coveragePercentage < 70 {
                        recommendationRow(
                            icon: "building.2.fill",
                            color: FullBars.Design.Colors.signalFair,
                            text: "\(worst.floorLabel) has the weakest coverage (\(Int(worst.coveragePercentage))%). Prioritize mesh placement there."
                        )
                    }
                }

                if !analysis.interferenceZones.isEmpty {
                    recommendationRow(
                        icon: "antenna.radiowaves.left.and.right",
                        color: .purple,
                        text: "\(analysis.interferenceZones.count) interference zone\(analysis.interferenceZones.count == 1 ? "" : "s") detected. Consider switching WiFi channels or moving interfering devices."
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(FullBars.Design.Colors.cardSurface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
            )
            .padding(.horizontal, 16)
        }
    }

    private func recommendationRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func pointBounds(_ points: [HeatmapPoint]) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        guard !points.isEmpty else { return (0, 1, 0, 1) }
        let xs = points.map(\.x)
        let zs = points.map(\.z)
        let padding: Double = 1.5
        return (
            (xs.min() ?? 0) - padding,
            (xs.max() ?? 0) + padding,
            (zs.min() ?? 0) - padding,
            (zs.max() ?? 0) + padding
        )
    }

    private func mapToView(x: Double, y: Double, bounds b: (minX: Double, maxX: Double, minY: Double, maxY: Double), size: CGSize) -> CGPoint {
        let rangeX = max(0.001, b.maxX - b.minX)
        let rangeY = max(0.001, b.maxY - b.minY)
        return CGPoint(
            x: CGFloat((x - b.minX) / rangeX) * size.width,
            y: CGFloat((y - b.minY) / rangeY) * size.height
        )
    }
}

#Preview {
    NavigationStack {
        MultiFloorWeakSpotView()
    }
    .preferredColorScheme(.dark)
}
