import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Shareable Wi-Fi quality "badge" — a Pro feature. Aimed at rental hosts
/// (Airbnb, VRBO) and people selling homes who want a credible, third-party
/// looking badge proving their internet is fast everywhere. Includes a QR
/// that encodes a short URL with the badge data.
struct ShareBadgeView: View {
    let home: HomeConfiguration
    let rooms: [Room]

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var isShareSheetPresented = false

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    // MARK: - Derived

    private var overallScore: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.gradeScore } / Double(rooms.count)
    }
    private var overallLetter: String {
        switch overallScore {
        case 90...:   return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default:      return "F"
        }
    }
    private var avgDownload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.downloadMbps } / Double(rooms.count)
    }
    private var avgUpload: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.uploadMbps } / Double(rooms.count)
    }
    private var avgPing: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.reduce(0.0) { $0 + $1.pingMs } / Double(rooms.count)
    }
    private var planDeliveredPercent: Int {
        guard home.ispPromisedDownloadMbps > 0 else { return 0 }
        return Int((avgDownload / home.ispPromisedDownloadMbps) * 100)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Share your Wi-Fi badge")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.top, 8)

                        Text("Great for rental listings, home sale pages, and anyone who cares that the Wi-Fi actually works.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        badge
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: BadgeSizeKey.self, value: geo.size)
                                }
                            )

                        Button {
                            renderAndShare()
                        } label: {
                            Label("Export & share", systemImage: "square.and.arrow.up")
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(cyan)
                                .foregroundStyle(.black)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(cyan)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $isShareSheetPresented) {
                if let img = renderedImage {
                    ImageShareSheet(items: [img])
                }
            }
        }
    }

    // MARK: - Badge card

    /// The visual badge. ViewThatFits / fixed size so it renders predictably
    /// when we snapshot it.
    private var badge: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wifi")
                    .font(.headline)
                    .foregroundStyle(.black)
                Text("Verified Wi-Fi")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.black)
                Spacer()
                Text("FULLBARS")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(cyan)

            // Body — dark
            VStack(spacing: 18) {
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 10)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: CGFloat(overallScore / 100))
                            .stroke(gradeColor(overallLetter),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: -2) {
                            Text(overallLetter)
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundStyle(gradeColor(overallLetter))
                            Text("\(Int(overallScore))")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(home.name)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(home.squareFootage) sq ft · \(rooms.count) room\(rooms.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !home.ispName.isEmpty {
                            Text(home.ispName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 0) {
                    statColumn(value: "\(Int(avgDownload))", unit: "Mbps ↓", color: .green)
                    divider
                    statColumn(value: "\(Int(avgUpload))", unit: "Mbps ↑", color: .blue)
                    divider
                    statColumn(value: "\(Int(avgPing))", unit: "ms ping", color: .yellow)
                }

                if home.ispPromisedDownloadMbps > 0 {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(cyan)
                        Text("Delivering \(planDeliveredPercent)% of the \(Int(home.ispPromisedDownloadMbps)) Mbps plan")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(alignment: .center, spacing: 14) {
                    if let qr = qrImage() {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 74, height: 74)
                            .padding(6)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan to verify")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Measured on \(formattedDate())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Per-room scan · FullBars")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(18)
            .background(Color(red: 0.08, green: 0.08, blue: 0.13))
        }
        .frame(width: 340)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 32)
    }

    private func statColumn(value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR

    private func qrImage() -> UIImage? {
        let payload = badgePayloadString()
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgimg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }

    private func badgePayloadString() -> String {
        // Compact payload — in a later pass this could be a hosted verification URL.
        var parts: [String] = []
        parts.append("grade=\(overallLetter)")
        parts.append("score=\(Int(overallScore))")
        parts.append("dl=\(Int(avgDownload))")
        parts.append("ul=\(Int(avgUpload))")
        parts.append("ping=\(Int(avgPing))")
        parts.append("rooms=\(rooms.count)")
        parts.append("sqft=\(home.squareFootage)")
        if !home.ispName.isEmpty {
            let clean = home.ispName.replacingOccurrences(of: " ", with: "+")
            parts.append("isp=\(clean)")
        }
        let query = parts.joined(separator: "&")
        return "https://fullbars.app/verify?\(query)"
    }

    // MARK: - Render & share

    private func renderAndShare() {
        let renderer = ImageRenderer(content:
            badge
                .padding(20)
                .background(bg)
        )
        renderer.scale = UIScreen.main.scale
        if let img = renderer.uiImage {
            renderedImage = img
            isShareSheetPresented = true
        }
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

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: .now)
    }
}

private struct BadgeSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Image-sharing wrapper for UIActivityViewController. Separate from
/// Views/Components/ShareSheet.swift (which is string-only).
struct ImageShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
