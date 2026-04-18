import WidgetKit
import SwiftUI

// MARK: - Shared data bridge
//
// The main app writes grade info into the App Group UserDefaults after each
// scan.  The widget reads it — no SwiftData sharing needed.

private let appGroup = "group.com.fullbars.shared"

private func readGradeFromDefaults() -> GradeEntry {
    guard let defaults = UserDefaults(suiteName: appGroup) else {
        return .placeholder
    }
    let letter    = defaults.string(forKey: "widgetGradeLetter") ?? "—"
    let score     = defaults.integer(forKey: "widgetGradeScore")
    let roomCount = defaults.integer(forKey: "widgetRoomCount")
    let homeName  = defaults.string(forKey: "widgetHomeName") ?? "FullBars"
    return GradeEntry(date: .now, letter: letter, score: score,
                      roomCount: roomCount, homeName: homeName)
}

// MARK: - Timeline entry

struct GradeEntry: TimelineEntry {
    let date: Date
    let letter: String      // "A" … "F" or "—"
    let score: Int           // 0-100
    let roomCount: Int
    let homeName: String

    static let placeholder = GradeEntry(
        date: .now, letter: "B", score: 82, roomCount: 4, homeName: "Home"
    )
}

// MARK: - Timeline provider

struct GradeProvider: TimelineProvider {
    func placeholder(in context: Context) -> GradeEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GradeEntry) -> Void) {
        completion(readGradeFromDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GradeEntry>) -> Void) {
        let entry = readGradeFromDefaults()
        // Refresh every 30 minutes — the grade only changes after a scan.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date)!
        completion(Timeline(entries: [entry], policy: .after(next)))
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
            GradeSmallView(entry: entry)
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
