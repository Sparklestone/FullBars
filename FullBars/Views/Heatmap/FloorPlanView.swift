import SwiftUI

/// 2D floor plan rendering from saved walkthrough session data.
/// Shows signal heatmap overlaid on detected room boundaries.
struct FloorPlanView: View {
    let points: [HeatmapPoint]
    let walls: [DetectedWall]
    let rooms: [DetectedRoom]
    let displayMode: DisplayMode
    var onPointTapped: ((HeatmapPoint) -> Void)?

    @State private var selectedPoint: HeatmapPoint?

    private let electricCyan = FullBars.Design.Colors.accentCyan

    // Compute bounds from all points
    private var bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float) {
        guard !points.isEmpty else { return (0, 1, 0, 1) }
        let xs = points.map(\.x)
        let ys = points.map(\.z) // Use z for top-down view
        let padding: Float = 1.0
        return (
            (xs.min() ?? 0) - padding,
            (xs.max() ?? 0) + padding,
            (ys.min() ?? 0) - padding,
            (ys.max() ?? 0) + padding
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let b = bounds

                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FullBars.Design.Colors.primaryBackground)

                    // Grid
                    Canvas { context, size in
                        drawGrid(context: context, size: size)
                    }

                    // Heatmap interpolation (technical mode)
                    if displayMode == .technical && points.count >= 3 {
                        Canvas { context, size in
                            drawHeatmapGradient(context: context, size: size, bounds: b)
                        }
                        .opacity(0.4)
                    }

                    // Walls
                    ForEach(walls) { wall in
                        let start = mapToView(
                            x: Float(wall.start.x), y: Float(wall.start.y),
                            bounds: b, size: CGSize(width: width, height: height)
                        )
                        let end = mapToView(
                            x: Float(wall.end.x), y: Float(wall.end.y),
                            bounds: b, size: CGSize(width: width, height: height)
                        )

                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    }

                    // Signal points
                    ForEach(points) { point in
                        let pos = mapToView(
                            x: point.x, y: point.z,
                            bounds: b, size: CGSize(width: width, height: height)
                        )

                        signalDot(for: point, at: pos)
                            .onTapGesture {
                                selectedPoint = point
                                onPointTapped?(point)
                            }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Selected point info
            if let point = selectedPoint {
                pointInfoCard(for: point)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Legend
            floorPlanLegend
        }
    }

    // MARK: - Drawing Helpers

    private func mapToView(x: Float, y: Float, bounds b: (minX: Float, maxX: Float, minY: Float, maxY: Float), size: CGSize) -> CGPoint {
        let rangeX = b.maxX - b.minX
        let rangeY = b.maxY - b.minY
        let normalizedX = CGFloat((x - b.minX) / rangeX) * size.width
        let normalizedY = CGFloat((y - b.minY) / rangeY) * size.height
        return CGPoint(x: normalizedX, y: normalizedY)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 30
        for x in stride(from: 0, through: size.width, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(.white.opacity(0.05)))
        }
        for y in stride(from: 0, through: size.height, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(.white.opacity(0.05)))
        }
    }

    private func drawHeatmapGradient(context: GraphicsContext, size: CGSize, bounds b: (minX: Float, maxX: Float, minY: Float, maxY: Float)) {
        // Simple point-based radial gradient heatmap
        for point in points {
            let pos = mapToView(x: point.x, y: point.z, bounds: b, size: size)
            let color = signalColor(point.signalStrength)
            let radius: CGFloat = 30

            let rect = CGRect(
                x: pos.x - radius,
                y: pos.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(0.25))
            )
        }
    }

    @ViewBuilder
    private func signalDot(for point: HeatmapPoint, at position: CGPoint) -> some View {
        let color = signalColor(point.signalStrength)
        let isSelected = selectedPoint?.id == point.id

        ZStack {
            // Glow
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: isSelected ? 24 : 18, height: isSelected ? 24 : 18)

            // Main dot
            Circle()
                .fill(color)
                .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                .shadow(color: color.opacity(0.6), radius: 4)
        }
        .position(position)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    @ViewBuilder
    private func pointInfoCard(for point: HeatmapPoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(signalColor(point.signalStrength))
                .frame(width: 12, height: 12)
                .shadow(color: signalColor(point.signalStrength).opacity(0.6), radius: 4)

            if displayMode == .technical {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(point.signalStrength) dBm (est.)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                    Text("Latency: \(Int(point.latency))ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(basicSignalLabel(point.signalStrength))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var floorPlanLegend: some View {
        HStack(spacing: 12) {
            ForEach([
                ("Excellent", Color.green),
                ("Good", FullBars.Design.Colors.accentCyan),
                ("Fair", Color.yellow),
                ("Weak", Color.orange),
                ("Poor", Color.red)
            ], id: \.0) { label, color in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case -50...0: return .green
        case -60..<(-50): return FullBars.Design.Colors.accentCyan
        case -70..<(-60): return .yellow
        case -80..<(-70): return .orange
        default: return .red
        }
    }

    private func basicSignalLabel(_ strength: Int) -> String {
        switch strength {
        case -50...0: return "Signal is excellent here"
        case -60..<(-50): return "Signal is good here"
        case -70..<(-60): return "Signal is fair here — try moving closer to your router"
        case -80..<(-70): return "Signal is weak here — try moving your router closer"
        default: return "Signal is very poor here — consider a WiFi extender"
        }
    }
}
