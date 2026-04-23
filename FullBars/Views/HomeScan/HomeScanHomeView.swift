import SwiftUI
import SwiftData

/// The new Home Scan tab — the entry point for scanning rooms. Shows the
/// user's home summary, a list of rooms already scanned (with per-room grade),
/// and the "Scan a room" CTA. Empty state prompts the first scan.
struct HomeScanHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [HomeConfiguration]
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]

    @State private var presentingNewRoom = false

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    @State private var subs = SubscriptionManager.shared
    @State private var roomToDelete: Room?
    @State private var roomToRename: Room?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    private var home: HomeConfiguration? { HomeSelection.activeHome(from: homes) }

    /// Closure to switch to the Results tab (injected by AppShell).
    var switchToResults: (() -> Void)? = nil

    // Only show rooms for the active home — deduped for free users.
    private var homeRooms: [Room] {
        guard let home else { return [] }
        let all = rooms.filter { $0.homeId == home.id }
        return RescanHistory.visibleRooms(for: all, isPro: subs.isPro)
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    homeHeader
                    if homeRooms.isEmpty {
                        emptyState
                    } else {
                        roomList
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Home Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentingNewRoom = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(cyan)
                }
                .accessibilityLabel("Scan a new room")
            }
        }
        .fullScreenCover(isPresented: $presentingNewRoom) {
            RoomScanView()
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Home Header

    @ViewBuilder
    private var homeHeader: some View {
        if let home {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "house.fill")
                        .foregroundStyle(cyan)
                        .font(.title3)
                    Text(home.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                }

                HStack(spacing: 16) {
                    statPill(label: "Sq ft", value: "\(home.squareFootage)")
                    statPill(label: "Floors", value: "\(home.numberOfFloors)")
                    if home.hasMeshNetwork {
                        statPill(label: "Mesh", value: "\(home.meshNodeCount + 1)")
                    }
                }

                if let label = floorSummary(home: home) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 56)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }

    private func floorSummary(home: HomeConfiguration) -> String? {
        let labels = home.floorLabels
        guard labels.count > 1 else { return nil }
        return labels.joined(separator: " · ")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(cyan)
            }
            .padding(.top, 24)

            Text("Scan your first room")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)

            Text("We'll walk you through it step by step: run a quick speed test, mark the corners, then walk the floor so we can measure signal everywhere.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                presentingNewRoom = true
            } label: {
                Label("Start scan", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    // MARK: - Room List

    private var roomList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scanned rooms")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(homeRooms.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                        roomCard(room)
                    }
                    .buttonStyle(.plain)
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

            Button {
                presentingNewRoom = true
            } label: {
                Label("Scan another room", systemImage: "plus")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(cyan)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(cyan.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 8)

            // View Results button
            if let switchToResults {
                Button {
                    switchToResults()
                } label: {
                    Label("View Results", systemImage: "chart.bar.doc.horizontal")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundStyle(.black)
                        .cornerRadius(14)
                }
                .padding(.top, 4)
            }
        }
    }

    private func roomCard(_ room: Room) -> some View {
        HStack(spacing: 14) {
            Image(systemName: room.roomType.systemImage)
                .font(.title2)
                .foregroundStyle(cyan)
                .frame(width: 44, height: 44)
                .background(cyan.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                Text(room.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text(floorLabel(for: room) + " · \(Int(room.downloadMbps)) Mbps down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !room.gradeLetterRaw.isEmpty {
                Text(room.gradeLetterRaw)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(gradeColor(for: room.gradeLetterRaw))
                    .frame(width: 36, height: 36)
                    .background(gradeColor(for: room.gradeLetterRaw).opacity(0.15))
                    .clipShape(Circle())
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }

    private func floorLabel(for room: Room) -> String {
        guard let home, home.floorLabels.indices.contains(room.floorIndex) else {
            return "Floor \(room.floorIndex + 1)"
        }
        return home.floorLabels[room.floorIndex]
    }

    private func gradeColor(for letter: String) -> Color {
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

/// Placeholder sheet that announces the new room walkthrough. The real
/// walkthrough ships in Pass 4 — for now this is a signpost so the new
/// shell compiles and runs while we build the guts.
struct NewRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let cyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 56))
                    .foregroundStyle(cyan)

                Text("Room walkthrough")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Coming in the next build. The guided scan (corner-mark, entry-mark, device-mark, paint-the-floor) is being wired up right now.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Close") { dismiss() }
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack { HomeScanHomeView() }
        .modelContainer(for: [HomeConfiguration.self, Room.self], inMemory: true)
}
