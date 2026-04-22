import SwiftUI
import SwiftData

/// Detailed view of a single scanned room. Shows the room's polygon, painted
/// coverage, a signal heatmap from captured HeatmapPoints, device placements,
/// aggregate stats, experience tiers, technical details, and recommendations.
struct RoomDetailView: View {
    let room: Room

    @Environment(\.modelContext) private var modelContext
    @Query private var allPoints: [HeatmapPoint]
    @Query private var allDevices: [DevicePlacement]
    @Query private var allDoorways: [Doorway]
    @Query(sort: \Room.createdAt, order: .reverse) private var allRooms: [Room]
    @Query private var homes: [HomeConfiguration]

    @State private var subs = SubscriptionManager.shared
    private var history: [Room] {
        RescanHistory.history(forSlotMatching: room, in: allRooms.filter { $0.homeId == room.homeId })
    }

    @State private var showHeatmap: Bool = true
    @State private var showWeakSpots: Bool = true
    @State private var showPainted: Bool = true
    @State private var showDevices: Bool = true
    @State private var showTechnicalDetails: Bool = (UserDefaults.standard.string(forKey: "displayMode") ?? DisplayMode.basic.rawValue) == DisplayMode.technical.rawValue

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
    /// Live weak spot detection — uses the same service that computes the stored
    /// weakSpotCount so the map overlays match the metrics.
    private var liveWeakSpots: [WeakSpot] {
        CoveragePlanningService.detectWeakSpots(points: points)
    }

    private var weakSpotPoints: [HeatmapPoint] {
        // Absolute threshold matching CoveragePlanningService.weakSpotModerateThreshold (-80 dBm).
        // Below -80 dBm, moderate performance criteria (streaming, video calls) cannot be met.
        return points.filter { $0.signalStrength < -80 }
    }

    private var houseSignalRange: SignalRange {
        let homePoints = allPoints.filter { $0.homeId == room.homeId }
        return WholeHouseAnalysisService.computeSignalRange(points: homePoints)
    }

    /// Distinct BSSIDs seen during the scan — for mesh handoff detection.
    /// NOTE: HeatmapPoint doesn't yet have a bssid property; stub returns empty.
    private var distinctBSSIDs: [String] {
        []
    }

    /// Number of mesh handoffs (AP switches) detected during the walk.
    private var meshHandoffCount: Int {
        0
    }

    /// Signal stats for technical view.
    private var signalStats: (min: Int, max: Int, avg: Int, median: Int) {
        let strengths = points.map(\.signalStrength).sorted()
        guard !strengths.isEmpty else { return (0, 0, 0, 0) }
        let avg = strengths.reduce(0, +) / strengths.count
        let median = strengths[strengths.count / 2]
        return (strengths.first!, strengths.last!, avg, median)
    }

    /// Home config for this room's home (ISP speeds, etc.)
    private var homeConfig: HomeConfiguration? {
        homes.first { $0.id == room.homeId }
    }

    /// Benchmark download speed: home average across all scanned rooms.
    private var downloadBenchmark: Double? {
        let siblings = allRooms.filter { $0.homeId == room.homeId && $0.downloadMbps > 0 }
        guard siblings.count > 1 else { return nil }
        return siblings.map(\.downloadMbps).reduce(0, +) / Double(siblings.count)
    }

    /// Benchmark upload speed: home average across all scanned rooms.
    private var uploadBenchmark: Double? {
        let siblings = allRooms.filter { $0.homeId == room.homeId && $0.uploadMbps > 0 }
        guard siblings.count > 1 else { return nil }
        return siblings.map(\.uploadMbps).reduce(0, +) / Double(siblings.count)
    }

    /// Benchmark source label.
    private var benchmarkSource: String {
        "home avg"
    }

    // MARK: - Body

    @State private var showScrollHint = true

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    gradeCard
                    experienceTierCard
                    metricsGrid
                    mapCard

                    // Scroll hint — nudges user to discover recommendations below
                    if showScrollHint {
                        VStack(spacing: 4) {
                            Text("More below")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.compact.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(cyan.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation { showScrollHint = false }
                            }
                        }
                    }

                    layerToggles

                    technicalDetailsToggle

