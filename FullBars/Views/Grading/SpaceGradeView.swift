import SwiftUI

/// Displays the A-F space grade with animated visuals.
/// Adapts presentation based on Basic vs Technical display mode.
struct SpaceGradeView: View {
    let grade: SpaceGrade
    let displayMode: DisplayMode

    @State private var animateGrade = false
    @State private var animateCategories = false
    @State private var showReport = false
    @State private var showExplainer = false

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main Grade Display
                gradeHero
                    .padding(.top, 20)

                // Summary text
                Text(grade.grade.basicDescription)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if displayMode == .technical {
                    // Numeric score
                    HStack(spacing: 8) {
                        Text("Score:")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", grade.overallScore))
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(grade.grade.color)
                        Text("/ 100")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    // Category Breakdown
                    categoryBreakdown

                    // Per-room grades
                    if !grade.roomGrades.isEmpty {
                        roomGradesSection
                    }

                    // Session stats
                    sessionStats
                }

                // How Grades Work
                Button(action: { showExplainer = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                        Text("How are grades calculated?")
                            .font(.system(.caption, design: .rounded))
                    }
                    .foregroundStyle(electricCyan.opacity(0.7))
                }

                // Export Button
                Button(action: { showReport = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Grade Report")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(electricCyan.opacity(0.2))
                    .foregroundStyle(electricCyan)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 32)
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        .navigationTitle("Space Grade")
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                animateGrade = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateCategories = true
            }
        }
        .sheet(isPresented: $showReport) {
            GradeReportView(grade: grade, displayMode: displayMode)
        }
        .sheet(isPresented: $showExplainer) {
            GradeExplainerView()
        }
    }

    // MARK: - Grade Hero

    private var gradeHero: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(grade.grade.color.opacity(0.2), lineWidth: 8)
                .frame(width: 180, height: 180)
                .shadow(color: grade.grade.color.opacity(0.3), radius: 20)

            // Progress ring
            Circle()
                .trim(from: 0, to: animateGrade ? grade.overallScore / 100 : 0)
                .stroke(
                    LinearGradient(
                        colors: [grade.grade.color, grade.grade.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .shadow(color: grade.grade.color.opacity(0.5), radius: 12)

            // Grade letter
            VStack(spacing: 4) {
                Text(grade.grade.rawValue)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(grade.grade.color)
                    .shadow(color: grade.grade.color.opacity(0.6), radius: 16)
                    .scaleEffect(animateGrade ? 1 : 0.5)
                    .opacity(animateGrade ? 1 : 0)

                Text(grade.grade.summary)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(electricCyan)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(grade.categoryScores) { category in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.category)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                            Text("\(Int(category.weight * 100))% weight")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Score bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(category.color)
                                    .frame(
                                        width: animateCategories ? geo.size.width * category.score / 100 : 0,
                                        height: 8
                                    )
                                    .shadow(color: category.color.opacity(0.4), radius: 4)
                            }
                        }
                        .frame(width: 100, height: 8)

                        Text(String(format: "%.0f", category.score))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(category.color)
                            .frame(width: 35, alignment: .trailing)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Room Grades

    private var roomGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Grades")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(electricCyan)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(grade.roomGrades) { room in
                    VStack(spacing: 8) {
                        Text(room.grade.rawValue)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(room.grade.color)

                        Text(room.name)
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)

                        Text("\(room.averageSignal) dBm avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: room.grade.color.opacity(0.15), radius: 8)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Session Stats

    private var sessionStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(electricCyan)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                statRow("Points Collected", value: "\(grade.pointCount)")
                statRow("Duration", value: formatDuration(grade.durationSeconds))
                statRow("Avg Signal", value: "\(grade.averageSignalStrength) dBm (est.)")
                statRow("Avg Latency", value: String(format: "%.0f ms", grade.averageLatency))
                if grade.averageDownloadSpeed > 0 {
                    statRow("Avg Download", value: String(format: "%.1f Mbps", grade.averageDownloadSpeed))
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
