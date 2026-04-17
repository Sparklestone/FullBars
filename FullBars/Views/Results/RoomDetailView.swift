import SwiftUI
import SwiftData

/// Detailed view of a single scanned room. Shows the room's polygon, painted
/// coverage, a signal heatmap from captured HeatmapPoints, device placements,
/// aggregate stats, and recommendations.
struct RoomDetailView: View {
    let room: Room

    @Environment(\.modelContext) private var modelContext
    @Query private var allPoints: [HeatmapPoint]
    @Query private var allDevices: [DevicePlacement]
    @Query private var allDoorways: [Doorway]
    @Query(sort: \Room.createdAt, order: .reverse) private var allRooms: [Room]

    @State private var subs = SubscriptionManager.shared
    private var history: [Room] {
        RescanHistory.history(forSlotMatching: room, in: allRooms.filter { $0.homeId == room.homeId })
    }

    @State private var showHeatmap: Bool = true
    @State private var showDeadZones: Bool = true
    @State private var showPainted: Bool = true
    @State private var showDevices: Bool = true

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    // MARK: - Filtered data

    private var points: [HeatmapPoint] {
        allPoints.filter { $0.roomId == room.id }
    }
    private var devices: [DevicePlacement] {
        allDevices.filter { $0.roomId == room.id }
    }
    private var doorways: [Doorway] {
        allDoorways.filter { $0.roomId == room.id }
    }
    private var deadZonePoints: [HeatmapPoint] {
        points.filter { $0.signalStrength < -80 }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gradeCard
                    metricsGrid
                    mapCard
                    layerToggles
                    if history.count > 1 { historyCard }
                    recommendationsCard
                }
                .padding(20)
            }
        }
        .navigationTitle(room.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    // MARK: - Grade card

    private var gradeCard: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)
                    .frame(width: 96, height: 96)
                Circle()
                    .trim(from: 0, to: CGFloat(room.gradeScore / 100))
                    .stroke(gradeColor(room.gradeLetterRaw),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-90))
                Text(room.gradeLetterRaw.isEmpty ? "–" : room.gradeLetterRaw)
                    .accessibilityIdentifier(AccessibilityID.RoomDetail.gradeRing)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor(room.gradeLetterRaw))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(room.gradeScore)) / 100")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(gradeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    private var gradeSummary: String {
        switch room.gradeLetterRaw.uppercased() {
        case "A": return "Excellent coverage throughout this room."
        case "B": return "Good coverage with minor weak spots."
        case "C": return "Usable, but some trouble areas."
        case "D": return "Noticeable gaps. A mesh node could help."
        default:  return "Significant dead zones. Consider repositioning your router or adding a mesh node."
        }
    }

    // MARK: - Metric grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricTile(label: "Download", value: "\(Int(room.downloadMbps))", unit: "Mbps", color: .green)
                metricTile(label: "Upload",   value: "\(Int(room.uploadMbps))",   unit: "Mbps", color: .blue)
            }
            HStack(spacing: 12) {
                metricTile(label: "Ping", value: "\(Int(room.pingMs))", unit: "ms", color: .yellow)
                metricTile(label: "Coverage",
                           value: "\(Int(room.paintedCoverageFraction * 100))",
                           unit: "% walked",
                           color: coverageColor(room.paintedCoverageFraction))
            }
            HStack(spacing: 12) {
                metricTile(label: "Dead zones",
                           value: "\(deadZonePoints.count)",
                           unit: "samples",
                           color: deadZonePoints.isEmpty ? .green : .red)
                metricTile(label: "BLE nearby",
                           value: "\(room.bleDeviceCount)",
                           unit: "devices",
                           color: room.bleDeviceCount > 10 ? .orange : .secondary)
            }
        }
    }

    private func metricTile(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Map

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Floor plan")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            RoomMapCanvas(
                room: room,
                points: showHeatmap ? points : [],
                deadZonePoints: showDeadZones ? deadZonePoints : [],
                devices: showDevices ? devices : [],
                doorways: doorways,
                showPainted: showPainted
            )
            .frame(height: 300)
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Layer toggles

    private var layerToggles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Layers")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                layerToggle(label: "Painted coverage", systemImage: "paintbrush.fill", isOn: $showPainted, tint: .gray)
                layerToggle(label: "Signal heatmap", systemImage: "wifi", isOn: $showHeatmap, tint: cyan)
                    .accessibilityIdentifier(AccessibilityID.RoomDetail.heatmapToggle)
                layerToggle(label: "Dead zones", systemImage: "exclamationmark.triangle.fill", isOn: $showDeadZones, tint: .red)
                    .accessibilityIdentifier(AccessibilityID.RoomDetail.deadZoneToggle)
                layerToggle(label: "Devices", systemImage: "wifi.router.fill", isOn: $showDevices, tint: .purple)
                    .accessibilityIdentifier(AccessibilityID.RoomDetail.devicesToggle)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func layerToggle(label: String, systemImage: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(cyan)
        }
    }

    // MARK: - Rescan history (Pro)

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(cyan)
                Text("Scan history")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if !subs.isPro {
                    Text("PRO")
                        .font(.system(.caption2, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(cyan)
                        .foregroundStyle(.black)
                        .cornerRadius(4)
                }
            }

            if subs.isPro {
                ForEach(history) { h in
                    HStack {
                        Image(systemName: h.id == room.id ? "circle.inset.filled" : "circle")
                            .foregroundStyle(h.id == room.id ? cyan : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(h.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(Int(h.downloadMbps)) Mbps · \(h.gradeLetterRaw.isEmpty ? "—" : h.gradeLetterRaw)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Text("Upgrade to Pro to compare this room across rescans and track coverage improvements over time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        let recs = buildRecommendations()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Recommendations")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }

            if recs.isEmpty {
                Text("No issues detected in this room. Signal looks great.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recs.enumerated()), id: \.offset) { _, rec in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: rec.icon)
                            .foregroundStyle(rec.color)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            Text(rec.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private struct Recommendation {
        let title: String
        let detail: String
        let icon: String
        let color: Color
    }

    private func buildRecommendations() -> [Recommendation] {
        var recs: [Recommendation] = []

        if !deadZonePoints.isEmpty {
            recs.append(Recommendation(
                title: "Add a mesh node",
                detail: "Found \(deadZonePoints.count) dead-zone sample\(deadZonePoints.count == 1 ? "" : "s") (below -80 dBm). A mesh node near this room would restore coverage.",
                icon: "dot.radiowaves.left.and.right",
                color: .purple
            ))
        }

        if room.downloadMbps < 25 {
            recs.append(Recommendation(
                title: "Slow download speed",
                detail: "Only \(Int(room.downloadMbps)) Mbps measured. Move closer to the router or check for obstructions like thick walls.",
                icon: "speedometer",
                color: .orange
            ))
        }

        if room.pingMs > 60 {
            recs.append(Recommendation(
                title: "High latency",
                detail: "\(Int(room.pingMs)) ms ping detected. This may cause lag in video calls and games.",
                icon: "clock.fill",
                color: .yellow
            ))
        }

        if room.bleDeviceCount > 15 {
            recs.append(Recommendation(
                title: "High BLE interference",
                detail: "\(room.bleDeviceCount) Bluetooth devices nearby. Consider switching your router to 5 GHz only for this room.",
                icon: "antenna.radiowaves.left.and.right",
                color: .orange
            ))
        }

        if room.paintedCoverageFraction < 0.45 {
            recs.append(Recommendation(
                title: "Rescan for better accuracy",
                detail: "Only \(Int(room.paintedCoverageFraction * 100))% of the room was walked. Scanning more of the floor will improve the results.",
                icon: "arrow.clockwise",
                color: cyan
            ))
        }

        if devices.isEmpty {
            recs.append(Recommendation(
                title: "No devices marked here",
                detail: "Mark your router or mesh node in the next scan so we can pinpoint the source of weak spots.",
                icon: "wifi.router",
                color: .secondary
            ))
        }

        return recs
    }

    // MARK: - Helpers

    private func gradeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    private func coverageColor(_ frac: Double) -> Color {
        switch frac {
        case 0.6...: return .green
        case 0.3..<0.6: return .yellow
        default: return .orange
        }
    }
}

// MARK: - Map canvas

/// Renders the room's polygon, painted cells, heatmap points, devices, doorways
/// into a single Canvas, auto-scaled to fit.
private struct RoomMapCanvas: View {
    let room: Room
    let points: [HeatmapPoint]
    let deadZonePoints: [HeatmapPoint]
    let devices: [DevicePlacement]
    let doorways: [Doorway]
    let showPainted: Bool

    var body: some View {
        GeometryReader { proxy in
            let corners = room.corners
            let paintedCells = room.paintedCells
            let cellSize = room.paintGridResolutionMeters

            let bounds = computeBounds(
                corners: corners,
                paintedCells: paintedCells,
                cellSize: cellSize,
                points: points,
                devices: devices
            )

            let padding: CGFloat = 20
            let availableW = proxy.size.width - padding * 2
            let availableH = proxy.size.height - padding * 2
            let spanX = max(bounds.maxX - bounds.minX, 1)
            let spanZ = max(bounds.maxZ - bounds.minZ, 1)
            let scale = min(availableW / CGFloat(spanX), availableH / CGFloat(spanZ))

            let offsetX = padding + (availableW - CGFloat(spanX) * scale) / 2
            let offsetZ = padding + (availableH - CGFloat(spanZ) * scale) / 2

            let project: (Float, Float) -> CGPoint = { x, z in
                CGPoint(
                    x: offsetX + CGFloat(x - bounds.minX) * scale,
                    y: offsetZ + CGFloat(z - bounds.minZ) * scale
                )
            }

            ZStack {
                // Layer 1: room polygon fill + outline
                Canvas { ctx, _ in
                    guard corners.count >= 3 else { return }
                    var path = Path()
                    let first = project(corners[0].0, corners[0].1)
                    path.move(to: first)
                    for i in 1..<corners.count {
                        path.addLine(to: project(corners[i].0, corners[i].1))
                    }
                    path.closeSubpath()
                    ctx.fill(path, with: .color(Color.white.opacity(0.04)))
                    ctx.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1.5)
                }

                // Layer 2: painted cells
                if showPainted {
                    Canvas { ctx, _ in
                        let cellPx = CGFloat(cellSize) * scale
                        for (gx, gz) in paintedCells {
                            let wx = Float(gx) * cellSize
                            let wz = Float(gz) * cellSize
                            let origin = project(wx, wz)
                            let rect = CGRect(x: origin.x, y: origin.y, width: cellPx, height: cellPx)
                            ctx.fill(Path(rect), with: .color(Color.gray.opacity(0.22)))
                        }
                    }
                }

                // Layer 3: heatmap points
                Canvas { ctx, _ in
                    for p in points {
                        let c = project(p.x, p.z)
                        let color = signalColor(p.signalStrength).opacity(0.55)
                        let rect = CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }

                // Layer 4: dead zone markers (on top)
                Canvas { ctx, _ in
                    for p in deadZonePoints {
                        let c = project(p.x, p.z)
                        let rect = CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.red))
                        ctx.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1)
                    }
                }

                // Layer 5: doorways
                ForEach(doorways) { d in
                    let p = project(d.x, d.z)
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.orange)
                        .position(p)
                }

                // Layer 6: devices (icons — on top)
                ForEach(devices) { dev in
                    let p = project(dev.x, dev.z)
                    ZStack {
                        Circle()
                            .fill(dev.deviceType.color)
                            .frame(width: 24, height: 24)
                        Image(systemName: dev.deviceType.systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .position(p)
                }
            }
        }
    }

    private struct Bounds {
        var minX: Float
        var maxX: Float
        var minZ: Float
        var maxZ: Float
    }

    private func computeBounds(
        corners: [(Float, Float)],
        paintedCells: [(Int, Int)],
        cellSize: Float,
        points: [HeatmapPoint],
        devices: [DevicePlacement]
    ) -> Bounds {
        var xs: [Float] = corners.map { $0.0 }
        var zs: [Float] = corners.map { $0.1 }
        for (gx, gz) in paintedCells {
            xs.append(Float(gx) * cellSize)
            xs.append(Float(gx + 1) * cellSize)
            zs.append(Float(gz) * cellSize)
            zs.append(Float(gz + 1) * cellSize)
        }
        for p in points { xs.append(p.x); zs.append(p.z) }
        for d in devices { xs.append(d.x); zs.append(d.z) }

        if xs.isEmpty { xs = [0, 1] }
        if zs.isEmpty { zs = [0, 1] }

        // Add a little margin
        let margin: Float = 0.5
        return Bounds(
            minX: (xs.min() ?? 0) - margin,
            maxX: (xs.max() ?? 1) + margin,
            minZ: (zs.min() ?? 0) - margin,
            maxZ: (zs.max() ?? 1) + margin
        )
    }

    private func signalColor(_ dBm: Int) -> Color {
        switch dBm {
        case -50...0:    return .green
        case -60..<(-50): return .mint
        case -70..<(-60): return .yellow
        case -80..<(-70): return .orange
        default:          return .red
        }
    }
}

#Preview {
    NavigationStack {
        RoomDetailView(room: Room(homeId: UUID(), roomTypeRaw: RoomType.livingRoom.rawValue,
                                  downloadMbps: 120, uploadMbps: 24, pingMs: 22,
                                  gradeScore: 82, gradeLetterRaw: "B"))
    }
    .modelContainer(for: [Room.self, HeatmapPoint.self, DevicePlacement.self, Doorway.self], inMemory: true)
}
