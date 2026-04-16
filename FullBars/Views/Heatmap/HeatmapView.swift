import SwiftUI
import SwiftData

struct HeatmapView: View {
    @State var viewModel = HeatmapViewModel()
    @State private var pulseAnimation = false
    @State private var showSetup = false
    @State private var showPaywall = false
    @State private var hasUsedWalkthrough = UserDefaults.standard.bool(forKey: "hasUsedWalkthrough")
    @State private var subscription = SubscriptionManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayMode) private var displayMode

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mode Selector
                    if viewModel.isARAvailable {
                        Picker("Mode", selection: $viewModel.walkthroughMode) {
                            ForEach(WalkthroughMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .disabled(viewModel.isRecording)
                    }

                    if viewModel.isRecording && viewModel.walkthroughMode == .ar && viewModel.isARAvailable {
                        // AR Camera View
                        ZStack {
                            ARWalkthroughView(
                                arService: viewModel.arService,
                                signalPoints: viewModel.heatmapPoints,
                                displayMode: displayMode
                            )
                            .ignoresSafeArea(edges: .horizontal)

                            ARHUDOverlay(
                                signalStrength: viewModel.currentSignalStrength,
                                duration: viewModel.recordingDuration,
                                pointCount: viewModel.pointCount,
                                trackingState: viewModel.arService.trackingState,
                                displayMode: displayMode
                            )
                        }
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.markerPlacedFeedback)
                    }

                    ScrollView {
                        VStack(spacing: 16) {
                            // Recording Controls
                            recordingControls
                                .padding(.horizontal, 16)

                            // Stats Card
                            statsCard
                                .padding(.horizontal, 16)

                            // Visualization
                            if viewModel.pointCount > 0 && !viewModel.isRecording {
                                // Show floor plan for completed sessions
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Floor Plan")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(electricCyan)

                                    FloorPlanView(
                                        points: viewModel.heatmapPoints,
                                        walls: viewModel.roomPlanService.walls,
                                        rooms: viewModel.roomPlanService.rooms,
                                        displayMode: displayMode
                                    )
                                    .frame(height: 300)
                                }
                                .padding(.horizontal, 16)
                            } else if !viewModel.isRecording && viewModel.walkthroughMode != .ar {
                                // 2D canvas for non-AR recording
                                canvasVisualization
                                    .padding(.horizontal, 16)
                            } else if viewModel.pointCount == 0 && !viewModel.isRecording {
                                emptyState
                                    .padding(.horizontal, 16)
                            }

                            // Save Button
                            if !viewModel.isRecording && viewModel.pointCount > 0 {
                                Button(action: {
                                    viewModel.saveSession(context: modelContext)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save Session")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(electricCyan.opacity(0.2))
                                    .foregroundStyle(electricCyan)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 16)
                            }

                            Spacer().frame(height: 20)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("AR Walkthrough")
            .sheet(isPresented: $showPaywall) { ProPaywallView() }
            .onAppear {
                if !subscription.isPro { showPaywall = true }
            }
            .sheet(isPresented: $showSetup) {
                WalkthroughSetupView(onStart: {
                    showSetup = false
                    hasUsedWalkthrough = true
                    UserDefaults.standard.set(true, forKey: "hasUsedWalkthrough")
                    viewModel.startRecording()
                    pulseAnimation = true
                })
            }
            .sheet(isPresented: $viewModel.showGradeResult) {
                if let grade = viewModel.currentGrade {
                    NavigationStack {
                        SpaceGradeView(grade: grade, displayMode: displayMode)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        viewModel.showGradeResult = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var recordingControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                    pulseAnimation = false
                } else if !hasUsedWalkthrough {
                    showSetup = true
                } else {
                    viewModel.startRecording()
                    pulseAnimation = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(
                            pulseAnimation ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                            value: pulseAnimation
                        )
                    Text(viewModel.isRecording ? "Stop Walkthrough" : "Start Walkthrough")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.isRecording ? Color.red.opacity(0.2) : electricCyan.opacity(0.2))
                .foregroundStyle(viewModel.isRecording ? .red : electricCyan)
                .cornerRadius(12)
            }
            .sensoryFeedback(.selection, trigger: viewModel.isRecording)
            .accessibilityLabel(viewModel.isRecording ? "Stop walkthrough" : "Start walkthrough")

            if viewModel.isRecording || viewModel.pointCount > 0 {
                Button(action: { viewModel.clearSession() }) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.red)
                }
                .accessibilityLabel("Clear session")
            }
        }
    }

    private var statsCard: some View {
        HStack(spacing: 16) {
            statItem(title: "Duration", value: formatDuration(viewModel.recordingDuration), color: electricCyan)

            Divider().opacity(0.3)

            statItem(title: "Points", value: "\(viewModel.pointCount)", color: electricCyan)

            Divider().opacity(0.3)

            if displayMode == .technical {
                statItem(
                    title: "Signal",
                    value: "\(viewModel.currentSignalStrength) dBm (est.)",
                    color: signalColor(viewModel.currentSignalStrength)
                )
            } else {
                statItem(
                    title: "Signal",
                    value: signalLabel(viewModel.currentSignalStrength),
                    color: signalColor(viewModel.currentSignalStrength)
                )
            }

            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: electricCyan.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private var canvasVisualization: some View {
        VStack(spacing: 12) {
            Text(viewModel.isRecording ? "Live Heatmap" : (viewModel.pointCount > 0 ? "Session Summary" : "No Data"))
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(electricCyan)

            if viewModel.pointCount > 0 {
                Canvas { context, _ in
                    let width: CGFloat = 300
                    let height: CGFloat = 300
                    let cellSize = width / 10

                    for i in 0..<11 {
                        let x = CGFloat(i) * cellSize
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                        context.stroke(path, with: .color(Color.white.opacity(0.1)))
                    }
                    for i in 0..<11 {
                        let y = CGFloat(i) * cellSize
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                        context.stroke(path, with: .color(Color.white.opacity(0.1)))
                    }

                    for point in viewModel.heatmapPoints {
                        let normalizedX = min(max(CGFloat((point.x + 5) / 10), 0), 1) * width
                        let normalizedY = min(max(CGFloat((point.z + 5) / 10), 0), 1) * height
                        let color = signalColor(point.signalStrength)

                        let glowRect = CGRect(x: normalizedX - 12, y: normalizedY - 12, width: 24, height: 24)
                        context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.2)))

                        let rect = CGRect(x: normalizedX - 8, y: normalizedY - 8, width: 16, height: 16)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
                .frame(height: 300)
                .background(Color(red: 0.1, green: 0.1, blue: 0.15))
                .cornerRadius(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(electricCyan.opacity(0.5))

            Text(displayMode == .basic
                ? "Start an AR walkthrough to see WiFi coverage mapped onto your floor plan"
                : "Start a walkthrough to map signal strength with AR and LiDAR"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private func signalColor(_ strength: Int) -> Color {
        switch strength {
        case -50...(-1): return .green
        case -60...(-51): return FullBars.Design.Colors.accentCyan
        case -70...(-61): return .yellow
        case -80...(-71): return .orange
        default: return .red
        }
    }

    private func signalLabel(_ strength: Int) -> String {
        switch strength {
        case -50...(-1): return "Strong"
        case -60...(-51): return "Good"
        case -70...(-61): return "Fair"
        case -80...(-71): return "Weak"
        default: return "Poor"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    HeatmapView()
        .environment(\.displayMode, .technical)
}
