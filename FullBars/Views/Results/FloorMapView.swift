import SwiftUI

/// A visual floor-plan-style map of scanned rooms. Connected rooms are stitched
/// together using doorway anchoring and compass-heading rotation so they align
/// like a real blueprint. Rooms without connections fall back to a flow grid.
///
/// **Stitching algorithm:**
/// 1. Rotate each room's polygon to true north using `−compassHeading`.
/// 2. Build an adjacency graph via `Doorway.connectsToRoomId`.
/// 3. BFS from an anchor room: for each connected pair, translate the new room
///    so the shared doorway points coincide.
/// 4. Render the stitched cluster in a single GeometryReader, fitting all
///    rooms into the available space.
/// 5. Unconnected rooms render in a 2-column flow grid below the blueprint.
struct FloorMapView: View {
    let rooms: [Room]
    let doorways: [Doorway]
    let home: HomeConfiguration?

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(roomsByFloor.enumerated()), id: \.offset) { _, floor in
                    VStack(alignment: .leading, spacing: 12) {
                        if roomsByFloor.count > 1 {
                            Text(floor.floorLabel)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                        }

                        floorBlueprint(rooms: floor.rooms)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Floor Blueprint

    /// For a set of rooms on one floor, compute the stitched layout and render.
    private func floorBlueprint(rooms: [Room]) -> some View {
        let layout = BlueprintLayout.compute(rooms: rooms, doorways: doorways)

        return VStack(alignment: .leading, spacing: 16) {
            // Stitched cluster (if any rooms have connections)
            if !layout.stitchedRooms.isEmpty {
                stitchedClusterView(layout: layout)
            }

            // Unconnected rooms in flow grid
            if !layout.unconnectedRooms.isEmpty {
                unconnectedGrid(rooms: layout.unconnectedRooms)
            }
        }
    }

    // MARK: - Stitched Cluster View

    /// Renders the stitched blueprint cluster in a single coordinate space.
    /// All room polygons are drawn with absolute coordinates inside one ZStack
    /// so they align correctly relative to each other.
    private func stitchedClusterView(layout: BlueprintLayout) -> some View {
        GeometryReader { geo in
            let fitted = layout.fitToSize(geo.size, padding: 16)

            ZStack {
                // Draw each room's filled polygon + stroke
                ForEach(fitted.roomFrames) { frame in
                    roomPolygon(frame: frame)
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
        .frame(height: max(250, CGFloat(layout.stitchedRooms.count) * 80))
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
    @ViewBuilder
    private func roomPolygon(frame: BlueprintLayout.RoomFrame) -> some View {
        let color = gradeColor(frame.room.gradeLetterRaw)
        frame.path
            .fill(color.opacity(0.12))
        frame.path
            .stroke(color.opacity(0.6), lineWidth: 1.5)
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
    static func compute(rooms: [Room], doorways: [Doorway]) -> BlueprintLayout {
        let roomMap = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })

        // Build adjacency: for each pair of rooms that share a doorway connection,
        // record both doorway positions (in their respective room-local coords).
        struct DoorwayLink {
            let fromRoomId: UUID
            let toRoomId: UUID
            let fromPosition: CGPoint  // doorway in fromRoom's local coords
            let toPosition: CGPoint    // matching doorway in toRoom's local coords
        }

        var links: [DoorwayLink] = []
        var adjacency: [UUID: Set<UUID>] = [:]

        for doorway in doorways {
            guard let targetId = doorway.connectsToRoomId,
                  roomMap[doorway.roomId] != nil,
                  roomMap[targetId] != nil else { continue }

            // Find the reciprocal doorway in the target room that connects back
            let reciprocal = doorways.first {
                $0.roomId == targetId && $0.connectsToRoomId == doorway.roomId
            }

            guard let recip = reciprocal else { continue }

            // Only add the link once (from the room with the smaller UUID)
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

        // Rooms with at least one valid connection
        let connectedIds = Set(adjacency.keys)
        guard !connectedIds.isEmpty else {
            return BlueprintLayout(stitchedRooms: [], unconnectedRooms: rooms)
        }

        // BFS to place rooms. Start with the room that has the most connections
        // (heuristic: produces a more balanced layout).
        let anchorId = connectedIds.max(by: {
            (adjacency[$0]?.count ?? 0) < (adjacency[$1]?.count ?? 0)
        })!

        // Each room stores a translation offset. The anchor sits at (0,0) in
        // world space, meaning its north-rotated corners are used directly.
        // For each subsequent room, we compute a translation that aligns its
        // shared doorway with the already-placed neighbor's doorway.
        //
        // Key insight: rotateToNorth() rotates room-local coords around the
        // room-local origin (0,0) — which is where ARKit placed the session
        // origin for that scan. The doorway position is also in room-local
        // coords, so rotating it the same way gives its north-rotated position.
        // We then just need a per-room translation vector.

        struct RoomPlacement {
            let room: Room
            let northCorners: [CGPoint]   // corners rotated to north (untranslated)
            let translation: CGPoint       // world offset applied to all points
        }

        var placements: [UUID: RoomPlacement] = [:]
        var queue: [UUID] = [anchorId]
        var visited: Set<UUID> = [anchorId]

        // Place the anchor room at origin
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

                // Determine which doorway position belongs to which room
                let (currentDoorLocal, neighborDoorLocal): (CGPoint, CGPoint)
                if link.fromRoomId == currentId {
                    currentDoorLocal = link.fromPosition
                    neighborDoorLocal = link.toPosition
                } else {
                    currentDoorLocal = link.toPosition
                    neighborDoorLocal = link.fromPosition
                }

                // Rotate doorway positions to north (same rotation as corners)
                let currentDoorNorth = rotatePoint(
                    currentDoorLocal, by: -0.0 * .pi / 180
                )
                let neighborDoorNorth = rotatePoint(
                    neighborDoorLocal, by: -0.0 * .pi / 180
                )

                // Current doorway in world space = north position + room translation
                let currentDoorWorld = CGPoint(
                    x: currentDoorNorth.x + currentPlacement.translation.x,
                    y: currentDoorNorth.y + currentPlacement.translation.y
                )

                // Neighbor's translation: move so neighborDoorNorth lands on currentDoorWorld
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

        // Convert placements to PlacedRooms with world corners
        var placed: [UUID: PlacedRoom] = [:]
        for (id, p) in placements {
            let worldCorners = p.northCorners.map {
                CGPoint(x: $0.x + p.translation.x, y: $0.y + p.translation.y)
            }
            placed[id] = PlacedRoom(room: p.room, worldCorners: worldCorners)
        }

        let unconnected = rooms.filter { !connectedIds.contains($0.id) }
        return BlueprintLayout(
            stitchedRooms: Array(placed.values),
            unconnectedRooms: unconnected
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
        let angleRad = -0.0 * .pi / 180

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
