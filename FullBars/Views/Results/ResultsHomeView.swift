import SwiftUI
import SwiftData

/// The new Results tab — shows overall house grade and a colour-coded room list.
/// Tapping a room drills into a detail view (Pass 5 will flesh this out).
struct ResultsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [HomeConfiguration]
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]
    @Query private var allPoints: [HeatmapPoint]
    @Query private var allDevices: [DevicePlacement]
    @Query private var allDoorways: [Doorway]
    @Query(sort: \SpaceGrade.timestamp, order: .reverse) private var spaceGrades: [SpaceGrade]

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    @State private var presentingBadge = false
    @State private var presentingPaywall = false
    @State private var subs = SubscriptionManager.shared
    @State private var presentingFullReport = false
    @State private var presentingWiFiReportCard = false
    @State private var roomToDelete: Room?
    @State private var roomToRename: Room?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false

    private var home: HomeConfiguration? { HomeSelection.activeHome(from: homes) }
    private var homeRooms: [Room] {
        guard let home else { return [] }
        let all = rooms.filter { $0.homeId == home.id }
        return RescanHistory.visibleRooms(for: all, isPro: subs.isPro)
    }

    private var homePoints: [HeatmapPoint] {
        guard let home else { return [] }
        let homeIdVal = home.id
        return allPoints.filter { $0.homeId == homeIdVal }
    }

    private var homeDevices: [DevicePlacement] {
        guard let home else { return [] }
        let homeIdVal = home.id
        return allDevices.filter { $0.homeId == homeIdVal }
    }

    private var homeDoorways: [Doorway] {
        guard let home else { return [] }
        let roomIds = Set(homeRooms.map(\.id))
        return allDoorways.filter { roomIds.contains($0.roomId) }
    }

    private var latestGrade: SpaceGrade? {
        spaceGrades.first  // already sorted newest-first
    }

    private var wholeHouseAnalysis: WholeHouseAnalysis {
        WholeHouseAnalysisService.analyzeHouse(rooms: homeRooms, allPoints: homePoints)
    }

    /// Overall grade — average of per-room grade scores (0-100)
    private var overallScore: Double {
        guard !homeRooms.isEmpty else { return 0 }
        let sum = homeRooms.reduce(0.0) { $0 + $1.gradeScore }
        return sum / Double(homeRooms.count)
    }

    private var overallLetter: String {
        switch overallScore {
        case 90...:  return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default:      return "F"
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                if homeRooms.isEmpty {
                    emptyState.padding(.top, 80)
                } else {
                    VStack(spacing: 20) {
                        overallCard
                        shareBadgeCTA
                        fullReportButton
                        roomGrades
                        // Floor plan map
                        if homeRooms.count >= 2, let home {
                            floorMapSection(home)
                        }

                        // WiFi Report Card (shareable grade summary)
                        if latestGrade != nil {
                            wifiReportCardButton
                        }

                        if let mesh = wholeHouseAnalysis.meshRecommendation {
                            meshRecommendationCard(mesh)
                        }
                        if !wholeHouseAnalysis.recommendations.isEmpty {
                            wholeHouseRecommendationsCard
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $presentingWiFiReportCard) {
            if let grade = latestGrade {
                WiFiReportCardView(
                    grade: grade,
                    ssid: home?.ispName ?? "Unknown",
                    displayMode: DisplayMode(rawValue: UserDefaults.standard.string(forKey: "displayMode") ?? DisplayMode.basic.rawValue) ?? .basic
                )
            }
        }
        .sheet(isPresented: $presentingFullReport) {
            if let home {
                FullReportView(
                    home: home,
                    rooms: homeRooms,
                    allPoints: homePoints,
                    allDevices: homeDevices,
                    allDoorways: homeDoorways
                )
            }
        }
        .sheet(isPresented: $presentingBadge) {
            if let home {
                ShareBadgeView(home: home, rooms: homeRooms)
            }
        }
        .sheet(isPresented: $presentingPaywall) {
            ProPaywallView()
        }
        .alert("Delete Room", isPresented: .init(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { roomToDelete = nil }
            Button("Delete", role: .destructive) {
                if let room = roomToDelete {
                    modelContext.delete(room)
                    try? modelContext.save()
                    roomToDelete = nil
                }
            }
        } message: {
            if let room = roomToDelete {
                Text("Delete \"\(room.displayName)\"? This cannot be undone.")
            }
        }
        .alert("Rename Room", isPresented: $showRenameAlert) {
            TextField("Room name", text: $renameText)
            Button("Cancel", role: .cancel) { roomToRename = nil }
            Button("Save") {
                if let room = roomToRename {
                    room.customName = renameText.isEmpty ? nil : renameText
                    try? modelContext.save()
                    roomToRename = nil
                }
            }
        } message: {
            Text("Enter a new name for this room.")
        }
    }

    // MARK: - Floor Map Section

    private func floorMapSection(_ home: HomeConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Floor Plan")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            FloorMapView(rooms: homeRooms, doorways: homeDoorways, home: home)
                .frame(height: 260)
                .background(Color.white.opacity(0.03))
                .cornerRadius(14)
        }
    }

    // MARK: - WiFi Report Card Button

    private var wifiReportCardButton: some View {
        Button {
            presentingWiFiReportCard = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "wifi.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("WiFi Report Card")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Shareable grade summary — your home's WiFi \"Carfax\" report.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Full Report Button

    private var fullReportButton: some View {
        Button {
            presentingFullReport = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cyan.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "doc.richtext.fill")
                        .font(.title3)
                        .foregroundStyle(cyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Full House Report")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("PDF with whole-house synopsis, room comparisons, and heatmaps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cyan.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share Badge CTA

    @ViewBuilder
    private var shareBadgeCTA: some View {
        if home != nil {
            Button {
                if subs.isPro {
                    presentingBadge = true
                } else {
                    presentingPaywall = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cyan.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "qrcode")
                            .font(.title3)
                            .foregroundStyle(cyan)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Shareable Results Badge")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .accessibilityIdentifier(AccessibilityID.Results.shareBadgeButton)
                            if !subs.isPro {
                                Text("PRO")
                                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(cyan)
                                    .foregroundStyle(.black)
                                    .cornerRadius(4)
                            }
                        }
                        Text("Prove your Wi-Fi works — great for rentals and listings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cyan.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No rooms scanned yet")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Start a scan from the Home Scan tab to see results here.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Overall

    private var overallCard: some View {
        VStack(spacing: 16) {
            Text("Overall grade")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: CGFloat(overallScore / 100))
                        .stroke(gradeColor(overallLetter), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                    Text(overallLetter)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor(overallLetter))
                        .accessibilityIdentifier(AccessibilityID.Results.gradeLabel)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(overallScore))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(homeRooms.count) room\(homeRooms.count == 1 ? "" : "s") scanned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    // MARK: - Per-Room Grades

    private var roomGrades: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rooms")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            ForEach(floorGroups, id: \.floorIndex) { group in
                if floorGroups.count > 1 {
                    Text(group.label)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, group.floorIndex == floorGroups.first?.floorIndex ? 0 : 6)
                }
                ForEach(group.rooms) { room in
                    NavigationLink {
                        RoomDetailView(room: room)
                    } label: {
                        roomGradeRow(room)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.Results.roomRow + ".\(room.displayName)")
                    .contextMenu {
                        Button {
                            renameText = room.customName ?? ""
                            roomToRename = room
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomToDelete = room
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func roomGradeRow(_ room: Room) -> some View {
        HStack(spacing: 12) {
            Image(systemName: room.roomType.systemImage)
                .foregroundStyle(cyan)
                .frame(width: 36, height: 36)
                .background(cyan.opacity(0.12))
                .cornerRadius(9)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(Int(room.downloadMbps)) Mbps · \(Int(room.pingMs)) ms ping")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(room.gradeLetterRaw.isEmpty ? "—" : room.gradeLetterRaw)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(room.gradeLetterRaw.isEmpty ? .secondary : gradeColor(room.gradeLetterRaw))
                .frame(width: 34, height: 34)
                .background((room.gradeLetterRaw.isEmpty ? Color.secondary : gradeColor(room.gradeLetterRaw)).opacity(0.15))
                .clipShape(Circle())
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }

    // MARK: - Mesh Recommendation

    private func meshRecommendationCard(_ mesh: MeshRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.circle")
                    .foregroundStyle(.purple)
                    .font(.title3)
                Text("Mesh System Recommended")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(mesh.recommendation)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best room")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mesh.bestRoom)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs help")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mesh.worstRoom)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mesh.speedGap)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mesh.signalGap)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Whole-House Recommendations

    private var wholeHouseRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Home Recommendations")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }

            ForEach(wholeHouseAnalysis.recommendations) { rec in
                recommendationRow(rec)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func recommendationRow(_ rec: WholeHouseRecommendation) -> some View {
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

    // MARK: - Floor Grouping

    private struct FloorGroup {
        let floorIndex: Int
        let label: String
        let rooms: [Room]
    }

    private var floorGroups: [FloorGroup] {
        let grouped = Dictionary(grouping: homeRooms) { $0.floorIndex }
        return grouped.keys.sorted().map { index in
            let label = floorLabel(forIndex: index)
            return FloorGroup(floorIndex: index, label: label, rooms: grouped[index] ?? [])
        }
    }

    private func floorLabel(forIndex index: Int) -> String {
        guard let home, home.floorLabels.indices.contains(index) else {
            return "Floor \(index + 1)"
        }
        return home.floorLabels[index]
    }
}

/// Placeholder room detail — Pass 5 replaces this with the overlays view
/// (signal, weak spots, interference, recommendations, painted coverage).
struct RoomDetailPlaceholder: View {
    let room: Room
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: room.roomType.systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                Text(room.displayName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text("Detailed overlays coming soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ResultsHomeView() }
        .modelContainer(for: [HomeConfiguration.self, Room.self, HeatmapPoint.self], inMemory: true)
}
