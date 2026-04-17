import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Shared container

/// Builds a read-only ModelContainer that points at the App Group store
/// shared with the main app.  The widget never writes — it just reads the
/// latest Room / HomeConfiguration rows.
@MainActor
func makeSharedContainer() -> ModelContainer? {
    guard let url = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fullbars.shared")?
        .appending(path: "default.store") else { return nil }

    let config = ModelConfiguration(url: url, allowsSave: false)
    return try? ModelContainer(
        for: HomeConfiguration.self, Room.self,
        configurations: config
    )
}

// MARK: - Timeline entry

struct GradeEntry: TimelineEntry {
    let date: Date
    let letter: String      // "A" … "F" or "—"
    let score: Int           // 0-100
    let roomCount: Int
    let homeName: String
}

// MARK: - Timeline provider

struct GradeProvider: TimelineProvider {
    func placeholder(in context: Context) -> GradeEntry {
        GradeEntry(date: .now, letter: "B", score: 82, roomCount: 4, homeName: "Home")
    }

    func getSnapshot(in context: Context, completion: @escaping (GradeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GradeEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 30 minutes — the grade only changes after a scan.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    @MainActor
    private func currentEntry() -> GradeEntry {
        guard let container = makeSharedContainer() else {
            return GradeEntry(date: .now, letter: "—", score: 0, roomCount: 0, homeName: "FullBars")
        }
        let ctx = container.mainContext
        let homes = (try? ctx.fetch(FetchDescriptor<HomeConfiguration>())) ?? []
        let rooms = (try? ctx.fetch(FetchDescriptor<Room>())) ?? []

        // Pick the first home (or whichever is "active" — simplified here).
        let home = homes.first
        let homeRooms = rooms.filter { $0.homeId == home?.id }

        guard !homeRooms.isEmpty else {
            return GradeEntry(date: .now, letter: "—", score: 0, roomCount: 0,
                              homeName: home?.name ?? "FullBars")
        }

        let avg = homeRooms.reduce(0.0) { $0 + $1.gradeScore } / Double(homeRooms.count)
        let letter: String = {
            switch avg {
            case 90...:   return "A"
            case 80..<90: return "B"
            case 70..<80: return "C"
            case 60..<70: return "D"
            default:      return "F"
            }
        }()

        return GradeEntry(date: .now, letter: letter, score: Int(avg),
                          roomCount: homeRooms.count, homeName: home?.name ?? "Home")
    }
}

// MARK: - Lock screen (circular)

struct GradeCircularView: View {
    let entry: GradeEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.letter)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("\(entry.score)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Lock screen (rectangular)

struct GradeRectangularView: View {
    let entry: GradeEntry

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.letter)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: 2) {
                Text("FullBars")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("\(entry.score)/100 · \(entry.roomCount) rooms")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Home screen (small)

struct GradeSmallView: View {
    let entry: GradeEntry

    var body: some View {
        VStack(spacing: 6) {
            Text("FullBars")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(entry.letter)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(gradeColor)

            Text("\(entry.score)/100")
                .font(.system(size: 14, weight: .medium, design: .rounded))

            Text("\(entry.roomCount) room\(entry.roomCount == 1 ? "" : "s")")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.black, for: .widget)
    }

    private var gradeColor: Color {
        switch entry.letter {
        case "A": return .green
        case "B": return .mint
        case "C": return .yellow
        case "D": return .orange
        default:  return .red
        }
    }
}

// MARK: - Widget definition

struct FullBarsWidget: Widget {
    let kind = "FullBarsGrade"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GradeProvider()) { entry in
            switch WidgetFamily.allCases.first {
            default:
                GradeSmallView(entry: entry)
            }
        }
        .configurationDisplayName("Wi-Fi Grade")
        .description("See your home's overall Wi-Fi grade at a glance.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget entry point

@main
struct FullBarsWidgetBundle: WidgetBundle {
    var body: some Widget {
        FullBarsWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FullBarsWidget()
} timeline: {
    GradeEntry(date: .now, letter: "A", score: 92, roomCount: 5, homeName: "Home")
    GradeEntry(date: .now, letter: "C", score: 73, roomCount: 3, homeName: "Home")
}

#Preview("Circular", as: .accessoryCircular) {
    FullBarsWidget()
} timeline: {
    GradeEntry(date: .now, letter: "B", score: 85, roomCount: 4, homeName: "Home")
}

#Preview("Rectangular", as: .accessoryRectangular) {
    FullBarsWidget()
} timeline: {
    GradeEntry(date: .now, letter: "B", score: 85, roomCount: 4, homeName: "Home")
}
