import SwiftUI
import SwiftData

/// The new Results tab — shows overall house grade and a colour-coded room list.
/// Tapping a room drills into a detail view (Pass 5 will flesh this out).
struct ResultsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [HomeConfiguration]
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    @State private var presentingBadge = false
    @State private var presentingPaywall = false
    @State private var subs = SubscriptionManager.shared

    private var home: HomeConfiguration? { HomeSelection.activeHome(from: homes) }
    private var homeRooms: [Room] {
        guard let home else { return [] }
        let all = rooms.filter { $0.homeId == home.id }
        return RescanHistory.visibleRooms(for: all, isPro: subs.isPro)
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
                        roomGrades
                        if let home, !home.ispName.isEmpty, home.ispPromisedDownloadMbps > 0 {
                            planComparison(home: home)
                        }
                        shareBadgeCTA
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $presentingBadge) {
            if let home {
                ShareBadgeView(home: home, rooms: homeRooms)
            }
        }
        .sheet(isPresented: $presentingPaywall) {
            ProPaywallView()
        }
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
                            Text(String(localized: "results.share_badge"))
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

            ForEach(homeRooms) { room in
                NavigationLink {
                    RoomDetailView(room: room)
                } label: {
                    roomGradeRow(room)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Results.roomRow + ".\(room.displayName)")
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
    }

    // MARK: - Plan Comparison

    private func planComparison(home: HomeConfiguration) -> some View {
        let avgDownload = homeRooms.isEmpty ? 0 : homeRooms.reduce(0.0) { $0 + $1.downloadMbps } / Double(homeRooms.count)
        let percent = home.ispPromisedDownloadMbps > 0 ? (avgDownload / home.ispPromisedDownloadMbps) * 100 : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("Your internet plan")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(home.ispName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Paid for \(Int(home.ispPromisedDownloadMbps)) Mbps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(percent))%")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(planColor(percent))
                    Text("of plan delivered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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

    private func planColor(_ percent: Double) -> Color {
        switch percent {
        case 85...: return .green
        case 65..<85: return .yellow
        case 40..<65: return .orange
        default: return .red
        }
    }
}

/// Placeholder room detail — Pass 5 replaces this with the overlays view
/// (signal, dead zones, interference, recommendations, painted coverage).
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
        .modelContainer(for: [HomeConfiguration.self, Room.self], inMemory: true)
}
