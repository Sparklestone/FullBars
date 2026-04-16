import SwiftUI

/// "How Grades Work" explainer sheet that breaks down the A-F grading system
/// so users understand what each grade means and how scores are calculated.
struct GradeExplainerView: View {
    @Environment(\.dismiss) private var dismiss

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(electricCyan)
                            .shadow(color: electricCyan.opacity(0.4), radius: 12)

                        Text("How Grades Work")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("FullBars grades your WiFi like a report card — from A (excellent) to F (failing).")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 12)

                    // Grade scale
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Scale")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(electricCyan)
                            .padding(.horizontal, 16)

                        ForEach(GradeLetter.allCases, id: \.self) { grade in
                            gradeRow(grade)
                        }
                        .padding(.horizontal, 16)
                    }

                    // What's measured
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What We Measure")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(electricCyan)
                            .padding(.horizontal, 16)

                        categoryRow(icon: "wifi", title: "Signal Coverage", weight: "30%",
                                    detail: "How strong and consistent your WiFi signal is across the scanned area.")
                        categoryRow(icon: "speedometer", title: "Speed", weight: "25%",
                                    detail: "Download and upload performance relative to what's needed for common tasks.")
                        categoryRow(icon: "checkmark.shield", title: "Reliability", weight: "20%",
                                    detail: "Packet loss and jitter — how stable your connection stays over time.")
                        categoryRow(icon: "clock", title: "Latency", weight: "15%",
                                    detail: "Response time. Lower is better, especially for video calls and gaming.")
                        categoryRow(icon: "antenna.radiowaves.left.and.right", title: "Interference", weight: "10%",
                                    detail: "Nearby devices competing for the same frequency bands as your WiFi.")
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for a Better Grade")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(electricCyan)
                            .padding(.horizontal, 16)

                        tipRow(number: 1, text: "Walk your entire space during a walkthrough — don't skip corners or rooms far from the router.")
                        tipRow(number: 2, text: "Run a speed test before and after making changes to see real improvement.")
                        tipRow(number: 3, text: "If you score below C, check Diagnostics for specific issues and fix suggestions.")
                    }

                    Spacer().frame(height: 24)
                }
                .padding(.vertical, 16)
            }
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(electricCyan)
                }
            }
        }
    }

    // MARK: - Components

    private func gradeRow(_ grade: GradeLetter) -> some View {
        let range: String = {
            switch grade {
            case .A: return "90–100"
            case .B: return "80–89"
            case .C: return "70–79"
            case .D: return "60–69"
            case .F: return "Below 60"
            }
        }()

        return HStack(spacing: 14) {
            Text(grade.rawValue)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(grade.color)
                .frame(width: 40)
                .shadow(color: grade.color.opacity(0.4), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(grade.summary)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("(\(range))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(grade.basicDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func categoryRow(icon: String, title: String, weight: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(electricCyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(weight)
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(electricCyan.opacity(0.2))
                        .foregroundStyle(electricCyan)
                        .cornerRadius(4)
                }
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func tipRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .frame(width: 24, height: 24)
                .background(electricCyan.opacity(0.2))
                .foregroundStyle(electricCyan)
                .clipShape(Circle())

            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    GradeExplainerView()
}
