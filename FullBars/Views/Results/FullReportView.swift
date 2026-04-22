import SwiftUI
import SwiftData
import UIKit

/// Full Report — generates a comprehensive PDF showing overall scoring and
/// detailed per-room breakdowns with floorplan maps. Shared alongside the
/// badge image to encourage FullBars usage.
struct FullReportView: View {
    let home: HomeConfiguration
    let rooms: [Room]
    let allPoints: [HeatmapPoint]
    let allDevices: [DevicePlacement]
    let allDoorways: [Doorway]

    @Environment(\.dismiss) private var dismiss
    @State private var isShareSheetPresented = false
    @State private var shareItems: [Any] = []
    @State private var isGenerating = false

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    // MARK: - Derived

    private var overallScore: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.gradeScore } / Double(rooms.count)
    }
    private var overallLetter: String {
        switch overallScore {
        case 90...:   return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default:      return "F"
        }
    }
    private var avgDownload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.downloadMbps } / Double(rooms.count)
    }
    private var avgUpload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.uploadMbps } / Double(rooms.count)
    }
    private var avgPing: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.pingMs } / Double(rooms.count)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Full Report")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        Text("Comprehensive Wi-Fi analysis of your home — overall scoring and detailed per-room breakdowns with floorplans.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        // Preview of what the PDF will contain
                        reportPreview

                        Button {
                            generateAndShare()
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "doc.richtext.fill")
                                }
                                Text(isGenerating ? "Generating..." : "Generate & Share PDF")
                            }
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(cyan)
                            .foregroundStyle(.black)
                            .cornerRadius(14)
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Full Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(cyan)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $isShareSheetPresented) {
                ImageShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Preview

    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall grade summary
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: CGFloat(overallScore / 100))
                        .stroke(gradeColor(overallLetter),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    Text(overallLetter)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor(overallLetter))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall: \(Int(overallScore))/100")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(rooms.count) rooms · \(Int(avgDownload)) Mbps avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.1))

            Text("Report includes:")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                reportIncludesRow(icon: "chart.bar.fill", text: "Overall home grade & speed summary")
                reportIncludesRow(icon: "list.bullet", text: "Per-room grades, speeds, and metrics")
                reportIncludesRow(icon: "checkmark.seal.fill", text: "Experience tier checklist per room")
                reportIncludesRow(icon: "map.fill", text: "Floorplan heatmap for each room")
                reportIncludesRow(icon: "exclamationmark.triangle.fill", text: "Weak spot analysis & recommendations")
                reportIncludesRow(icon: "qrcode", text: "Shareable badge included")
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }

    private func reportIncludesRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(cyan)
                .frame(width: 16)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - PDF Generation

    private func generateAndShare() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Build the PDF content view (multiple pages rendered as one tall image)
            let pdfContent = FullReportPDFContent(
                home: home,
                rooms: rooms,
                allPoints: allPoints,
                allDevices: allDevices,
                allDoorways: allDoorways
            )

            let renderer = ImageRenderer(content:
                pdfContent
                    .frame(width: 612) // US Letter width in points
                    .background(Color(red: 0.08, green: 0.08, blue: 0.13))
            )
            renderer.scale = 2.0

            let pdfURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("FullBars_Report_\(home.name.replacingOccurrences(of: " ", with: "_")).pdf")

            renderer.render { size, renderInContext in
                var mediaBox = CGRect(origin: .zero, size: size)
                guard let context = CGContext(pdfURL as CFURL, mediaBox: &mediaBox, nil) else { return }
                context.beginPDFPage(nil)
                renderInContext(context)
                context.endPDFPage()
                context.closePDF()
            }

            // Also render the badge image
            let badgeImage = renderBadgeImage()

            DispatchQueue.main.async {
                isGenerating = false
                var items: [Any] = [pdfURL]
                if let badge = badgeImage {
                    items.append(badge)
                }
                shareItems = items
                isShareSheetPresented = true
            }
        }
    }

    private func renderBadgeImage() -> UIImage? {
        let badgeView = ShareBadgeCard(home: home, rooms: rooms)
            .frame(width: 340)
            .padding(20)
            .background(bg)
        let renderer = ImageRenderer(content: badgeView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private func gradeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }
}

// MARK: - Badge Card (extracted for rendering)

/// Standalone badge card view — reusable for rendering alongside the report.
struct ShareBadgeCard: View {
    let home: HomeConfiguration
    let rooms: [Room]

    private let cyan = FullBars.Design.Colors.accentCyan

