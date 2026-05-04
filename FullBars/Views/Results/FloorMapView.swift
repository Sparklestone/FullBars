import SwiftUI

/// A visual floor-plan-style map of scanned rooms. Connected rooms are stitched
/// together using doorway anchoring and compass-heading rotation so they align
/// like a real blueprint. All rooms are placed in one unified coordinate space —
/// doorway-connected rooms snap together, others flow-layout beside the cluster.
///
/// **Stitching algorithm:**
/// 1. Rotate each room's polygon to true north using `−compassHeading`.
/// 2. Build an adjacency graph via `Doorway.connectsToRoomId`.
/// 3. BFS from an anchor room: for each connected pair, translate the new room
///    so the shared doorway points coincide.
/// 4. Auto-place any unconnected rooms in a flow row below the cluster.
/// 5. Render ALL rooms in a single GeometryReader so they align correctly.
struct FloorMapView: View {
    let rooms: [Room]
    let doorways: [Doorway]
    let home: HomeConfiguration?
    var isFullScreen: Bool = false

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    @State private var selectedFloorIndex: Int = 0
    @State private var showHeatmapOverlay: Bool = false

    // MARK: - Computed layout

    /// All rooms grouped by floor
    private var roomsByFloor: [(floorLabel: String, rooms: [Room])] {
        guard let home else {
            return rooms.isEmpty ? [] : [("All Rooms", rooms)]
        }
        let floors = Dictionary(grouping: rooms) { $0.floorIndex }
        return floors.keys.sorted().map { idx in
            let label = home.floorLabels.indices.contains(idx)
                ? home.floorLabels[idx]
                : "Floor \(idx + 1)"
            return (label, floors[idx] ?? [])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Floor selector (only if multiple floors)
            if roomsByFloor.count > 1 {
                floorSelector
            }

            // Blueprint toolbar — heatmap toggle, room count
            if !rooms.isEmpty {
                blueprintToolbar
            }

            // Main blueprint area
            ScrollView {
                if roomsByFloor.indices.contains(selectedFloorIndex) {
                    let floor = roomsByFloor[selectedFloorIndex]
                    floorBlueprint(rooms: floor.rooms)
                        .padding(.horizontal, isFullScreen ? 12 : 20)
                        .padding(.top, 8)
                } else if let first = roomsByFloor.first {
                    floorBlueprint(rooms: first.rooms)
                        .padding(.horizontal, isFullScreen ? 12 : 20)
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Floor Selector

    private var floorSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(roomsByFloor.enumerated()), id: \.offset) { idx, floor in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFloorIndex = idx
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                                .font(.system(size: 10))
                            Text(floor.floorLabel)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                            Text("(\(floor.rooms.count))")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(selectedFloorIndex == idx ? .white.opacity(0.7) : .secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedFloorIndex == idx ? cyan.opacity(0.25) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedFloorIndex == idx ? cyan.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(selectedFloorIndex == idx ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Blueprint Toolbar

    private var blueprintToolbar: some View {
        HStack {
            // Room count badge
            let floorRooms = roomsByFloor.indices.contains(selectedFloorIndex)
                ? roomsByFloor[selectedFloorIndex].rooms
                : rooms
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 10))
                Text("\(floorRooms.count) room\(floorRooms.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .rounded))
            }
            .foregroundStyle(.secondary)

            Spacer()

            // Heatmap overlay toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showHeatmapOverlay.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showHeatmapOverlay ? "waveform.badge.minus" : "waveform.badge.plus")
                        .font(.system(size: 11))
                    Text(showHeatmapOverlay ? "Grades" : "Signal")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                }
                .foregroundStyle(showHeatmapOverlay ? cyan : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(showHeatmapOverlay ? cyan.opacity(0.15) : Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Floor Blueprint

    /// For a set of rooms on one floor, compute the stitched layout and render.
    private func floorBlueprint(rooms: [Room]) -> some View {
        let layout = BlueprintLayout.compute(rooms: rooms, doorways: doorways)

        return VStack(alignment: .leading, spacing: 16) {
            if !layout.stitchedRooms.isEmpty {
                stitchedClusterView(layout: layout, floorRooms: rooms)
            }

            // Unconnected rooms in flow grid (shouldn't trigger now, but kept as fallback)
            if !layout.unconnectedRooms.isEmpty {
                unconnectedGrid(rooms: layout.unconnectedRooms)
            }
        }
    }

    // MARK: - Stitched Cluster View

    /// Renders the stitched blueprint cluster in a single coordinate space.
    /// All room polygons are drawn with absolute coordinates inside one ZStack
    /// so they align correctly relative to each other.
    private func stitchedClusterView(layout: BlueprintLayout, floorRooms: [Room]) -> some View {
        GeometryReader { geo in
            let fitted = layout.fitToSize(geo.size, padding: 16)

            ZStack {
                // Draw each room's filled polygon + stroke
                ForEach(fitted.roomFrames) { frame in
                    roomPolygon(frame: frame, showSignal: showHeatmapOverlay)
                }

                // Doorway indicators between connected rooms
                ForEach(fitted.roomFrames) { frame in
                    // Grade badge — top-right of each room's bounding box
                    gradeBadge(for: frame)
                }

                // Overlay tappable labels at each room's centre
                ForEach(fitted.roomFrames) { frame in
                    NavigationLink {
                        RoomDetailView(room: frame.room)
                    } label: {
                        roomLabel(for: frame)
                    }
                    .buttonStyle(.plain)
                    .position(frame.labelCenter)
                }
            }
        }
        .frame(height: dynamicHeight(roomCount: layout.stitchedRooms.count))
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Dynamic height based on room count — scales up for more rooms
    private func dynamicHeight(roomCount: Int) -> CGFloat {
        if isFullScreen {
            return max(350, min(600, CGFloat(roomCount) * 100 + 150))
        }
        return max(260, min(450, CGFloat(roomCount) * 70 + 120))
    }

    /// Grade badge positioned at the top-right of a room's bounding box
    private func gradeBadge(for frame: BlueprintLayout.RoomFrame) -> some View {
        let grade = frame.room.gradeLetterRaw
        let color = gradeColor(grade)

        return Text(grade.isEmpty ? "—" : grade)
            .font(.system(size: 9, design: .rounded).weight(.heavy))
            .foregroundStyle(grade.isEmpty ? Color.secondary : Color.white)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(grade.isEmpty ? Color.secondary.opacity(0.3) : color.opacity(0.85))
            )
            .position(x: frame.boundingBox.maxX - 4, y: frame.boundingBox.minY + 4)
    }

    /// Compact label shown at the centre of each stitched room polygon.
    private func roomLabel(for frame: BlueprintLayout.RoomFrame) -> some View {
        let grade = frame.room.gradeLetterRaw
        let color = gradeColor(grade)

        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: frame.room.roomType.systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(cyan)
                Text(frame.room.displayName)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Text(grade.isEmpty ? "—" : grade)
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .foregroundStyle(grade.isEmpty ? .secondary : color)
            HStack(spacing: 5) {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.green)
                    Text("\(Int(frame.room.downloadMbps))")
                        .font(.system(size: 9, design: .rounded).weight(.medium))
                        .foregroundStyle(.green)
                }
                HStack(spacing: 1) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(cyan)
                    Text("\(Int(frame.room.uploadMbps))")
                        .font(.system(size: 9, design: .rounded).weight(.medium))
                        .foregroundStyle(cyan)
                }
            }
        }
        .padding(4)
        .background(bg.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Renders a single room's polygon fill + stroke.
    /// In signal mode, fill color is based on average signal strength.
    /// In grade mode, fill color matches the room's letter grade.
    @ViewBuilder
    private func roomPolygon(frame: BlueprintLayout.RoomFrame, showSignal: Bool) -> some View {
        if showSignal {
            let signalColor = signalScoreColor(frame.room.gradeScore)
            frame.path
                .fill(signalColor.opacity(0.25))
            frame.path
                .stroke(signalColor.opacity(0.7), lineWidth: 1.5)
        } else {
            let color = gradeColor(frame.room.gradeLetterRaw)
            frame.path
                .fill(color.opacity(0.12))
            frame.path
                .stroke(color.opacity(0.6), lineWidth: 1.5)
        }
    }

    /// Maps a room's grade score (0–100) to a signal-style color for the heatmap overlay
    private func signalScoreColor(_ score: Double) -> Color {
        switch score {
        case 85...:       return .green        // Excellent
        case 70..<85:     return .mint          // Good
        case 55..<70:     return .yellow        // Fair
        case 40..<55:     return .orange        // Weak
        default:          return .red           // Very weak / dead
        }
    }

    // MARK: - Unconnected Grid

    /// Rooms without doorway connections get the familiar 2-column card layout.
    private func unconnectedGrid(rooms: [Room]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(rooms) { room in
                NavigationLink {
                    RoomDetailView(room: room)
                } label: {
                    roomMapCard(room)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Room Map Card (fallback)

    private func roomMapCard(_ room: Room) -> some View {
        let grade = room.gradeLetterRaw
        let color = gradeColor(grade)

        return VStack(spacing: 0) {
            // Room shape area
            ZStack {
                color.opacity(0.08)
                roomCardShape(room, color: color)
                    .padding(12)
                // Grade badge — top right
                VStack {
                    HStack {
                        Spacer()
                        Text(grade.isEmpty ? "—" : grade)
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(grade.isEmpty ? .secondary : color)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(bg)
                                    .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 1.5))
                            )
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(height: 120)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 12, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 12
            ))

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: room.roomType.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(cyan)
                    Text(room.displayName)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.green)
                        Text("\(Int(room.downloadMbps))")
                            .font(.system(.caption2, design: .rounded).weight(.medium))
                            .foregroundStyle(.green)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(cyan)
                        Text("\(Int(room.uploadMbps))")
                            .font(.system(.caption2, design: .rounded).weight(.medium))
                            .foregroundStyle(cyan)
                    }
                    if room.deadZoneCount > 0 {
                        HStack(spacing: 1) {
                            Text("💀")
                                .font(.system(size: 9))
                            Text("\(room.deadZoneCount)")
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 12,
                bottomTrailingRadius: 12, topTrailingRadius: 0
            ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func roomCardShape(_ room: Room, color: Color) -> some View {
        let corners = room.corners
        if corners.count >= 3 {
            cardPolygonView(corners: corners.map { (Double($0.0), Double($0.1)) }, color: color)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                .overlay(
                    Image(systemName: room.roomType.systemImage)
                        .font(.system(size: 28))
                        .foregroundStyle(color.opacity(0.3))
                )
        }
    }

    private func cardPolygonView(corners: [(Double, Double)], color: Color) -> some View {
        GeometryReader { geo in
            let path = Self.scaledPolygonPath(corners: corners, in: geo.size, padding: 8)
            path.fill(color.opacity(0.15))
                .overlay(path.stroke(color.opacity(0.6), lineWidth: 1.5))
        }
    }

    // MARK: - Helpers

    private func gradeColor(_ letter: String) -> Color {
        switch letter.uppercased() {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default:  return .secondary
        }
    }

    /// Scales corner coordinates to fit within the given CGSize.
    static func scaledPolygonPath(corners: [(Double, Double)], in size: CGSize, padding: CGFloat) -> Path {
        guard !corners.isEmpty else { return Path() }
        let xs = corners.map(\.0), ys = corners.map(\.1)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let roomW = maxX - minX, roomH = maxY - minY
        guard roomW > 0, roomH > 0 else { return Path() }

        let availW = size.width - padding * 2
        let availH = size.height - padding * 2
        let scale = min(availW / CGFloat(roomW), availH / CGFloat(roomH))
        let scaledW = CGFloat(roomW) * scale
        let scaledH = CGFloat(roomH) * scale
        let offX = padding + (availW - scaledW) / 2
        let offY = padding + (availH - scaledH) / 2

        return Path { path in
            for (i, c) in corners.enumerated() {
                let x = offX + CGFloat(c.0 - minX) * scale
                let y = offY + CGFloat(c.1 - minY) * scale
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Blueprint Layout Engine

/// Pure-value layout computation for stitching rooms together.
/// Separated from the view so it's testable and doesn't depend on SwiftUI geometry.
struct BlueprintLayout {

    /// A room positioned in the shared coordinate space.
    struct PlacedRoom {
        let room: Room
        /// Room corners rotated to true north and translated to their
        /// position in the shared blueprint coordinate space.
        let worldCorners: [CGPoint]
    }

    /// Final frame info ready for rendering.
    struct RoomFrame: Identifiable {
        var id: UUID { room.id }
        let room: Room
        let path: Path
        let boundingBox: CGRect
        let labelCenter: CGPoint
    }

    /// Layout result after fitting to a view size.
    struct FittedLayout {
        let roomFrames: [RoomFrame]
    }

    let stitchedRooms: [PlacedRoom]
    let unconnectedRooms: [Room]

    // MARK: - Compute

    /// Build the stitched layout from rooms and doorways.
    /// All rooms are placed in the blueprint — connected rooms use doorway alignment,
    /// unconnected rooms are auto-placed in a flow layout adjacent to the cluster.
    static func compute(rooms: [Room], doorways: [Doorway]) -> BlueprintLayout {
        guard !rooms.isEmpty else {
            return BlueprintLayout(stitchedRooms: [], unconnectedRooms: [])
        }

        let roomMap = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })

        // Build adjacency via doorway connections
        struct DoorwayLink {
            let fromRoomId: UUID
            let toRoomId: UUID
            let fromPosition: CGPoint
            let toPosition: CGPoint
        }

        var links: [DoorwayLink] = []
        var adjacency: [UUID: Set<UUID>] = [:]

        for doorway in doorways {
            guard let targetId = doorway.connectsToRoomId,
                  roomMap[doorway.roomId] != nil,
                  roomMap[targetId] != nil else { continue }

            let reciprocal = doorways.first {
                $0.roomId == targetId && $0.connectsToRoomId == doorway.roomId
            }
            guard let recip = reciprocal else { continue }

            if doorway.roomId.uuidString < targetId.uuidString {
                links.append(DoorwayLink(
                    fromRoomId: doorway.roomId,
                    toRoomId: targetId,
                    fromPosition: CGPoint(x: CGFloat(doorway.x), y: CGFloat(doorway.z)),
                    toPosition: CGPoint(x: CGFloat(recip.x), y: CGFloat(recip.z))
                ))
            }
            adjacency[doorway.roomId, default: []].insert(targetId)
            adjacency[targetId, default: []].insert(doorway.roomId)
        }

        struct RoomPlacement {
            let room: Room
            let northCorners: [CGPoint]
            let translation: CGPoint
        }

        var placements: [UUID: RoomPlacement] = [:]

        // --- Phase 1: Place doorway-connected rooms via BFS ---
        let connectedIds = Set(adjacency.keys)
        if !connectedIds.isEmpty {
            let anchorId = connectedIds.max(by: {
                (adjacency[$0]?.count ?? 0) < (adjacency[$1]?.count ?? 0)
            })!

            var queue: [UUID] = [anchorId]
            var visited: Set<UUID> = [anchorId]

            if let anchor = roomMap[anchorId] {
                let nc = rotateToNorth(room: anchor)
                placements[anchorId] = RoomPlacement(room: anchor, northCorners: nc, translation: .zero)
            }

            while !queue.isEmpty {
                let currentId = queue.removeFirst()
                guard let neighbors = adjacency[currentId] else { continue }

                for neighborId in neighbors where !visited.contains(neighborId) {
                    visited.insert(neighborId)

                    let link = links.first {
                        ($0.fromRoomId == currentId && $0.toRoomId == neighborId) ||
                        ($0.fromRoomId == neighborId && $0.toRoomId == currentId)
                    }

                    guard let link,
                          let currentRoom = roomMap[currentId],
                          let neighborRoom = roomMap[neighborId],
                          let currentPlacement = placements[currentId] else { continue }

                    let (currentDoorLocal, neighborDoorLocal): (CGPoint, CGPoint)
                    if link.fromRoomId == currentId {
                        currentDoorLocal = link.fromPosition
                        neighborDoorLocal = link.toPosition
                    } else {
                        currentDoorLocal = link.toPosition
                        neighborDoorLocal = link.fromPosition
                    }

                    let currentAngle = -currentRoom.compassHeading * .pi / 180
                    let neighborAngle = -neighborRoom.compassHeading * .pi / 180
                    let currentDoorNorth = rotatePoint(currentDoorLocal, by: currentAngle)
                    let neighborDoorNorth = rotatePoint(neighborDoorLocal, by: neighborAngle)

                    let currentDoorWorld = CGPoint(
                        x: currentDoorNorth.x + currentPlacement.translation.x,
                        y: currentDoorNorth.y + currentPlacement.translation.y
                    )
                    let neighborTranslation = CGPoint(
                        x: currentDoorWorld.x - neighborDoorNorth.x,
                        y: currentDoorWorld.y - neighborDoorNorth.y
                    )

                    let nc = rotateToNorth(room: neighborRoom)
                    placements[neighborId] = RoomPlacement(
                        room: neighborRoom, northCorners: nc, translation: neighborTranslation
                    )
                    queue.append(neighborId)
                }
            }
        }

        // --- Phase 2: Auto-place unconnected rooms in a flow layout ---
        // All rooms get north-aligned and placed so the entire floor is one map.
        let unplacedRooms = rooms.filter { placements[$0.id] == nil }

        if !unplacedRooms.isEmpty {
            // Find bounding box of already-placed rooms (if any)
            let allPlacedCorners = placements.values.flatMap { p in
                p.northCorners.map { CGPoint(x: $0.x + p.translation.x, y: $0.y + p.translation.y) }
            }
            var clusterBounds = boundingRect(allPlacedCorners)

            // If no rooms placed yet, start at origin
            if clusterBounds == .zero { clusterBounds = CGRect(x: 0, y: 0, width: 0, height: 0) }

            // Place unconnected rooms in a row below the cluster
            let gap: CGFloat = 1.5 // meters gap between rooms
            var cursorX = clusterBounds.minX
            let cursorY = clusterBounds.maxY + gap

            for room in unplacedRooms {
                let nc = rotateToNorth(room: room)
                guard !nc.isEmpty else { continue }

                let roomBounds = boundingRect(nc)

                // Translate so room's top-left aligns with cursor
                let tx = cursorX - roomBounds.minX
                let ty = cursorY - roomBounds.minY

                placements[room.id] = RoomPlacement(
                    room: room, northCorners: nc, translation: CGPoint(x: tx, y: ty)
                )

                // Advance cursor right
                cursorX += roomBounds.width + gap
            }
        }

        // Convert all placements to PlacedRooms
        var allPlaced: [PlacedRoom] = []
        for room in rooms {
            guard let p = placements[room.id] else { continue }
            let worldCorners = p.northCorners.map {
                CGPoint(x: $0.x + p.translation.x, y: $0.y + p.translation.y)
            }
            allPlaced.append(PlacedRoom(room: p.room, worldCorners: worldCorners))
        }

        // All rooms are now "stitched" — none are unconnected in the view
        return BlueprintLayout(
            stitchedRooms: allPlaced,
            unconnectedRooms: []
        )
    }

    // MARK: - Fit to view size

    /// Transform placed rooms into render-ready frames that fit within `size`.
    func fitToSize(_ size: CGSize, padding: CGFloat) -> FittedLayout {
        guard !stitchedRooms.isEmpty else { return FittedLayout(roomFrames: []) }

        // Find the bounding box of all placed rooms
        let allPoints = stitchedRooms.flatMap(\.worldCorners)
        let allBounds = Self.boundingRect(allPoints)
        guard allBounds.width > 0, allBounds.height > 0 else {
            return FittedLayout(roomFrames: [])
        }

        let availW = size.width - padding * 2
        let availH = size.height - padding * 2
        let scale = min(availW / allBounds.width, availH / allBounds.height)

        // Centre the layout
        let scaledW = allBounds.width * scale
        let scaledH = allBounds.height * scale
        let globalOffX = padding + (availW - scaledW) / 2
        let globalOffY = padding + (availH - scaledH) / 2

        var frames: [RoomFrame] = []

        for placed in stitchedRooms {
            let screenCorners = placed.worldCorners.map { pt in
                CGPoint(
                    x: globalOffX + (pt.x - allBounds.minX) * scale,
                    y: globalOffY + (pt.y - allBounds.minY) * scale
                )
            }

            guard screenCorners.count >= 3 else { continue }

            let path = Path { p in
                for (i, c) in screenCorners.enumerated() {
                    if i == 0 { p.move(to: c) }
                    else { p.addLine(to: c) }
                }
                p.closeSubpath()
            }

            let bbox = path.boundingRect
            let center = CGPoint(
                x: screenCorners.map(\.x).reduce(0, +) / CGFloat(screenCorners.count),
                y: screenCorners.map(\.y).reduce(0, +) / CGFloat(screenCorners.count)
            )

            frames.append(RoomFrame(
                room: placed.room,
                path: path,
                boundingBox: bbox,
                labelCenter: center
            ))
        }

        return FittedLayout(roomFrames: frames)
    }

    // MARK: - Geometry helpers

    /// Rotate a room's corners to true north using its compassHeading.
    /// compassHeading is degrees clockwise from true north, so we rotate
    /// by −heading to align room-local X axis with geographic east.
    private static func rotateToNorth(room: Room) -> [CGPoint] {
        let corners = room.corners
        guard corners.count >= 3 else { return [] }
        let angleRad = -room.compassHeading * .pi / 180

        return corners.map { corner in
            let pt = CGPoint(x: CGFloat(corner.0), y: CGFloat(corner.1))
            return rotatePoint(pt, by: angleRad)
        }
    }

    /// Rotate a point around the origin by `angle` radians.
    private static func rotatePoint(_ pt: CGPoint, by angle: Double) -> CGPoint {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: pt.x * cosA - pt.y * sinA,
            y: pt.x * sinA + pt.y * cosA
        )
    }

    /// Bounding rect for a set of points.
    static func boundingRect(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

#Preview {
    NavigationStack {
        FloorMapView(rooms: [], doorways: [], home: nil)
    }
}
