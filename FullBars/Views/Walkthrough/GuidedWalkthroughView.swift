import SwiftUI
import SwiftData

// Guided room-by-room WiFi capture flow.
// Steps: intro -> pick floor -> pick room -> 360° spin -> room done -> next room or summary.
// Each captured HeatmapPoint is tagged with roomName + floorIndex.

enum WalkthroughStep {
    case intro, pickFloor, pickRoom, spinning, roomDone, summary
}

struct GuidedWalkthroughView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step: WalkthroughStep = .intro
    @State private var viewModel = SignalMonitorViewModel()
    @State private var sessionId = UUID()

    @State private var selectedFloorIndex: Int = 0
    @State private var selectedRoom: String = ""

    @State private var spinProgress: Double = 0
    @State private var spinTimer: Timer?
    @State private var samplesThisRoom: [HeatmapPoint] = []
    @State private var capturedRooms: [CapturedRoom] = []
    @State private var showPaywall: Bool = false

    private let profile = UserProfile()
    private let subscription = SubscriptionManager.shared
    private let spinDuration: Double = 15.0
    private let sampleInterval: Double = 0.5
    private let primary = FullBars.Design.Colors.accentCyan

    struct CapturedRoom: Identifiable {
        let id = UUID()
        let floor: Int
        let name: String
        let avg: Int
        let count: Int
    }

    var body: some View {
        ZStack {
            FullBars.Design.Colors.primaryBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                header
                Spacer(minLength: 0)
                Group {
                    switch step {
                    case .intro:     introCard
                    case .pickFloor: pickFloorCard
                    case .pickRoom:  pickRoomCard
                    case .spinning:  spinningCard
                    case .roomDone:  roomDoneCard
                    case .summary:   summaryCard
                    }
                }
                .transition(.opacity)
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(step == .spinning)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(onDismiss: {
                // If they just subscribed, let them continue
                if subscription.isPro { withAnimation { step = .pickRoom } }
            })
        }
        .onChange(of: subscription.isPro) { _, isPro in
            if isPro { showPaywall = false }
        }
        .onDisappear { cleanup() }
    }

    private var header: some View {
        HStack {
            Text("Guided Walkthrough")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Spacer()
            if step != .spinning {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var introCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 64))
                .foregroundStyle(primary)
            Text("Let's map your WiFi")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 14) {
                instructionRow("1", "You'll walk room by room through your home.")
                instructionRow("2", "In each room, stand near the middle and hold your phone at chest height.")
                instructionRow("3", "Slowly spin in a full circle while we measure. About 15 seconds per room.")
                instructionRow("4", "We'll show you a coverage grade for every room and the whole home.")
            }
            .padding(18)
            .background(cardBackground)
            primaryButton("Start Walkthrough") { withAnimation { step = .pickFloor } }
        }
    }

    private func instructionRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(primary.opacity(0.2)).frame(width: 26, height: 26)
                Text(num).font(.system(.caption, design: .rounded)).fontWeight(.bold).foregroundStyle(primary)
            }
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pickFloorCard: some View {
        VStack(spacing: 16) {
            Text("Which floor are you on?")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("You can switch floors any time.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            VStack(spacing: 10) {
                ForEach(Array(profile.floorLabels.enumerated()), id: \.offset) { idx, label in
                    Button {
                        selectedFloorIndex = idx
                        withAnimation { step = .pickRoom }
                    } label: {
                        HStack {
                            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(primary)
                            Text(label)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(16)
                        .background(cardBackground)
                    }
                }
            }
        }
    }

    private var pickRoomCard: some View {
        VStack(spacing: 16) {
            Text("Which room are you in?")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(floorLabel)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(primary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(profile.roomPresets, id: \.self) { room in
                        roomChip(room)
                    }
                }
            }
            .frame(maxHeight: 320)
            HStack {
                Button("Change Floor") { withAnimation { step = .pickFloor } }
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("Finish") { withAnimation { step = .summary } }
                    .foregroundStyle(primary)
                    .disabled(capturedRooms.isEmpty)
            }
        }
    }

    private var floorLabel: String {
        let labels = profile.floorLabels
        guard labels.indices.contains(selectedFloorIndex) else { return "" }
        return labels[selectedFloorIndex]
    }

    private func roomChip(_ room: String) -> some View {
        let alreadyDone = capturedRooms.contains { $0.floor == selectedFloorIndex && $0.name == room }
        return Button {
            guard !alreadyDone else { return }
            selectedRoom = room
            beginSpin()
        } label: {
            HStack {
                Text(room)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(alreadyDone ? .white.opacity(0.3) : .white)
                Spacer()
                if alreadyDone {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(cardBackground)
        }
        .disabled(alreadyDone)
    }

    private var spinningCard: some View {
        VStack(spacing: 24) {
            Text("Spin slowly in a full circle")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("\(selectedRoom) • Hold phone at chest height")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: spinProgress)
                    .stroke(primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: sampleInterval), value: spinProgress)
                VStack(spacing: 6) {
                    Text("\(Int(spinProgress * 360))°")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(samplesThisRoom.count) samples")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Text("Keep turning at a steady pace…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var roomDoneCard: some View {
        let avg = samplesAvg
        return VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("\(selectedRoom) captured")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            VStack(spacing: 6) {
                Text(roomLabel(forAvg: avg))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(roomColor(forAvg: avg))
                Text("Average \(avg) dBm • \(samplesThisRoom.count) samples")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            VStack(spacing: 10) {
                if subscription.isPro || capturedRooms.count < SubscriptionManager.freeRoomLimit {
                    primaryButton("Capture Next Room") { withAnimation { step = .pickRoom } }
                } else {
                    // Free user hit room limit — show upgrade prompt
                    primaryButton("Unlock All Rooms — Go Pro") { showPaywall = true }
                }
                Button("Finish Walkthrough") { withAnimation { step = .summary } }
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var samplesAvg: Int {
        guard !samplesThisRoom.isEmpty else { return 0 }
        let total = samplesThisRoom.map { $0.signalStrength }.reduce(0, +)
        return total / samplesThisRoom.count
    }

    private var summaryCard: some View {
        let total = capturedRooms.count
        let avg = total == 0 ? 0 : capturedRooms.map { $0.avg }.reduce(0, +) / total
        return VStack(spacing: 18) {
            Image(systemName: "house.fill")
                .font(.system(size: 48))
                .foregroundStyle(primary)
            Text("Walkthrough complete")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("\(total) rooms • avg \(avg) dBm")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            // Grade context
            Text("This Home Scan measures your signal coverage — 30% of your overall WiFi grade. Check your Dashboard to see your updated grade.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(capturedRooms) { r in
                        HStack {
                            Circle().fill(roomColor(forAvg: r.avg)).frame(width: 10, height: 10)
                            Text(r.name)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(r.avg) dBm")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Text(roomLabel(forAvg: r.avg))
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(roomColor(forAvg: r.avg))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(cardBackground)
                    }
                }
            }
            .frame(maxHeight: 280)
            NavigationLink {
                ScrollView {
                    WholeHomeCoverageView(
                        points: samplesThisSession,
                        ispPromisedSpeed: profile.ispPromisedSpeed
                    )
                    .padding(16)
                }
                .background(FullBars.Design.Colors.primaryBackground.ignoresSafeArea())
                .navigationTitle("Whole Home Coverage")
            } label: {
                Text("See Whole Home Coverage")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(primary))
            }
            Button("Done") {
                viewModel.stopMonitoring()
                dismiss()
            }
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    // All heatmap points captured during this walkthrough session (across all rooms).
    @Query private var allPoints: [HeatmapPoint]
    private var samplesThisSession: [HeatmapPoint] {
        allPoints.filter { $0.sessionId == sessionId }
    }

    // MARK: - Spin logic

    private func beginSpin() {
        spinProgress = 0
        samplesThisRoom = []
        viewModel.startMonitoring()
        withAnimation { step = .spinning }
        spinTimer?.invalidate()
        spinTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { _ in
            let p = HeatmapPoint(
                signalStrength: viewModel.currentSignalStrength,
                latency: viewModel.currentLatency,
                sessionId: sessionId,
                roomName: selectedRoom,
                floorIndex: selectedFloorIndex
            )
            modelContext.insert(p)
            samplesThisRoom.append(p)
            spinProgress = min(1.0, spinProgress + sampleInterval / spinDuration)
            if spinProgress >= 1.0 { finishSpin() }
        }
    }

    private func finishSpin() {
        spinTimer?.invalidate()
        spinTimer = nil
        viewModel.stopMonitoring()
        let avg = samplesAvg
        capturedRooms.append(CapturedRoom(floor: selectedFloorIndex, name: selectedRoom, avg: avg, count: samplesThisRoom.count))
        try? modelContext.save()
        withAnimation { step = .roomDone }
    }

    private func cleanup() {
        spinTimer?.invalidate()
        spinTimer = nil
        viewModel.stopMonitoring()
    }

    // MARK: - Helpers

    private func roomLabel(forAvg avg: Int) -> String {
        switch avg {
        case -55...0:    return "Excellent"
        case -65 ..< -55: return "Strong"
        case -75 ..< -65: return "Moderate"
        case -85 ..< -75: return "Weak"
        default:         return "Very Weak"
        }
    }

    private func roomColor(forAvg avg: Int) -> Color {
        Color.forSignalStrength(avg)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(primary))
        }
    }
}
