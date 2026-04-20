import SwiftUI
import SwiftData

/// Shareable ISP report card — grades measured WiFi performance.
/// Designed to be screenshot-friendly for social sharing.
struct ISPReportCardView: View {
    @Query(sort: \SpeedTestResult.timestamp, order: .reverse) private var speedResults: [SpeedTestResult]
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false

    private let ispName = UserProfile().ispName
    private let primary = FullBars.Design.Colors.accentCyan

    private var recentResults: [SpeedTestResult] {
        Array(speedResults.prefix(10))
    }

    private var avgDownload: Double {
        guard !recentResults.isEmpty else { return 0 }
        return recentResults.map(\.downloadSpeed).reduce(0, +) / Double(recentResults.count)
    }

    private var avgUpload: Double {
        guard !recentResults.isEmpty else { return 0 }
        return recentResults.map(\.uploadSpeed).reduce(0, +) / Double(recentResults.count)
    }

    private var avgLatency: Double {
        guard !recentResults.isEmpty else { return 0 }
        return recentResults.map(\.latency).reduce(0, +) / Double(recentResults.count)
    }

    /// Grade WiFi performance on absolute speed tiers (no promised speed needed).
    private var performanceGrade: String {
        switch avgDownload {
        case 100...: return "A"
        case 50..<100: return "B"
        case 25..<50: return "C"
        case 10..<25: return "D"
        default: return "F"
        }
    }

    private var performanceColor: Color {
        switch avgDownload {
        case 100...: return .green
        case 50..<100: return Color(red: 0.6, green: 0.8, blue: 0.2)
        case 25..<50: return .yellow
        case 10..<25: return .orange
        default: return .red
        }
    }

    /// Friendly description of the speed tier.
    private var performanceTier: String {
        switch avgDownload {
        case 100...: return "Excellent — 4K streaming, large downloads, no lag"
        case 50..<100: return "Good — HD streaming, video calls, multi-device"
        case 25..<50: return "Fair — browsing and SD streaming, may stutter with load"
        case 10..<25: return "Poor — basic browsing only, slow downloads"
        default: return "Very Poor — frequent buffering and timeouts"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    reportCard
                        .padding(16)

                    // Share actions
                    VStack(spacing: 12) {
                        Button {
                            captureAndShare()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share ISP Report Card")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(primary))
                        }

                        Button {
                            exportPDF()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                Text("Export as PDF")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).stroke(primary, lineWidth: 1.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .background(FullBars.Design.Colors.primaryBackground)
            .navigationTitle("ISP Report Card")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderCardAsImage() {
                    ShareSheet(activityItems: [image])
                }
            }
        }
    }

    // MARK: - Report Card

    @ViewBuilder
    private var reportCard: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(primary)
                    Text(ispName.isEmpty ? "Your ISP" : ispName)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Report Card")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text("Based on \(recentResults.count) speed test\(recentResults.count == 1 ? "" : "s")")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(Color(red: 0.08, green: 0.10, blue: 0.14))

            Divider().background(Color.white.opacity(0.1))

            // Grade circle
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: min(1.0, avgDownload / 150.0))
                        .stroke(performanceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    Text(performanceGrade)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(performanceColor)
                }

                Text("WiFi Performance")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))

                Text(performanceTier)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.1))

            // Measured metrics
            VStack(spacing: 14) {
                metricRow(
                    label: "Download Speed",
                    value: "\(Int(avgDownload)) Mbps",
                    isGood: avgDownload >= 50
                )
                metricRow(
                    label: "Upload Speed",
                    value: "\(Int(avgUpload)) Mbps",
                    isGood: avgUpload >= 10
                )
                metricRow(
                    label: "Latency",
                    value: "\(Int(avgLatency)) ms",
                    isGood: avgLatency < 30
                )
            }
            .padding(18)

            Divider().background(Color.white.opacity(0.1))

            // Footer
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(primary)
                Text("FullBars")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(primary)
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(Color(red: 0.06, green: 0.07, blue: 0.10))
        }
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func metricRow(label: String, value: String, isGood: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(isGood ? .green : .orange)
        }
    }

    // MARK: - Export

    private func renderCardAsImage() -> UIImage? {
        let renderer = ImageRenderer(content: reportCard.frame(width: 380).padding(20).background(FullBars.Design.Colors.primaryBackground))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private func captureAndShare() {
        showShareSheet = true
    }

    private func exportPDF() {
        guard let image = renderCardAsImage(), let data = image.pngData() else { return }
        let renderer = ImageRenderer(content: reportCard.frame(width: 380).padding(20).background(FullBars.Design.Colors.primaryBackground))
        renderer.scale = 2.0

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ISP_Report_Card.pdf")
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
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
