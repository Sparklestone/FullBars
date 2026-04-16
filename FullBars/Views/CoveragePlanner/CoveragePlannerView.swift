import SwiftUI
import SwiftData

/// Interactive coverage planner showing dead zones, mesh placement recommendations,
/// and interference areas overlaid on a 2D floor plan with edge indicators.
struct CoveragePlannerView: View {
    @Query(sort: \HeatmapPoint.timestamp, order: .reverse) private var allPoints: [HeatmapPoint]
    @State private var analysis: CoverageAnalysisResult?
    @State private var selectedFloor: Int = 0
    @State private var showDeadZones = true
    @State private var showMeshPlacements = true
    @State private var showInterference = true
    @State private var showRouter = true
    @State private var selectedDeadZone: DeadZone?
    @State private var selectedMeshRec: MeshPlacementRecommendation?
    @State private var showPaywall = false
    @State private var subscription = SubscriptionManager.shared

    @Environment(\.displayMode) private var displayMode

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if allPoints.isEmpty {
                    emptyState
                } else {
                    // Summary header
                    if let analysis {
                        summaryHeader(analysis)
                    }

                    // Floor picker (if multi-floor)
                    if let analysis, analysis.floorCount > 1 {
                        floorPicker(floorCount: analysis.floorCount)
                    }

                    // Main floor plan with overlays
                    floorPlanWithOverlays
                        .padding(.horizontal, 16)

                    // Layer toggles
                    layerToggles
                        .padding(.horizontal, 16)

                    // Dead zone detail cards
                    if let analysis, showDeadZones {
                        deadZoneCards(analysis.deadZones.filter { $0.floorIndex == selectedFloor })
                    }

                    // Mesh placement cards
                    if let analysis, showMeshPlacements {
                        meshPlacementCards(analysis.meshRecommendations.filter { $0.floorIndex == selectedFloor })
                    }

                    // Interference cards
                    if let analysis, showInterference {
                        interferenceCards(analysis.interferenceZones.filter { $0.floorIndex == selectedFloor })
                    }

                    Spacer(minLength: 40)
                }
            }
            .padding(.vertical, 16)
        }
        .background(FullBars.Design.Colors.primaryBackground)
        .navigationTitle("Coverage Planner")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) { ProPaywallView() }
        .onAppear { runAnalysis() }
        .onChange(of: allPoints.count) { _, _ in runAnalysis() }
    }

    // MARK: - Analysis

    private func runAnalysis() {
        guard !allPoints.isEmpty else { return }
        analysis = CoveragePlanningService.analyze(points: allPoints)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)

            ZStack {
                Circle()
                    .fill(electricCyan.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(electricCyan)
            }

            Text("No Coverage Data Yet")
                .font(FullBars.Design.Typography.title)
                .foregroundStyle(.white)

            Text("Run a Home Scan first to map your WiFi coverage, then come back here to see dead zones, mesh placement recommendations, and interference areas.")
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
            .padding(.top, 8)

            Spacer(minLength: 60)
        }
    }

    // MARK: - Summary Header

    private func summaryHeader(_ analysis: CoverageAnalysisResult) -> some View {
        VStack(spacing: 12) {
            // Coverage score ring
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: analysis.coveragePercentage / 100)
                        .stroke(analysis.assessmentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(analysis.coveragePercentage))%")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Coverage Score")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(analysis.overallAssessment)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            // Quick stats
            HStack(spacing: 0) {
                statPill(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(analysis.deadZoneCount)",
                    label: "Dead Zones",
                    color: analysis.deadZoneCount > 0 ? FullBars.Design.Colors.signalPoor : .green
                )
                Spacer()
                statPill(
                    icon: "wifi.router.fill",
                    value: "\(analysis.meshNodesNeeded)",
                    label: "Nodes Needed",
                    color: analysis.meshNodesNeeded > 0 ? electricCyan : .green
                )
                Spacer()
                statPill(
                    icon: "antenna.radiowaves.left.and.right",
                    value: "\(analysis.interferenceZones.count)",
                    label: "Interference",
                    color: analysis.interferenceZones.isEmpty ? .green : .purple
                )
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

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Floor Picker

    private func floorPicker(floorCount: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<floorCount, id: \.self) { floor in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedFloor = floor }
                } label: {
                    Text(floor == 0 ? "Ground" : "Floor \(floor + 1)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(selectedFloor == floor ? .bold : .regular)
                        .foregroundStyle(selectedFloor == floor ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selectedFloor == floor ? electricCyan : Color.white.opacity(0.08))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Floor Plan with Overlays + Edge Indicators

    private var floorPlanWithOverlays: some View {
        let floorPoints = allPoints.filter { $0.floorIndex == selectedFloor }

        return GeometryReader { geo in
            let size = geo.size
            let bounds = pointBounds(floorPoints)

            ZStack {
                // Base floor plan with grid
                RoundedRectangle(cornerRadius: 16)
                    .fill(FullBars.Design.Colors.primaryBackground)

                Canvas { context, canvasSize in
                    drawGrid(context: context, size: canvasSize)
                }

                // Heatmap dots
                ForEach(floorPoints) { point in
                    let pos = mapToView(x: point.x, y: point.z, bounds: bounds, size: size)
                    Circle()
                        .fill(Color.forSignalStrength(point.signalStrength).opacity(0.5))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color.forSignalStrength(point.signalStrength).opacity(0.4), radius: 4)
                        .position(pos)
                }

                // Dead zone overlays
                if showDeadZones, let analysis {
                    ForEach(analysis.deadZones.filter { $0.floorIndex == selectedFloor }) { dz in
                        let pos = mapToView(x: dz.centerX, y: dz.centerZ, bounds: bounds, size: size)
                        let radiusPx = mapRadius(dz.radius, bounds: bounds, size: size)

                        deadZoneOverlay(dz, at: pos, radius: radiusPx)
                            .onTapGesture { selectedDeadZone = dz }
                    }
                }

                // Interference overlays
                if showInterference, let analysis {
                    ForEach(analysis.interferenceZones.filter { $0.floorIndex == selectedFloor }) { iz in
                        let pos = mapToView(x: iz.centerX, y: iz.centerZ, bounds: bounds, size: size)
                        let radiusPx = mapRadius(iz.radius, bounds: bounds, size: size)

                        interferenceOverlay(iz, at: pos, radius: radiusPx)
                    }
                }

                // Mesh placement markers
                if showMeshPlacements, let analysis {
                    ForEach(analysis.meshRecommendations.filter { $0.floorIndex == selectedFloor }) { rec in
                        let pos = mapToView(x: rec.x, y: rec.z, bounds: bounds, size: size)
                        meshPlacementMarker(rec, at: pos)
                            .onTapGesture { selectedMeshRec = rec }
                    }
                }

                // Router position
                if showRouter, let analysis, let router = analysis.estimatedRouterPosition {
                    let pos = mapToView(x: Float(router.x), y: Float(router.y), bounds: bounds, size: size)
                    routerMarker(at: pos)
                }

                // Edge indicators
                if let analysis {
                    edgeIndicatorsOverlay(analysis: analysis, bounds: bounds, viewSize: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Dead Zone Overlay

    private func deadZoneOverlay(_ dz: DeadZone, at position: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            // Pulsing danger circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [dz.severity.color.opacity(0.3), dz.severity.color.opacity(0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .stroke(dz.severity.color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .frame(width: radius * 2, height: radius * 2)

            // Center icon
            VStack(spacing: 2) {
                Image(systemName: dz.severity.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(dz.severity.color)
                if let room = dz.roomName {
                    Text(room)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .position(position)
    }

    // MARK: - Interference Overlay

    private func interferenceOverlay(_ iz: InterferenceZone, at position: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(iz.interferenceLevel.color.opacity(0.15))
                .frame(width: radius * 2, height: radius * 2)

            Circle()
                .stroke(iz.interferenceLevel.color.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .frame(width: radius * 2, height: radius * 2)

            Image(systemName: iz.interferenceLevel.icon)
                .font(.system(size: 12))
                .foregroundStyle(iz.interferenceLevel.color)
        }
        .position(position)
    }

    // MARK: - Mesh Placement Marker

    private func meshPlacementMarker(_ rec: MeshPlacementRecommendation, at position: CGPoint) -> some View {
        ZStack {
            // Coverage radius circle
            Circle()
                .fill(rec.type.color.opacity(0.08))
                .frame(width: 50, height: 50)

            Circle()
                .stroke(rec.type.color.opacity(0.3), lineWidth: 1)
                .frame(width: 50, height: 50)

            // Pin marker
            VStack(spacing: 1) {
                ZStack {
                    Circle()
                        .fill(rec.type.color)
                        .frame(width: 24, height: 24)
                        .shadow(color: rec.type.color.opacity(0.5), radius: 4)

                    Image(systemName: rec.type.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }

                if rec.type != .primaryRouter {
                    Text("#\(rec.priority)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(rec.type.color)
                }
            }
        }
        .position(position)
    }

    // MARK: - Router Marker

    private func routerMarker(at position: CGPoint) -> some View {
        ZStack {
            // Signal rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(electricCyan.opacity(0.15 - Double(ring) * 0.04), lineWidth: 1)
                    .frame(
                        width: CGFloat(30 + ring * 16),
                        height: CGFloat(30 + ring * 16)
                    )
            }

            ZStack {
                Circle()
                    .fill(electricCyan)
                    .frame(width: 22, height: 22)
                    .shadow(color: electricCyan.opacity(0.5), radius: 6)

                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .position(position)
    }

    // MARK: - Edge Indicators Overlay

    private func edgeIndicatorsOverlay(analysis: CoverageAnalysisResult, bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float), viewSize: CGSize) -> some View {
        let cgBounds = CGRect(
            x: CGFloat(bounds.minX),
            y: CGFloat(bounds.minY),
            width: CGFloat(bounds.maxX - bounds.minX),
            height: CGFloat(bounds.maxY - bounds.minY)
        )
        let indicators = CoveragePlanningService.generateEdgeIndicators(
            analysis: analysis,
            visibleBounds: cgBounds,
            viewSize: viewSize
        )

        return ZStack {
            ForEach(indicators) { indicator in
                edgeIndicatorView(indicator, viewSize: viewSize)
            }
        }
    }

    private func edgeIndicatorView(_ indicator: EdgeIndicator, viewSize: CGSize) -> some View {
        let position: CGPoint
        let rotation: Angle

        switch indicator.edge {
        case .top:
            position = CGPoint(x: viewSize.width * indicator.position, y: 16)
            rotation = .degrees(0)
        case .bottom:
            position = CGPoint(x: viewSize.width * indicator.position, y: viewSize.height - 16)
            rotation = .degrees(180)
        case .leading:
            position = CGPoint(x: 16, y: viewSize.height * indicator.position)
            rotation = .degrees(-90)
        case .trailing:
            position = CGPoint(x: viewSize.width - 16, y: viewSize.height * indicator.position)
            rotation = .degrees(90)
        }

        return HStack(spacing: 3) {
            Image(systemName: indicator.type.icon)
                .font(.system(size: 9, weight: .bold))
            Text(indicator.label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(indicator.color.opacity(0.85))
        )
        .shadow(color: indicator.color.opacity(0.4), radius: 3)
        .position(position)
    }

    // MARK: - Layer Toggles

    private var layerToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Map Layers")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 8) {
                layerToggle("Dead Zones", icon: "exclamationmark.triangle.fill", color: FullBars.Design.Colors.signalPoor, isOn: $showDeadZones)
                layerToggle("Mesh", icon: "wifi.router.fill", color: FullBars.Design.Colors.signalGood, isOn: $showMeshPlacements)
                layerToggle("Interference", icon: "antenna.radiowaves.left.and.right", color: .purple, isOn: $showInterference)
                layerToggle("Router", icon: "wifi.circle.fill", color: electricCyan, isOn: $showRouter)
            }
        }
    }

    private func layerToggle(_ label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOn.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isOn.wrappedValue ? .white : .white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isOn.wrappedValue ? color.opacity(0.25) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(isOn.wrappedValue ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
    }

    // MARK: - Dead Zone Cards

    private func deadZoneCards(_ zones: [DeadZone]) -> some View {
        Group {
            if !zones.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(FullBars.Design.Colors.signalPoor)
                        Text("Dead Zones")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)

                    ForEach(zones) { dz in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(dz.severity.color.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: dz.severity.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(dz.severity.color)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(dz.roomName ?? "Dead Zone")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(dz.severity.label)
                                        .font(.system(.caption2, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(dz.severity.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(dz.severity.color.opacity(0.15)))
                                }
                                Text(dz.severity.friendlyDescription)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(dz.averageSignal) dBm avg · \(dz.pointCount) data points")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FullBars.Design.Colors.cardSurface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(dz.severity.color.opacity(0.15)))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Mesh Placement Cards

    private func meshPlacementCards(_ recs: [MeshPlacementRecommendation]) -> some View {
        let actionableRecs = recs.filter { $0.type != .primaryRouter }
        return Group {
            if !actionableRecs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "wifi.router.fill")
                            .foregroundStyle(FullBars.Design.Colors.signalGood)
                        Text("Recommended Placement")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)

                    ForEach(actionableRecs) { rec in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(rec.type.color.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: rec.type.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(rec.type.color)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Place \(rec.type.label)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    if let room = rec.nearestRoomName {
                                        Text("near \(room)")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Text("Priority \(rec.priority)")
                                        .font(.system(.caption2, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(rec.type.color)
                                }
                                Text(rec.expectedImpact)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(rec.reason)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FullBars.Design.Colors.cardSurface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(rec.type.color.opacity(0.15)))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Interference Cards

    private func interferenceCards(_ zones: [InterferenceZone]) -> some View {
        Group {
            if !zones.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.purple)
                        Text("Interference Zones")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)

                    ForEach(zones) { iz in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(iz.interferenceLevel.color.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: iz.interferenceLevel.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(iz.interferenceLevel.color)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(iz.roomName ?? "Interference Area")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(iz.interferenceLevel.rawValue.capitalized)
                                        .font(.system(.caption2, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(iz.interferenceLevel.color)
                                }
                                ForEach(iz.likelySources.prefix(2), id: \.self) { source in
                                    Text("• \(source)")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(FullBars.Design.Colors.cardSurface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(iz.interferenceLevel.color.opacity(0.15)))
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Drawing Helpers

    private func pointBounds(_ points: [HeatmapPoint]) -> (minX: Float, maxX: Float, minY: Float, maxY: Float) {
        guard !points.isEmpty else { return (0, 1, 0, 1) }
        let xs = points.map(\.x)
        let zs = points.map(\.z)
        let padding: Float = 2.0
        return (
            (xs.min() ?? 0) - padding,
            (xs.max() ?? 0) + padding,
            (zs.min() ?? 0) - padding,
            (zs.max() ?? 0) + padding
        )
    }

    private func mapToView(x: Float, y: Float, bounds b: (minX: Float, maxX: Float, minY: Float, maxY: Float), size: CGSize) -> CGPoint {
        let rangeX = max(0.001, b.maxX - b.minX)
        let rangeY = max(0.001, b.maxY - b.minY)
        return CGPoint(
            x: CGFloat((x - b.minX) / rangeX) * size.width,
            y: CGFloat((y - b.minY) / rangeY) * size.height
        )
    }

    private func mapRadius(_ meters: Float, bounds b: (minX: Float, maxX: Float, minY: Float, maxY: Float), size: CGSize) -> CGFloat {
        let rangeX = max(0.001, b.maxX - b.minX)
        return CGFloat(meters / rangeX) * size.width
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 30
        for x in stride(from: CGFloat(0), through: size.width, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.04)))
        }
        for y in stride(from: CGFloat(0), through: size.height, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.white.opacity(0.04)))
        }
    }
}

#Preview {
    NavigationStack {
        CoveragePlannerView()
    }
    .preferredColorScheme(.dark)
}
