import SwiftUI

/// Exportable grade report — generates a shareable card view.
struct GradeReportView: View {
    let grade: SpaceGrade
    let displayMode: DisplayMode

    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Shareable Card
                    reportCard
                        .padding(16)

                    // Export Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            captureAndShare()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share as Image")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(electricCyan.opacity(0.2))
                            .foregroundStyle(electricCyan)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            shareAsText()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                Text("Share as Text Report")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            exportPDF()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                Text("Export as PDF")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .navigationTitle("Grade Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: generateTextReport())
            }
        }
    }

    // MARK: - Report Card

    private var reportCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FullBars")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(electricCyan)
                    Text("WiFi Grade Report")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(formattedDate)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.2)

            // Grade
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(grade.grade.color.opacity(0.3), lineWidth: 6)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: grade.overallScore / 100)
                        .stroke(grade.grade.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text(grade.grade.rawValue)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(grade.grade.color)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(grade.grade.summary)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)

                    if displayMode == .technical {
                        Text("Score: \(String(format: "%.1f", grade.overallScore))/100")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(grade.grade.basicDescription)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            // Categories (compact)
            if displayMode == .technical {
                Divider().opacity(0.2)

                VStack(spacing: 6) {
                    ForEach(grade.categoryScores) { cat in
                        HStack {
                            Text(cat.category)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cat.color)
                                        .frame(width: geo.size.width * cat.score / 100, height: 6)
                                }
                            }
                            .frame(width: 80, height: 6)

                            Text(String(format: "%.0f", cat.score))
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(cat.color)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }

            // Quick stats
            Divider().opacity(0.2)

            HStack(spacing: 16) {
                reportStat(icon: "mappin.circle", value: "\(grade.pointCount)", label: "Points")
                reportStat(icon: "clock", value: formatDuration(grade.durationSeconds), label: "Duration")
                reportStat(icon: "wifi", value: "\(grade.averageSignalStrength) dBm", label: "Avg Signal")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.09, green: 0.11, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(grade.grade.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: grade.grade.color.opacity(0.15), radius: 16)
    }

    private func reportStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(electricCyan)
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Export

    private func captureAndShare() {
        // Generate text report and share
        showShareSheet = true
    }

    private func shareAsText() {
        showShareSheet = true
    }

    private func exportPDF() {
        let renderer = ImageRenderer(
            content: reportCard
                .frame(width: 380)
                .padding(20)
                .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        )
        renderer.scale = 2.0

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Grade_Report.pdf")
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    private func generateTextReport() -> String {
        var report = "📡 FullBars WiFi Grade Report\n"
        report += "================================\n\n"
        report += "Grade: \(grade.grade.rawValue) — \(grade.grade.summary)\n"
        report += "Score: \(String(format: "%.1f", grade.overallScore))/100\n\n"
        report += "\(grade.grade.basicDescription)\n\n"

        report += "📊 Category Breakdown:\n"
        for cat in grade.categoryScores {
            report += "  • \(cat.category): \(String(format: "%.0f", cat.score))/100\n"
        }

        report += "\n📈 Session Stats:\n"
        report += "  • Points: \(grade.pointCount)\n"
        report += "  • Duration: \(formatDuration(grade.durationSeconds))\n"
        report += "  • Avg Signal: \(grade.averageSignalStrength) dBm\n"
        report += "  • Avg Latency: \(String(format: "%.0f", grade.averageLatency)) ms\n"

        if !grade.roomGrades.isEmpty {
            report += "\n🏠 Room Grades:\n"
            for room in grade.roomGrades {
                report += "  • \(room.name): \(room.grade.rawValue) (\(room.averageSignal) dBm)\n"
            }
        }

        report += "\n— Generated by FullBars"
        return report
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: grade.timestamp)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

