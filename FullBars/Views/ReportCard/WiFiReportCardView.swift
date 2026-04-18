import SwiftUI

/// A shareable WiFi Report Card — the "Carfax" for a space's connectivity.
/// Can be exported as an image for sharing on social media, messaging, or email.
struct WiFiReportCardView: View {
    let grade: SpaceGrade
    let ssid: String
    let displayMode: DisplayMode
    let generatedDate: Date

    @State private var showShareSheet = false
    @State private var showPDFShareSheet = false
    @Environment(\.displayMode) private var envDisplayMode

    private let electricCyan = FullBars.Design.Colors.accentCyan

    init(grade: SpaceGrade, ssid: String = "Unknown",
         displayMode: DisplayMode = .basic,
         generatedDate: Date = .now) {
        self.grade = grade
        self.ssid = ssid
        self.displayMode = displayMode
        self.generatedDate = generatedDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                reportContent
                    .padding(20)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .navigationTitle("WiFi Report Card")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showShareSheet = true } label: {
                            Label("Share as Text", systemImage: "square.and.arrow.up")
                        }
                        Button { exportPDF() } label: {
                            Label("Export as PDF", systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: generateTextReport())
            }
        }
    }

    // MARK: - Report Content

    private var reportContent: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "wifi")
                        .font(.title3)
                        .foregroundStyle(electricCyan)
                    Text("WiFi Report Card")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                }

                HStack {
                    Text("Network: \(ssid)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(generatedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .background(FullBars.Design.Colors.cardSurface)

            // Big Grade
            VStack(spacing: 8) {
                Text(grade.grade.rawValue)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(grade.grade.color)
                    .shadow(color: grade.grade.color.opacity(0.5), radius: 20)

                Text(grade.grade.summary)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(grade.grade.basicDescription)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [grade.grade.color.opacity(0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // Category Scores
            VStack(spacing: 12) {
                Text("Category Breakdown")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(electricCyan)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(grade.categoryScores) { cat in
                    HStack(spacing: 12) {
                        Text(cat.category)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 110, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 10)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(cat.color)
                                    .frame(width: geo.size.width * cat.score / 100, height: 10)
                            }
                        }
                        .frame(height: 10)

                        Text(GradeLetter.from(score: cat.score).rawValue)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(cat.color)
                            .frame(width: 24)
                    }
                }
            }
            .padding(20)

            // Room-by-Room (if available)
            if !grade.roomGrades.isEmpty {
                VStack(spacing: 12) {
                    Text("Room-by-Room")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(electricCyan)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(grade.roomGrades) { room in
                            HStack(spacing: 8) {
                                Text(room.grade.rawValue)
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(room.grade.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name)
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.semibold)
                                    Text("\(room.averageSignal) dBm (est.)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }

            // Key Stats
            VStack(spacing: 12) {
                Text("Key Metrics")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(electricCyan)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    metricBadge(label: "Signal", value: "\(grade.averageSignalStrength)", unit: "dBm")
                    metricBadge(label: "Latency", value: String(format: "%.0f", grade.averageLatency), unit: "ms")
                    if grade.averageDownloadSpeed > 0 {
                        metricBadge(label: "Speed", value: String(format: "%.0f", grade.averageDownloadSpeed), unit: "Mbps")
                    }
                    metricBadge(label: "Points", value: "\(grade.pointCount)", unit: "sampled")
                }
            }
            .padding(20)

            // Footer
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(electricCyan)
                Text("Scanned by FullBars")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Score: \(String(format: "%.0f", grade.overallScore))/100")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(grade.grade.color)
            }
            .padding(20)
            .background(FullBars.Design.Colors.cardSurface)
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.09))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(grade.grade.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: grade.grade.color.opacity(0.15), radius: 16)
    }

    // MARK: - Components

    private func metricBadge(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(electricCyan.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }

    // MARK: - PDF Export

    private func exportPDF() {
        let renderer = ImageRenderer(
            content: reportContent
                .frame(width: 380)
                .padding(20)
                .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        )
        renderer.scale = 2.0

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WiFi_Report_Card.pdf")
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

    // MARK: - Text Report for Sharing

    private func generateTextReport() -> String {
        var r = "📶 WiFi Report Card\n"
        r += "Network: \(ssid)\n"
        r += "Date: \(generatedDate.formatted(date: .abbreviated, time: .shortened))\n\n"
        r += "Overall Grade: \(grade.grade.rawValue) (\(String(format: "%.0f", grade.overallScore))/100)\n"
        r += "\(grade.grade.basicDescription)\n\n"

        r += "Category Scores:\n"
        for cat in grade.categoryScores {
            r += "  \(cat.category): \(GradeLetter.from(score: cat.score).rawValue) (\(String(format: "%.0f", cat.score)))\n"
        }

        if !grade.roomGrades.isEmpty {
            r += "\nRoom-by-Room:\n"
            for room in grade.roomGrades {
                r += "  \(room.name): \(room.grade.rawValue) (avg \(room.averageSignal) dBm)\n"
            }
        }

        r += "\nKey Metrics:\n"
        r += "  Avg Signal: \(grade.averageSignalStrength) dBm (est.)\n"
        r += "  Avg Latency: \(String(format: "%.0f", grade.averageLatency)) ms\n"
        if grade.averageDownloadSpeed > 0 {
            r += "  Avg Speed: \(String(format: "%.1f", grade.averageDownloadSpeed)) Mbps\n"
        }
        r += "  Points Sampled: \(grade.pointCount)\n"
        r += "\nScanned by FullBars"
        return r
    }
}

#Preview {
    WiFiReportCardView(
        grade: SpaceGrade(
            overallScore: 82,
            signalCoverageScore: 88,
            speedPerformanceScore: 75,
            reliabilityScore: 90,
            latencyScore: 72,
            interferenceScore: 85,
            pointCount: 42,
            durationSeconds: 95,
            averageSignalStrength: -58,
            averageLatency: 34,
            averageDownloadSpeed: 67
        ),
        ssid: "MyHomeWiFi"
    )
    .preferredColorScheme(.dark)
}