    private var overallScore: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.gradeScore } / Double(rooms.count)
    }
    private var overallLetter: String {
        switch overallScore {
        case 90...:   return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default:      return "F"
        }
    }
    private var avgDownload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.downloadMbps } / Double(rooms.count)
    }
    private var avgUpload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.uploadMbps } / Double(rooms.count)
    }
    private var avgPing: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.pingMs } / Double(rooms.count)
    }

    private func gradeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wifi")
                    .font(.headline)
                    .foregroundStyle(.black)
                Text("Verified Wi-Fi")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("FULLBARS")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(cyan)

            VStack(spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: CGFloat(overallScore / 100))
                            .stroke(gradeColor(overallLetter),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        Text(overallLetter)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(gradeColor(overallLetter))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(home.name)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(rooms.count) rooms · \(Int(overallScore))/100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    statCol(value: "\(Int(avgDownload))", unit: "Mbps ↓", color: .green)
                    statCol(value: "\(Int(avgUpload))", unit: "Mbps ↑", color: .blue)
                    statCol(value: "\(Int(avgPing))", unit: "ms ping", color: .yellow)
                }
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.08, blue: 0.13))
        }
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func statCol(value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PDF Content Layout

/// The actual content rendered into the PDF. Laid out at 612pt width (US Letter)
/// as a single tall view.
private struct FullReportPDFContent: View {
    let home: HomeConfiguration
    let rooms: [Room]
    let allPoints: [HeatmapPoint]
    let allDevices: [DevicePlacement]
    let allDoorways: [Doorway]

    private let cyan = FullBars.Design.Colors.accentCyan

    private var overallScore: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.gradeScore } / Double(rooms.count)
    }
    private var overallLetter: String {
        switch overallScore {
        case 90...:   return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default:      return "F"
        }
    }
    private var avgDownload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.downloadMbps } / Double(rooms.count)
    }
    private var avgUpload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.uploadMbps } / Double(rooms.count)
    }
    private var avgPing: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.pingMs } / Double(rooms.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundStyle(.black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FullBars Wi-Fi Report")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.black)
                    Text(home.name)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.black.opacity(0.7))
                }
                Spacer()
                Text(formattedDate())
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(24)
            .background(cyan)

            VStack(alignment: .leading, spacing: 28) {
                // Overall Summary
                overallSummary
                    .padding(.top, 4)

                Divider().background(Color.white.opacity(0.15))

                // Per-room details
                ForEach(rooms) { room in
                    roomSection(room)

                    if room.id != rooms.last?.id {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }

                // Footer
                HStack {
                    Spacer()
                    Text("Generated by FullBars · fullbars.app")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(28)
        }
    }

    // MARK: - Overall Summary

    private var overallSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Summary")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: CGFloat(overallScore / 100))
                        .stroke(gradeColor(overallLetter),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Text(overallLetter)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(gradeColor(overallLetter))
                        Text("\(Int(overallScore))/100")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    pdfStat(label: "Avg Download", value: "\(Int(avgDownload)) Mbps", color: .green)
                    pdfStat(label: "Avg Upload", value: "\(Int(avgUpload)) Mbps", color: .blue)
                    pdfStat(label: "Avg Ping", value: "\(Int(avgPing)) ms", color: .yellow)
                    pdfStat(label: "Rooms Scanned", value: "\(rooms.count)", color: .white)
                }
                Spacer()
            }

            if !home.ispName.isEmpty {
                HStack(spacing: 6) {
                    Text("Provider:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(home.ispName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Per-room section

    private func roomSection(_ room: Room) -> some View {
        let roomPoints = allPoints.filter { $0.roomId == room.id }
        let roomDevices = allDevices.filter { $0.roomId == room.id }
        let roomDoorways = allDoorways.filter { $0.roomId == room.id }

        return VStack(alignment: .leading, spacing: 14) {
            // Room header
            HStack(spacing: 10) {
                Image(systemName: room.roomType.systemImage)
                    .foregroundStyle(cyan)
                    .frame(width: 28, height: 28)
                    .background(cyan.opacity(0.15))
                    .cornerRadius(6)

                Text(room.displayName)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Text(room.gradeLetterRaw.isEmpty ? "—" : room.gradeLetterRaw)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(gradeColor(room.gradeLetterRaw))
                    .frame(width: 36, height: 36)
                    .background(gradeColor(room.gradeLetterRaw).opacity(0.15))
                    .clipShape(Circle())
            }

            // Metrics grid
            HStack(spacing: 10) {
                miniMetric(label: "Download", value: "\(Int(room.downloadMbps))", unit: "Mbps", color: .green)
                miniMetric(label: "Upload", value: "\(Int(room.uploadMbps))", unit: "Mbps", color: .blue)








                miniMetric(label: "Ping", value: "\(Int(room.pingMs))", unit: "ms", color: .yellow)
                miniMetric(label: "Weak Spots", value: "\(room.deadZoneCount)", unit: "", color: room.deadZoneCount == 0 ? .green : .red)
            }

            // Experience tiers
            experienceTierSection(room)

            // Floorplan map (if we have points)
            if roomPoints.count >= 3 {
                Text("Signal Coverage Map")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                RoomMapCanvas(
                    room: room,
                    points: roomPoints,
                    weakSpotPoints: weakSpotPointsFor(room: room, points: roomPoints),
                    weakSpots: CoveragePlanningService.detectWeakSpots(points: roomPoints),
                    devices: roomDevices,
                    doorways: roomDoorways,
                    showPainted: true
                )
                .frame(height: 200)
                .background(Color.black.opacity(0.25))
                .cornerRadius(10)
            }

            // Recommendations
            let recs = buildRecommendations(room)
            if !recs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(recs, id: \.title) { rec in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: rec.icon)
                                .font(.caption2)
                                .foregroundStyle(rec.color)
                                .frame(width: 14)
                            Text(rec.title)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            +
                            Text(" — \(rec.detail)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    private func weakSpotPointsFor(room: Room, points: [HeatmapPoint]) -> [HeatmapPoint] {
        let avg = points.isEmpty ? -70
            : points.map(\.signalStrength).reduce(0, +) / points.count
        let threshold = avg - 15
        return points.filter { $0.signalStrength < threshold }
    }

    // MARK: - Experience Tiers

    private func experienceTierSection(_ room: Room) -> some View {
        let dl = room.downloadMbps
        let ping = room.pingMs

        let tiers: [(String, Bool)] = [
            ("Web & email", dl >= 1),
            ("Video calls", dl >= 5 && ping < 150),
            ("HD streaming", dl >= 5),
            ("4K streaming", dl >= 25),
            ("Gaming", dl >= 10 && ping < 80),
            ("Large downloads", dl >= 25),
            ("No weak spots", room.deadZoneCount == 0),
        ]

        return VStack(alignment: .leading, spacing: 4) {
            Text("What works here")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            // Two-column layout
            let half = (tiers.count + 1) / 2
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<half, id: \.self) { i in
                        tierRow(tiers[i].0, supported: tiers[i].1)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(half..<tiers.count, id: \.self) { i in
                        tierRow(tiers[i].0, supported: tiers[i].1)
                    }
                }
            }
        }
    }

    private func tierRow(_ label: String, supported: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(supported ? .green : .red.opacity(0.6))
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(supported ? .white : .secondary)
        }
    }

    // MARK: - Recommendations

    private struct Rec {
        let title: String
        let detail: String
        let icon: String
        let color: Color
    }

    private func buildRecommendations(_ room: Room) -> [Rec] {
        let roomPoints = allPoints.filter { $0.roomId == room.id }
        let dzs = CoveragePlanningService.detectWeakSpots(points: roomPoints)
        var recs: [Rec] = []
        if !dzs.isEmpty {
            let hasCritical = dzs.contains { $0.severity == .critical }
            recs.append(Rec(title: "Weak spots", detail: "\(dzs.count) weak area\(dzs.count == 1 ? "" : "s"). Add a mesh node or adjust router placement.", icon: "exclamationmark.triangle.fill", color: hasCritical ? .red : .yellow))
        }
        if room.downloadMbps < 25 {
            recs.append(Rec(title: "Slow speed", detail: "Only \(Int(room.downloadMbps)) Mbps. Check obstructions.", icon: "speedometer", color: .orange))
        }
        if room.pingMs > 60 {
            recs.append(Rec(title: "High latency", detail: "\(Int(room.pingMs)) ms. May cause lag.", icon: "clock.fill", color: .yellow))
        }
        if !recs.isEmpty {
            recs.append(Rec(title: "Rescan after changes", detail: "Scan again to confirm improvements.", icon: "arrow.clockwise.circle.fill", color: .cyan))
        }
        return recs
    }

    // MARK: - Helpers

    private func pdfStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func miniMetric(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
    }

    private func gradeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: .now)
    }
}  // end FullReportPDFContent
