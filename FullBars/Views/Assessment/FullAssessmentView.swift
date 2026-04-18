import SwiftUI
import SwiftData

/// Combined speed test + home scan flow.
/// Steps: intro -> speed test -> walkthrough -> results summary.
enum AssessmentPhase: CaseIterable {
    case intro, speedTest, walkthrough, results
}

struct FullAssessmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var phase: AssessmentPhase = .intro
    @State private var speedService = SpeedTestService()
    @State private var speedResult: SpeedTestResult?
    @State private var walkthroughComplete = false
    @State private var sessionId = UUID()
    @State private var showPaywall = false

    @Query(sort: \HeatmapPoint.timestamp, order: .reverse) private var allPoints: [HeatmapPoint]

    private let profile = UserProfile()
    private let subscription = SubscriptionManager.shared
    private let primary = FullBars.Design.Colors.accentCyan

    private var sessionPoints: [HeatmapPoint] {
        allPoints.filter { $0.sessionId == sessionId }
    }

    var body: some View {
        ZStack {
            FullBars.Design.Colors.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                assessmentProgress
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                Group {
                    switch phase {
                    case .intro:      introPhase
                    case .speedTest:  speedTestPhase
                    case .walkthrough: walkthroughPhase
                    case .results:    resultsPhase
                    }
                }
                .transition(.opacity)

                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(phase == .speedTest && speedService.isRunning)
        .sheet(isPresented: $showPaywall) { ProPaywallView() }
    }

    // MARK: - Progress

    private var assessmentProgress: some View {
        HStack(spacing: 8) {
            ForEach(Array(AssessmentPhase.allCases.enumerated()), id: \.offset) { idx, p in
                let isCurrent = p == phase
                let isDone = AssessmentPhase.allCases.firstIndex(of: p)! < AssessmentPhase.allCases.firstIndex(of: phase)!
                Capsule()
                    .fill(isDone || isCurrent ? primary : Color.white.opacity(0.15))
                    .frame(height: 4)
                    .animation(.easeInOut, value: phase)
            }
        }
    }

    // MARK: - Intro

    private var introPhase: some View {
        VStack(spacing: 24) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 64))
                .foregroundStyle(primary)

            Text("Full WiFi Assessment")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("We'll run a speed test, then walk you through each room. Takes about 5 minutes.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                phaseRow("1", "Speed test — ~30 seconds", "speedometer")
                phaseRow("2", "Room-by-room scan — ~15 sec per room", "figure.walk.motion")
                phaseRow("3", "Your WiFi grade and report", "chart.bar.fill")
            }
            .padding(18)
            .background(cardBackground)

            Button {
                withAnimation { phase = .speedTest }
                Task { await runSpeedTest() }
            } label: {
                Text("Start Assessment")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius).fill(primary))
            }
            .padding(.horizontal, 20)
        }
        .padding(20)
    }

    private func phaseRow(_ num: String, _ text: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(primary.opacity(0.2)).frame(width: 28, height: 28)
                Text(num).font(.system(.caption, design: .rounded)).fontWeight(.bold).foregroundStyle(primary)
            }
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(primary)
                .frame(width: 20)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Speed Test

    private var speedTestPhase: some View {
        VStack(spacing: 28) {
            Text("Running Speed Test")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)

            if speedService.isRunning {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 10)
                            .frame(width: 180, height: 180)
                        Circle()
                            .trim(from: 0, to: speedService.progress)
                            .stroke(primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.3), value: speedService.progress)
                        VStack(spacing: 4) {
                            Text(speedService.currentPhase.replacingOccurrences(of: "...", with: ""))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(Int(speedService.progress * 100))%")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            } else if let result = speedResult {
                // Speed test done — show quick results
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    HStack(spacing: 32) {
                        speedStat("Download", "\(Int(result.downloadSpeed))", "Mbps")
                        speedStat("Upload", "\(Int(result.uploadSpeed))", "Mbps")
                        speedStat("Latency", "\(Int(result.latency))", "ms")
                    }
                    .padding(18)
                    .background(cardBackground)

                    Button {
                        withAnimation { phase = .walkthrough }
                    } label: {
                        Text("Continue to Room Scan")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius).fill(primary))
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(20)
    }

    private func speedStat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Walkthrough

    private var walkthroughPhase: some View {
        // Embed the guided walkthrough inside the assessment
        GuidedWalkthroughView()
    }

    // MARK: - Results

    private var resultsPhase: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(primary)

            Text("Assessment Complete")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)

            if let result = speedResult {
                VStack(spacing: 12) {
                    resultRow("Download Speed", "\(Int(result.downloadSpeed)) Mbps")
                    resultRow("Upload Speed", "\(Int(result.uploadSpeed)) Mbps")
                    resultRow("Latency", "\(Int(result.latency)) ms")
                    if profile.ispPromisedSpeed > 0 {
                        let pct = Int((result.downloadSpeed / profile.ispPromisedSpeed) * 100)
                        resultRow("ISP Delivery", "\(pct)% of promised \(Int(profile.ispPromisedSpeed)) Mbps")
                    }
                }
                .padding(18)
                .background(cardBackground)
            }

            Text("Check your Dashboard to see your updated WiFi grade.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius).fill(primary))
            }
            .padding(.horizontal, 20)
        }
        .padding(20)
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Actions

    private func runSpeedTest() async {
        if let result = await speedService.runFullTest() {
            await MainActor.run {
                speedResult = result
                // Persist result
                let record = SpeedTestResult(
                    timestamp: result.timestamp,
                    downloadSpeed: result.downloadSpeed,
                    uploadSpeed: result.uploadSpeed,
                    latency: result.latency,
                    jitter: result.jitter,
                    packetLoss: result.packetLoss,
                    serverName: result.serverName,
                    serverLocation: result.serverLocation
                )
                modelContext.insert(record)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium)
            .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
            .overlay(RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusMedium).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
