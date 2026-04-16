import SwiftUI
import SwiftData

struct ActionItemsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \ActionItem.priority) var actionItems: [ActionItem]

    @State private var showShareSheet = false

    private let electricCyan = FullBars.Design.Colors.accentCyan
    private let emerald = Color(red: 0.3, green: 1, blue: 0.6)

    var completedCount: Int {
        actionItems.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        actionItems.count
    }

    var itemsByPriority: [Int: [ActionItem]] {
        Dictionary(grouping: actionItems) { $0.priority }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Header
                    if totalCount > 0 {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Progress")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(completedCount) of \(totalCount)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(electricCyan)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [electricCyan, emerald]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0))
                                        .shadow(color: electricCyan.opacity(0.4), radius: 8, x: 0, y: 2)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(16)
                    }

                    // Use List for proper swipe action support
                    List {
                        ForEach([1, 2, 3], id: \.self) { priority in
                            let items = itemsByPriority[priority] ?? []
                            if !items.isEmpty {
                                Section {
                                    ForEach(items) { item in
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    item.isCompleted.toggle()
                                                    try? modelContext.save()
                                                }
                                            }) {
                                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(item.isCompleted ? electricCyan : .gray)
                                                    .font(.system(size: 18))
                                                    .scaleEffect(item.isCompleted ? 1.15 : 1.0)
                                            }
                                            .buttonStyle(.plain)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.title)
                                                    .font(.system(.subheadline, design: .rounded))
                                                    .fontWeight(.semibold)
                                                    .strikethrough(item.isCompleted)
                                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                                                if !item.itemDescription.isEmpty {
                                                    Text(item.itemDescription)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .listRowBackground(FullBars.Design.Colors.cardSurface)
                                    }
                                } header: {
                                    HStack(spacing: 8) {
                                        Text(priorityLabel(priority))
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundStyle(priorityColor(priority))
                                        Text("\(items.count)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(priorityColor(priority).opacity(0.2))
                                            .foregroundStyle(priorityColor(priority))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)

                    // Share Button
                    if totalCount > 0 {
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share with ISP")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(electricCyan.opacity(0.2))
                            .foregroundStyle(electricCyan)
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .shadow(color: electricCyan.opacity(0.1), radius: 8, x: 0, y: 4)
                        .accessibilityLabel("Share action items with ISP")
                    }
                }
            }
            .navigationTitle("Action Items")
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: generateReport())
            }
        }
    }

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1: return "High"
        case 2: return "Medium"
        case 3: return "Low"
        default: return "Unknown"
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        default: return electricCyan
        }
    }

    private func generateReport() -> String {
        var report = "FullBars Action Items Report\n"
        report += "Generated: \(Date().formatted())\n\n"
        report += "Progress: \(completedCount)/\(totalCount)\n\n"

        for priority in [1, 2, 3] {
            let items = itemsByPriority[priority] ?? []
            if !items.isEmpty {
                report += "\n\(priorityLabel(priority)) Priority:\n"
                for item in items {
                    let status = item.isCompleted ? "[x]" : "[ ]"
                    report += "\(status) \(item.title)\n"
                    if !item.itemDescription.isEmpty {
                        report += "    \(item.itemDescription)\n"
                    }
                }
            }
        }

        return report
    }
}

#Preview {
    ActionItemsView()
        .modelContainer(for: ActionItem.self, inMemory: true)
}