                    if showTechnicalDetails {
                        technicalDetailsCard
                    }

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
        default:  return "Significant weak spots. Consider repositioning your router or adding a mesh node."
        }
    }

    // MARK: - Experience tier card

    /// Shows what activities are supported at the measured speed/signal,
    /// so non-technical users immediately understand what the numbers mean.
    private var experienceTierCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(cyan)
                Text("What works here")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }

            let tiers = experienceTiers()
            ForEach(tiers, id: \.label) { tier in
                HStack(spacing: 10) {
                    Image(systemName: tier.supported ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(tier.supported ? .green : .red.opacity(0.7))
                        .frame(width: 20)
                    Text(tier.label)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(tier.supported ? .white : .secondary)
                    Spacer()
                    if tier.supported {
                        Text(tier.quality)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private struct ExperienceTier {
        let label: String
        let supported: Bool
        let quality: String
    }

    private func experienceTiers() -> [ExperienceTier] {
        let dl = room.downloadMbps
        let ping = room.pingMs
        let hasWeakSpots = room.deadZoneCount > 0

        return [
            ExperienceTier(
                label: "Web browsing & email",
                supported: dl >= 1,
                quality: dl >= 25 ? "Fast" : "Usable"
            ),
            ExperienceTier(
                label: "Video calls (Zoom, Teams)",
                supported: dl >= 5 && ping < 150,
                quality: dl >= 25 && ping < 50 ? "Excellent" : (dl >= 10 ? "Good" : "Basic")
            ),
            ExperienceTier(
                label: "HD streaming (Netflix, YouTube)",
                supported: dl >= 5,
                quality: dl >= 25 ? "Smooth" : "May buffer"
            ),
            ExperienceTier(
                label: "4K streaming",
                supported: dl >= 25,
                quality: dl >= 50 ? "Smooth" : "Possible buffering"
            ),
            ExperienceTier(
                label: "Online gaming",
                supported: dl >= 10 && ping < 80,
                quality: ping < 30 ? "Low latency" : (ping < 60 ? "Playable" : "Some lag")
            ),
            ExperienceTier(
                label: "Large file downloads",
                supported: dl >= 25,
                quality: dl >= 200 ? "Very fast" : (dl >= 100 ? "Fast" : "Moderate")
            ),
            ExperienceTier(
                label: "Reliable whole-room coverage",
                supported: !hasWeakSpots,
                quality: hasWeakSpots ? "" : "No weak spots"
            ),
        ]
    }

    // MARK: - Metric grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let bench = downloadBenchmark {
                    metricTile(label: "Download", value: "\(Int(room.downloadMbps)) / \(Int(bench))", unit: "Mbps", color: .green, subtitle: benchmarkSource)
                } else {
                    metricTile(label: "Download", value: "\(Int(room.downloadMbps))", unit: "Mbps", color: .green)
                }
                if let bench = uploadBenchmark {
                    metricTile(label: "Upload", value: "\(Int(room.uploadMbps)) / \(Int(bench))", unit: "Mbps", color: cyan, subtitle: benchmarkSource)
                } else {
                    metricTile(label: "Upload", value: "\(Int(room.uploadMbps))", unit: "Mbps", color: cyan)
                }
            }
            HStack(spacing: 12) {
                metricTile(label: "Ping", value: "\(Int(room.pingMs))", unit: "ms", color: .yellow)
                metricTile(label: "Coverage",
                           value: "\(Int(room.paintedCoverageFraction * 100))",
                           unit: "% walked",
                           color: coverageColor(room.paintedCoverageFraction))
            }
            HStack(spacing: 12) {
                metricTile(label: "Weak spots",
                           value: "\(liveWeakSpots.count)",
                           unit: liveWeakSpots.count == 1 ? "area" : "areas",
                           color: liveWeakSpots.isEmpty ? .green : .red)
                metricTile(label: "Wireless devices",
                           value: "\(room.bleDeviceCount)",
                           unit: "nearby",
                           color: room.bleDeviceCount > 12 ? .orange : .secondary)
            }
            // Mesh handoff row — only show if we have BSSID data
            if distinctBSSIDs.count > 1 {
                HStack(spacing: 12) {
                    metricTile(label: "Access points",
                               value: "\(distinctBSSIDs.count)",
                               unit: "mesh nodes",
                               color: cyan)
                    metricTile(label: "AP switches",
                               value: "\(meshHandoffCount)",
                               unit: "handoffs",
                               color: meshHandoffCount > 3 ? .orange : .secondary)
                }
            }
        }
    }

    private func metricTile(label: String, value: String, unit: String, color: Color, subtitle: String? = nil) -> some View {
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
            if let subtitle {
                Text("vs \(subtitle)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.7))
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
                weakSpotPoints: showWeakSpots ? weakSpotPoints : [],
                weakSpots: showWeakSpots ? liveWeakSpots : [],
                devices: showDevices ? devices : [],
                doorways: doorways,
                showPainted: showPainted,
                signalRange: houseSignalRange
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
                layerToggle(label: "Weak spots", systemImage: "exclamationmark.triangle.fill", isOn: $showWeakSpots, tint: .orange)
                    .accessibilityIdentifier(AccessibilityID.RoomDetail.weakSpotToggle)
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

    // MARK: - Technical details toggle (per-room)

    private var technicalDetailsToggle: some View {
        HStack(spacing: 10) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text("Technical Details")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $showTechnicalDetails.animation(.easeInOut(duration: 0.25)))
                .tint(cyan)
                .labelsHidden()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Technical details card (shown when per-room toggle is on)

    private var technicalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundStyle(cyan)
                Text("Technical details")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Signal distribution
            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Signal distribution")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    let stats = signalStats
                    HStack(spacing: 16) {
                        techStat(label: "Min", value: "\(stats.min) dBm")
                        techStat(label: "Max", value: "\(stats.max) dBm")
                        techStat(label: "Avg", value: "\(stats.avg) dBm")
                        techStat(label: "Median", value: "\(stats.median) dBm")
                    }

                    // Signal histogram — 5-band breakdown
                    signalHistogram
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }

            // BSSID / mesh tracking
            if !distinctBSSIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Access point tracking")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    ForEach(distinctBSSIDs, id: \.self) { bssid in
                        let count = points.count  // TODO: filter by bssid once HeatmapPoint gains the property
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.router")
                                .font(.caption)
                                .foregroundStyle(cyan)
                            Text(bssid)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(count) samples")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if meshHandoffCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("\(meshHandoffCount) mesh handoff\(meshHandoffCount == 1 ? "" : "s") detected during walk")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }

            // BLE device breakdown
            if room.bleDeviceCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wireless interference")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
                        techStat(label: "Devices", value: "\(room.bleDeviceCount)")
                        techStat(label: "Congestion",
                                 value: room.bleDeviceCount > 30 ? "Severe" :
                                        room.bleDeviceCount > 12 ? "High" :
                                        room.bleDeviceCount > 8  ? "Medium" : "Low")
                    }

                    Text("Nearby Bluetooth/wireless devices can cause 2.4 GHz interference. If congestion is high, switch your router to 5 GHz.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }

            // Raw scan metadata
            VStack(alignment: .leading, spacing: 6) {
                Text("Scan metadata")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    techStat(label: "Samples", value: "\(points.count)")
                    techStat(label: "Coverage", value: "\(Int(room.paintedCoverageFraction * 100))%")
                    techStat(label: "Grid res", value: String(format: "%.1fm", room.paintGridResolutionMeters))
                }

                if let speedAt = room.speedTestAt {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Speed test: \(speedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Signal values are estimated dBm derived from NEHotspotNetwork (0.0-1.0 mapped via -100 + strength * 70). They are approximate, not raw RSSI.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.top, 2)
            }
            .padding(10)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var signalHistogram: some View {
        let strengths = points.map(\.signalStrength)
        let total = max(strengths.count, 1)
        let bands: [(label: String, color: Color, count: Int)] = [
            ("Excellent", .green,  strengths.filter { $0 >= -55 }.count),
            ("Good",      cyan,    strengths.filter { $0 >= -65 && $0 < -55 }.count),
            ("Fair",      .yellow, strengths.filter { $0 >= -75 && $0 < -65 }.count),
            ("Weak",      .orange, strengths.filter { $0 >= -85 && $0 < -75 }.count),
            ("Poor",      .red,    strengths.filter { $0 < -85 }.count),
        ]

        VStack(spacing: 4) {
            ForEach(bands, id: \.label) { band in
                HStack(spacing: 6) {
                    Text(band.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    GeometryReader { geo in
                        let fraction = CGFloat(band.count) / CGFloat(total)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(band.color.opacity(0.7))
                            .frame(width: max(fraction * geo.size.width, band.count > 0 ? 4 : 0))
                    }
                    .frame(height: 10)
                    Text("\(band.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
            }
        }
    }

    private func techStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
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
        let dzCount = liveWeakSpots.count

        // Weak spots detected
        if dzCount > 0 {
            let hasCritical = liveWeakSpots.contains { $0.severity == .critical }
            recs.append(Recommendation(
                title: "Weak spot\(dzCount == 1 ? "" : "s") detected",
                detail: "Found \(dzCount) \(hasCritical ? "severe " : "")weak spot\(dzCount == 1 ? "" : "s") where signal drops significantly. Consider adding a mesh node, moving your router, or removing obstructions like thick walls or large metal objects.",
                icon: "exclamationmark.triangle.fill",
                color: hasCritical ? .red : .yellow
            ))
        }

        // Devices in or near weak spots
        let devicesInWeakSpots = devicesNearWeakSpots()
        if !devicesInWeakSpots.isEmpty {
            let names = devicesInWeakSpots.map(\.displayLabel).joined(separator: ", ")
            recs.append(Recommendation(
                title: "Device\(devicesInWeakSpots.count == 1 ? "" : "s") in a weak spot",
                detail: "\(names) \(devicesInWeakSpots.count == 1 ? "is" : "are") in or near a weak spot. Move \(devicesInWeakSpots.count == 1 ? "it" : "them") to an area with better signal, adjust your router placement, or add a mesh node nearby.",
                icon: "exclamationmark.circle.fill",
                color: .red
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
            let latencyTip: String
            if room.pingMs > 100 {
                latencyTip = "Try connecting via ethernet for gaming or video calls, or move closer to the router. Check if other devices are using heavy bandwidth (streaming, downloads)."
            } else {
                latencyTip = "Close bandwidth-heavy apps on other devices, switch to 5 GHz if on 2.4 GHz, or use a wired connection for latency-sensitive tasks like gaming or video calls."
            }
            recs.append(Recommendation(
                title: "High latency",
                detail: "\(Int(room.pingMs)) ms ping detected. \(latencyTip)",
                icon: "clock.fill",
                color: .yellow
            ))
        }

        if meshHandoffCount > 3 {
            recs.append(Recommendation(
                title: "Frequent mesh handoffs",
                detail: "Your device switched access points \(meshHandoffCount) times during the walk. This can cause brief connection drops. Check that your mesh nodes have consistent firmware and strong backhaul.",
                icon: "arrow.triangle.swap",
                color: .orange
            ))
        }

        if room.bleDeviceCount > 12 {
            recs.append(Recommendation(
                title: "Wireless congestion",
                detail: "\(room.bleDeviceCount) wireless devices detected nearby. Consider switching your router to 5 GHz for this room to avoid 2.4 GHz interference.",
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
                title: "No devices marked",
                detail: "Place your router, mesh nodes, TV, computer, or other devices on the map during your next scan to see if any are sitting in a weak spot.",
                icon: "wifi.router",
                color: .secondary
            ))
        }

        // Final "rescan after changes" recommendation when there are actionable issues
        if !recs.isEmpty && room.paintedCoverageFraction >= 0.45 {
            recs.append(Recommendation(
                title: "Rescan after making changes",
                detail: "After adjusting your setup based on the suggestions above, scan this room again to get an updated score and confirm the improvements.",
                icon: "arrow.clockwise.circle.fill",
                color: cyan
            ))
        }

        return recs
    }

    /// Find placed devices that are inside or within 1.5 m of a weak spot.
    private func devicesNearWeakSpots() -> [DevicePlacement] {
        guard !liveWeakSpots.isEmpty else { return [] }
        let proximityMargin: Double = 1.5 // meters beyond the weak spot radius
        return devices.filter { dev in
            // Skip routers/mesh — we don't tell users to move their router OUT of a weak spot
            // (it might be there on purpose). Focus on consumer devices.
            guard dev.deviceType != .router && dev.deviceType != .meshNode else { return false }
            return liveWeakSpots.contains { zone in
                let deltaX = dev.x - zone.centerX
                let deltaZ = dev.z - zone.centerZ
                let dist = sqrt(deltaX * deltaX + deltaZ * deltaZ)
                return dist <= zone.radius + proximityMargin
            }
        }
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

/// Renders the room's polygon, painted cells, IDW signal heatmap, clustered
/// weak spot overlays, devices, and doorways into a single Canvas, auto-scaled to fit.
struct RoomMapCanvas: View {
    let room: Room
    let points: [HeatmapPoint]
    let weakSpotPoints: [HeatmapPoint]
    let weakSpots: [WeakSpot]
    let devices: [DevicePlacement]
    let doorways: [Doorway]
    let showPainted: Bool
    var signalRange: SignalRange? = nil

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

            let project: (Double, Double) -> CGPoint = { x, z in
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
                            let wx = Double(gx) * cellSize
                            let wz = Double(gz) * cellSize
                            let origin = project(wx, wz)
                            let rect = CGRect(x: origin.x, y: origin.y, width: cellPx, height: cellPx)
                            ctx.fill(Path(rect), with: .color(Color.gray.opacity(0.22)))
                        }
                    }
                }

                // Layer 3: IDW area-based signal heatmap
                if points.count >= 3, let range = signalRange {
                    Canvas { ctx, size in
                        drawIDWHeatmap(
                            context: ctx, size: size,
                            points: points, project: project,
                            bounds: bounds, scale: scale,
                            signalRange: range
                        )
                    }
                }

                // Layer 3b: small sample dots on top of heatmap for reference
                Canvas { ctx, _ in
                    let dotBlue = Color(red: 0.45, green: 0.68, blue: 1.0)
                    for p in points {
                        let c = project(p.x, p.z)
                        let dot = CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)
                        ctx.fill(Path(ellipseIn: dot), with: .color(dotBlue.opacity(0.5)))
                    }
                }

                // Layer 4: weak spot overlays from CoveragePlanningService
                Canvas { ctx, _ in
                    for dz in weakSpots {
                        drawWeakSpotOverlay(ctx: ctx, weakSpot: dz, project: project, scale: scale)
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

    // MARK: - IDW heatmap

    /// Compute projected weak spot centers and radii for heatmap gap masking.
    private func weakSpotRegions(project: (Double, Double) -> CGPoint, scale: CGFloat) -> [(center: CGPoint, radius: CGFloat)] {
        return weakSpots.map { dz in
            let center = project(dz.centerX, dz.centerZ)
            let radiusPx = CGFloat(dz.radius) * scale
            return (center, radiusPx)
        }
    }

    private func drawIDWHeatmap(
        context ctx: GraphicsContext,
        size: CGSize,
        points: [HeatmapPoint],
        project: (Double, Double) -> CGPoint,
        bounds: Bounds,
        scale: CGFloat,
        signalRange: SignalRange
    ) {
        let cellPx: CGFloat = 8
        let cols = Int(ceil(size.width / cellPx))
        let rows = Int(ceil(size.height / cellPx))
        guard cols > 0, rows > 0 else { return }

        // Pre-compute projected positions
        let viewPoints = points.map { pt -> (pos: CGPoint, signal: Double) in
            let pos = project(pt.x, pt.z)
            return (pos, Double(pt.signalStrength))
        }

        // Pre-compute weak spot regions so we can leave gaps in the heatmap
        let dzRegions = weakSpotRegions(project: project, scale: scale)

        let power: Double = 2.5
        let maxRadius: CGFloat = 80

        // Use whole-house relative signal range for green→orange coloring
        let range = signalRange

        for row in 0..<rows {
            for col in 0..<cols {
                let cx = CGFloat(col) * cellPx + cellPx / 2
                let cy = CGFloat(row) * cellPx + cellPx / 2

                // Skip cells that fall inside a weak spot region (leave gaps)
                let inWeakSpot = dzRegions.contains { region in
                    let dx = cx - region.center.x
                    let dy = cy - region.center.y
                    return sqrt(dx * dx + dy * dy) < region.radius
                }
                if inWeakSpot { continue }

                var weightedSignal: Double = 0
                var totalWeight: Double = 0

                for vp in viewPoints {
                    let dx = cx - vp.pos.x
                    let dy = cy - vp.pos.y
                    let dist = sqrt(dx * dx + dy * dy)
                    guard dist < maxRadius else { continue }

                    if dist < 1 {
                        weightedSignal = vp.signal
                        totalWeight = 1
                        break
                    }

                    let w = 1.0 / pow(Double(dist), power)
                    weightedSignal += vp.signal * w
                    totalWeight += w
                }

                guard totalWeight > 0 else { continue }

                let interpolated = weightedSignal / totalWeight
                let dBm = Int(interpolated)

                // Skip weak-spot-level signals (they have their own overlay)
                guard dBm >= -80 else { continue }

                // Green→orange relative color from whole-house range
                let cellColor = SignalRange.relativeColor(for: dBm, range: range)

                // Opacity: stronger signal = more opaque
                let normalised = min(1.0, max(0.0, (interpolated + 90) / 50))
                let opacity = 0.20 + normalised * 0.45

                let rect = CGRect(x: CGFloat(col) * cellPx, y: CGFloat(row) * cellPx, width: cellPx, height: cellPx)
                ctx.fill(Path(rect), with: .color(cellColor.opacity(opacity)))
            }
        }
    }

    // MARK: - Weak spot rendering

    /// Draw a weak spot overlay using the service-computed WeakSpot model.
    /// Yellow for severe (warning), red for critical.
    private func drawWeakSpotOverlay(
        ctx: GraphicsContext,
        weakSpot dz: WeakSpot,
        project: (Double, Double) -> CGPoint,
        scale: CGFloat
    ) {
        let center = project(dz.centerX, dz.centerZ)
        let radiusPx = max(CGFloat(dz.radius) * scale, 12)

        let isCritical = dz.severity == .critical
        let zoneColor: Color = isCritical ? .red : .yellow

        let rect = CGRect(
            x: center.x - radiusPx,
            y: center.y - radiusPx,
            width: radiusPx * 2,
            height: radiusPx * 2
        )
        ctx.fill(Path(ellipseIn: rect), with: .color(zoneColor.opacity(isCritical ? 0.25 : 0.20)))
        ctx.stroke(
            Path(ellipseIn: rect),
            with: .color(zoneColor.opacity(0.7)),
            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
        )

        // Warning icon at center
        let iconSize: CGFloat = 16
        let icon = Text("⚠")
            .font(.system(size: iconSize))
        ctx.draw(ctx.resolve(icon), at: center)
    }

    // MARK: - Helpers

    private struct Bounds {
        var minX: Double
        var maxX: Double
        var minZ: Double
        var maxZ: Double
    }

    private func computeBounds(
        corners: [(Double, Double)],
        paintedCells: [(Int, Int)],
        cellSize: Double,
        points: [HeatmapPoint],
        devices: [DevicePlacement]
    ) -> Bounds {
        var xs: [Double] = corners.map { $0.0 }
        var zs: [Double] = corners.map { $0.1 }
        for (gx, gz) in paintedCells {
            xs.append(Double(gx) * cellSize)
            xs.append(Double(gx + 1) * cellSize)
            zs.append(Double(gz) * cellSize)
            zs.append(Double(gz + 1) * cellSize)
        }
        for p in points { xs.append(p.x); zs.append(p.z) }
        for d in devices { xs.append(d.x); zs.append(d.z) }

        if xs.isEmpty { xs = [0, 1] }
        if zs.isEmpty { zs = [0, 1] }

        let margin: Double = 0.5
        return Bounds(
            minX: (xs.min() ?? 0) - margin,
            maxX: (xs.max() ?? 1) + margin,
            minZ: (zs.min() ?? 0) - margin,
            maxZ: (zs.max() ?? 1) + margin
        )
    }

    // signalColor removed — heatmap now uses uniform faint light blue
}

#Preview {
    NavigationStack {
        RoomDetailView(room: Room(homeId: UUID(), roomTypeRaw: RoomType.livingRoom.rawValue,
                                  downloadMbps: 120, uploadMbps: 24, pingMs: 22,
                                  gradeScore: 82, gradeLetterRaw: "B"))
    }
    .modelContainer(for: [Room.self, HeatmapPoint.self, DevicePlacement.self, Doorway.self, HomeConfiguration.self], inMemory: true)
}
