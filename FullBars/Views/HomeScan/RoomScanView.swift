import SwiftUI
import SwiftData

/// The room scan walkthrough UI. Drives a `RoomScanCoordinator` through a
/// simplified 4-step flow: (1) entrance → (2) corners → (3) center speed test
/// → (4) router/mesh question → optional Pro deep scan → review → save.
/// Signal samples and coverage data are collected passively in the background
/// as the user walks between steps.
struct RoomScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var homes: [HomeConfiguration]
    @Query private var existingRooms: [Room]

    @State private var coordinator = RoomScanCoordinator()
    @State private var subs = SubscriptionManager.shared

    // Pre-scan setup state
    @State private var selectedRoomType: RoomType = .livingRoom
    @State private var customName: String = ""
    @AppStorage("lastUsedFloorIndex") private var selectedFloorIndex: Int = 0

    // Deep scan offer uses coordinator.showDeepScanOffer

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    private var home: HomeConfiguration? { homes.first }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            Group {
                switch coordinator.phase {
                case .notStarted:
                    setupScreen
                case .atEntrance:
                    entranceScreen
                case .markingCorners:
                    cornersScreen
                case .walkToCenter:
                    walkToCenterScreen
                case .runningSpeedTest:
                    speedTestScreen
                case .routerQuestion:
                    routerQuestionScreen
                case .placingRouter:
                    placingRouterScreen
                case .deepScan:
                    deepScanScreen
                case .reviewingBeforeSave:
                    if coordinator.showDeepScanOffer {
                        deepScanOfferScreen
                    } else {
                        reviewScreen
                    }
                case .saved:
                    savedScreen
                case .failed(let err):
                    failedScreen(err)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Clamp persisted floor index to valid range
            if let home, selectedFloorIndex >= home.numberOfFloors {
                selectedFloorIndex = 0
            }
            coordinator.deepScanAvailable = subs.isPro
        }
    }

    private var homeRooms: [Room] {
        guard let home else { return [] }
        return existingRooms.filter { $0.homeId == home.id }
    }

    // MARK: - Setup

    private var setupScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
                Spacer()
                Text("New room")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let home, home.numberOfFloors > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Floor")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.white)
                            HStack(spacing: 10) {
                                ForEach(0..<home.numberOfFloors, id: \.self) { i in
                                    let label = home.floorLabels.indices.contains(i) ? home.floorLabels[i] : "Floor \(i+1)"
                                    let isSelected = selectedFloorIndex == i
                                    Button {
                                        selectedFloorIndex = i
                                    } label: {
                                        Text(label)
                                            .font(.system(.caption, design: .rounded).weight(.semibold))
                                            .foregroundStyle(isSelected ? .white : .secondary)
                                            .frame(maxWidth: .infinity, minHeight: 40)
                                            .background(isSelected ? cyan.opacity(0.15) : Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? cyan : Color.white.opacity(0.1),
                                                            lineWidth: isSelected ? 2 : 1)
                                            )
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Room type")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(RoomType.allCases) { type in
                                Button {
                                    selectedRoomType = type
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.systemImage)
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedRoomType == type ? cyan : .secondary)
                                        Text(type.label)
                                            .font(.caption)
                                            .foregroundStyle(selectedRoomType == type ? .white : .secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .padding(.vertical, 8)
                                    .background(selectedRoomType == type ? cyan.opacity(0.15) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedRoomType == type ? cyan : Color.white.opacity(0.1),
                                                    lineWidth: selectedRoomType == type ? 2 : 1)
                                    )
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom name (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Kid's room, The Cave", text: $customName)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    instructionsBlock
                }
                .padding(.horizontal, 20)
            }

            startScanButton
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    private var instructionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it works")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            instructionRow(num: 1, text: "Start at the room entrance and press Begin Scan.")
            instructionRow(num: 2, text: "Walk to each corner and tap Add Corner.")
            instructionRow(num: 3, text: "Walk to the center for a speed test.")
            instructionRow(num: 4, text: "Tell us if there's a router or mesh node here.")
            Text("We measure your signal in the background as you walk!")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(cyan.opacity(0.7))
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }

    private func instructionRow(num: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(num)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(cyan)
                .clipShape(Circle())
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var startScanButton: some View {
        Button {
            guard let home else { return }
            coordinator.start(
                home: home,
                roomType: selectedRoomType,
                customName: customName.isEmpty ? nil : customName,
                floorIndex: selectedFloorIndex
            )
        } label: {
            Label("Start scan", systemImage: "play.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(cyan)
                .foregroundStyle(.black)
                .cornerRadius(14)
        }
    }

    // MARK: - Step indicator

    private func stepIndicator(step: Int, title: String) -> some View {
        HStack(spacing: 12) {
            ForEach(1...coordinator.totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == step ? cyan : (i < step ? Color.green : Color.white.opacity(0.15)))
                    .frame(width: 8, height: 8)
            }
            Spacer()
            Text("Step \(min(step, coordinator.totalSteps)) of \(coordinator.totalSteps)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func stepHeader(step: Int, title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { coordinator.goBackOneStep(); if coordinator.phase == .notStarted { dismiss() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button { coordinator.cancel(); dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            stepIndicator(step: step, title: title)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
        }
    }

    private var signalColor: Color {
        switch coordinator.currentSignalStrength {
        case -50...0: return .green
        case -70...(-51): return .yellow
        default: return .red
        }
    }

    private var signalLabel: String {
        let s = coordinator.currentSignalStrength
        return s == 0 ? "—" : "\(s) dBm"
    }

    private var coverageColor: Color {
        switch coordinator.paintedCoverageFraction {
        case 0.30...: return .green
        case 0.15...: return .yellow
        default:      return .orange
        }
    }

    // MARK: - Step 1: Entrance

    private var entranceScreen: some View {
        VStack(spacing: 0) {
            stepHeader(
                step: 1,
                title: "Start at the entrance",
                subtitle: "Stand at the doorway to this room."
            )

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(cyan.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(cyan)
                }

                Text("Stand at the entrance to the room")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("We'll start measuring your WiFi signal as soon as you begin. Walk naturally — we capture data in the background.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                        .foregroundStyle(signalColor)
                    Text(signalLabel)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(signalColor)
                }
                .padding(.top, 8)
            }

            Spacer()

            Button { coordinator.beginFromEntrance() } label: {
                Label("Begin scan", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 2: Corners

    private var cornersScreen: some View {
        VStack(spacing: 0) {
            stepHeader(
                step: 2,
                title: "Mark corners",
                subtitle: "Walk to each corner of the room and tap Add Corner."
            )

            RoomCanvasView(coordinator: coordinator)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Live counter
            HStack {
                Label("\(coordinator.corners.count) corners", systemImage: "square.on.square")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(cyan)
                Spacer()
                Label(signalLabel, systemImage: "wifi")
                    .font(.caption2)
                    .foregroundStyle(signalColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    coordinator.markCorner()
                    // Capture RSSI at each corner
                    coordinator.captureCornerSignal()
                } label: {
                    Label("Add corner", systemImage: "plus.square.on.square")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(cyan)
                        .foregroundStyle(.black)
                        .cornerRadius(12)
                }

                Button { coordinator.finishCorners() } label: {
                    Text("Done with corners")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(coordinator.corners.count >= 3 ? Color.green : Color.white.opacity(0.08))
                        .foregroundStyle(coordinator.corners.count >= 3 ? .black : .secondary)
                        .cornerRadius(12)
                }
                .disabled(coordinator.corners.count < 3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3: Walk to center + speed test

    private var walkToCenterScreen: some View {
        VStack(spacing: 0) {
            stepHeader(
                step: 3,
                title: "Speed test",
                subtitle: "Walk to the approximate center of the room."
            )

            RoomCanvasView(coordinator: coordinator)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 32))
                        .foregroundStyle(cyan)
                    Text("Walk to the center of the room")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text("It doesn't need to be exact — just roughly the middle.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Button { coordinator.confirmAtCenter() } label: {
                    Label("I'm here — run speed test", systemImage: "speedometer")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .foregroundStyle(.black)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3b: Speed test running

    private var speedTestScreen: some View {
        VStack(spacing: 24) {
            stepHeader(
                step: 3,
                title: "Speed test",
                subtitle: "Stand still — measuring your connection."
            )

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 170, height: 170)
                Image(systemName: "speedometer")
                    .font(.system(size: 60))
                    .foregroundStyle(cyan)
            }

            Text("Running speed test…")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Hold your phone steady. About 15 seconds.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ProgressView()
                .progressViewStyle(.linear)
                .tint(cyan)
                .padding(.horizontal, 60)
            Spacer()
        }
    }

    // MARK: - Step 4: Router / Mesh question

    private var routerQuestionScreen: some View {
        VStack(spacing: 0) {
            stepHeader(
                step: 4,
                title: "Router or mesh node?",
                subtitle: "Is there a WiFi router or mesh node in this room?"
            )

            Spacer()

            VStack(spacing: 16) {
                // Speed test result summary
                if coordinator.downloadMbps > 0 {
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(Int(coordinator.downloadMbps))")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                            Text("Mbps down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text("\(Int(coordinator.uploadMbps))")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                            Text("Mbps up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(spacing: 2) {
                            Text("\(Int(coordinator.pingMs))")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                            Text("ms ping")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }

                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "wifi.router.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.purple)
                }

                Text("Is there a router or mesh node\nin this room?")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 10) {
                Button { coordinator.yesRouterInRoom() } label: {
                    Label("Yes — let me mark it", systemImage: "checkmark.circle.fill")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                }

                Button { coordinator.noRouterInRoom() } label: {
                    Text("No router or mesh here")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 4b: Place router pin

    private var placingRouterScreen: some View {
        VStack(spacing: 0) {
            stepHeader(
                step: 4,
                title: "Mark the router",
                subtitle: "Walk to your router or mesh node and tap Place."
            )

            RoomCanvasView(coordinator: coordinator)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack {
                Label("\(coordinator.devices.count) device(s)", systemImage: "wifi.router.fill")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.purple)
                Spacer()
                Label(signalLabel, systemImage: "wifi")
                    .font(.caption2)
                    .foregroundStyle(signalColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    coordinator.markDevice(
                        type: .router,
                        isPrimaryRouter: coordinator.devices.isEmpty,
                        label: nil
                    )
                } label: {
                    Label("Place router here", systemImage: "mappin.and.ellipse")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button { coordinator.finishRouterPlacement() } label: {
                    Text("Done")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(coordinator.devices.isEmpty ? Color.white.opacity(0.08) : Color.green)
                        .foregroundStyle(coordinator.devices.isEmpty ? Color.secondary : Color.black)
                        .cornerRadius(12)
                }
                .disabled(coordinator.devices.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Deep Scan Offer (Pro)

    private var deepScanOfferScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { coordinator.showDeepScanOffer = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(cyan.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(cyan)
                }

                Text("Want more detail?")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Run a Deep Scan by walking the entire floor. This creates a high-resolution heatmap with precise weak spot detection — ideal for large rooms or detailed analysis.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if !subs.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Pro feature")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(8)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                if subs.isPro {
                    Button {
                        coordinator.showDeepScanOffer = false
                        coordinator.beginDeepScan()
                    } label: {
                        Label("Start deep scan", systemImage: "paintbrush.pointed.fill")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(cyan)
                            .foregroundStyle(.black)
                            .cornerRadius(14)
                    }
                }

                Button {
                    coordinator.showDeepScanOffer = false
                    // Already at reviewingBeforeSave, just dismiss the offer
                } label: {
                    Text(subs.isPro ? "Skip — standard scan is fine" : "Continue with standard scan")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Deep Scan (Paint the floor)

    private var deepScanScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button { coordinator.goBackOneStep() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption2)
                        Text("Deep Scan")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(8)
                    Spacer()
                    Button { coordinator.finishDeepScan() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                VStack(spacing: 4) {
                    Text("Paint the floor")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Walk around the room to map high-resolution signal coverage.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)
            }

            RoomCanvasView(coordinator: coordinator)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            HStack {
                Label("\(Int(coordinator.paintedCoverageFraction * 100))% painted", systemImage: "paintbrush.fill")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(coverageColor)
                Spacer()
                Label(signalLabel, systemImage: "wifi")
                    .font(.caption2)
                    .foregroundStyle(signalColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            Button { coordinator.finishDeepScan() } label: {
                HStack {
                    Image(systemName: coordinator.canFinishPainting ? "checkmark.circle.fill" : "paintbrush.pointed.fill")
                    Text(coordinator.canFinishPainting
                         ? "Done painting"
                         : "Keep walking (\(Int(coordinator.paintedCoverageFraction * 100))%)")
                }
                .font(.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(coordinator.canFinishPainting ? Color.green : Color.white.opacity(0.12))
                .foregroundStyle(coordinator.canFinishPainting ? .black : .secondary)
                .cornerRadius(12)
            }
            .disabled(!coordinator.canFinishPainting)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Review

    private var reviewScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Text("Review & save")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    RoomCanvasView(coordinator: coordinator)
                        .frame(height: 260)

                    reviewStatCard("Corners marked", value: "\(coordinator.corners.count)")
                    if !coordinator.devices.isEmpty {
                        reviewStatCard("Router / mesh", value: "\(coordinator.devices.count)")
                    }
                    reviewStatCard("Signal samples", value: "\(coordinator.samples.count)")
                    reviewStatCard("Coverage mapped", value: "\(Int(coordinator.paintedCoverageFraction * 100))%")
                    reviewStatCard("Speed test", value: "\(Int(coordinator.downloadMbps)) ↓ / \(Int(coordinator.uploadMbps)) ↑ Mbps")
                    reviewStatCard("Ping", value: "\(Int(coordinator.pingMs)) ms")

                    // Offer deep scan if Pro and not yet done
                    if subs.isPro && !coordinator.deepScanOffered {
                        Button {
                            coordinator.deepScanOffered = true
                            coordinator.beginDeepScan()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Text("Run Deep Scan for more detail")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                        }
                    } else if !subs.isPro {
                        // Soft upsell for free users
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text("Upgrade to Pro for Deep Scan — high-res heatmaps with precise weak spot detection")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                coordinator.save(into: modelContext)
            } label: {
                Label("Save room", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func reviewStatCard(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }

    // MARK: - Saved

    private var savedScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }
            Text("Room saved")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Check the Results tab for your grade.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Failed

    private func failedScreen(_ err: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Scan failed")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(err)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button { dismiss() } label: {
                Text("Close")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Identifiable UUID wrapper (for `sheet(item:)`)

private struct IdentifiedID: Identifiable {
    let id: UUID
}

// MARK: - Doorway Connection Sheet

struct DoorwayConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: RoomScanCoordinator
    let doorwayId: UUID
    let existingRooms: [Room]

    @State private var mode: Mode = .pending
    @State private var pendingType: RoomType = .bedroom
    @State private var pendingName: String = ""
    @State private var outsideType: OutsideConnectionType = .front
    @State private var connectToRoomId: UUID?

    enum Mode: String, CaseIterable, Identifiable {
        case pending = "Another room"
        case outside = "Outside"
        case existing = "Already scanned"
        var id: String { rawValue }
    }

    private var index: Int? { coordinator.doorways.firstIndex(where: { $0.id == doorwayId }) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where does this door go?") {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                switch mode {
                case .pending:
                    Section("Pending room") {
                        Picker("Room type", selection: $pendingType) {
                            ForEach(RoomType.allCases) { Text($0.label).tag($0) }
                        }
                        TextField("Custom name (optional)", text: $pendingName)
                    }
                case .outside:
                    Section("Outside") {
                        Picker("Entry type", selection: $outsideType) {
                            ForEach(OutsideConnectionType.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                case .existing:
                    Section("Existing room") {
                        if existingRooms.isEmpty {
                            Text("You haven't scanned any other rooms yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(existingRooms) { room in
                                Button {
                                    connectToRoomId = room.id
                                } label: {
                                    HStack {
                                        Image(systemName: room.roomType.systemImage)
                                        Text(room.displayName)
                                        Spacer()
                                        if connectToRoomId == room.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Doorway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Remove the doorway since it was added optimistically
                        if let i = index { coordinator.doorways.remove(at: i) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDoorway()
                        dismiss()
                    }.bold()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveDoorway() {
        guard let i = index else { return }
        var d = coordinator.doorways[i]
        d.connectsToOutside = false
        d.connectsToUnknownRoom = false
        d.connectsToRoomId = nil
        d.connectsToOutsideTypeRaw = nil
        d.pendingRoomTypeRaw = nil
        d.pendingRoomName = nil

        switch mode {
        case .pending:
            d.connectsToUnknownRoom = true
            d.pendingRoomTypeRaw = pendingType.rawValue
            d.pendingRoomName = pendingName.isEmpty ? nil : pendingName
        case .outside:
            d.connectsToOutside = true
            d.connectsToOutsideTypeRaw = outsideType.rawValue
        case .existing:
            d.connectsToRoomId = connectToRoomId
        }
        coordinator.doorways[i] = d
    }
}

// MARK: - Device Placement Sheet

struct DevicePlacementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: RoomScanCoordinator

    @State private var type: DeviceType = .router
    @State private var isPrimary: Bool = true
    @State private var label: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Device type") {
                    Picker("Type", selection: $type) {
                        ForEach(DeviceType.allCases) {
                            Label($0.label, systemImage: $0.systemImage).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Details") {
                    if type == .router {
                        Toggle("Primary router", isOn: $isPrimary)
                    }
                    TextField("Label (optional)", text: $label)
                }
            }
            .navigationTitle("Place device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Place") {
                        coordinator.markDevice(
                            type: type,
                            isPrimaryRouter: isPrimary,
                            label: label.isEmpty ? nil : label
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                // If this is the first device, default to primary router.
                if coordinator.devices.isEmpty { isPrimary = true }
            }
            .onChange(of: type) { _, newType in
                // Only routers can be primary
                if newType != .router { isPrimary = false }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Room Canvas

/// Top-down canvas of the room being scanned. Draws painted cells, corner
/// markers, doorway markers, device markers, and the user's current position.
struct RoomCanvasView: View {
    @Bindable var coordinator: RoomScanCoordinator
    private let cyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        GeometryReader { geo in
            let all = allPointsToBound()
            let bounds = boundingRect(of: all)
            let padded = bounds.insetBy(dx: -1.0, dy: -1.0)

            let scaleX = geo.size.width / CGFloat(max(padded.width, 0.001))
            let scaleY = geo.size.height / CGFloat(max(padded.height, 0.001))
            let scale = min(scaleX, scaleY)

            let project: (SIMD2<Float>) -> CGPoint = { p in
                let x = CGFloat(p.x - Float(padded.origin.x)) * scale
                let y = CGFloat(p.y - Float(padded.origin.y)) * scale
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // Background grid
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                // Painted cells
                Canvas { ctx, size in
                    let cellSize = CGFloat(coordinator.gridResolution) * scale
                    for cell in coordinator.paintedCells {
                        let wx = Double(cell.x) * coordinator.gridResolution
                        let wz = Double(cell.z) * coordinator.gridResolution
                        let p = project(SIMD2<Float>(Float(wx), Float(wz)))
                        let rect = CGRect(
                            x: p.x - cellSize / 2,
                            y: p.y - cellSize / 2,
                            width: cellSize,
                            height: cellSize
                        )
                        ctx.fill(Path(rect), with: .color(cyan.opacity(0.22)))
                    }
                }

                // Room polygon (filled if we have enough corners)
                if coordinator.corners.count >= 3 {
                    Canvas { ctx, _ in
                        var path = Path()
                        path.move(to: project(coordinator.corners[0]))
                        for corner in coordinator.corners.dropFirst() {
                            path.addLine(to: project(corner))
                        }
                        path.closeSubpath()
                        ctx.stroke(path, with: .color(cyan), lineWidth: 2)
                    }
                }

                // Corner dots
                ForEach(Array(coordinator.corners.enumerated()), id: \.offset) { idx, corner in
                    let p = project(corner)
                    Circle()
                        .fill(cyan)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().fill(cyan).frame(width: 12, height: 12))
                        .position(p)
                        .contextMenu {
                            Button(role: .destructive) {
                                coordinator.removeCorner(at: idx)
                            } label: {
                                Label("Delete corner", systemImage: "trash")
                            }
                        }
                }

                // Doorways
                ForEach(coordinator.doorways) { doorway in
                    let p = project(doorway.position)
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .position(p)
                        .contextMenu {
                            Button(role: .destructive) {
                                coordinator.removeDoorway(id: doorway.id)
                            } label: {
                                Label("Delete entry", systemImage: "trash")
                            }
                        }
                }

                // Devices
                ForEach(coordinator.devices) { device in
                    let p = project(device.position)
                    Image(systemName: device.isPrimaryRouter ? "wifi.router.fill" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .position(p)
                        .contextMenu {
                            Button(role: .destructive) {
                                coordinator.removeDevice(id: device.id)
                            } label: {
                                Label("Delete device", systemImage: "trash")
                            }
                        }
                }

                // Current position (pulsing)
                if let pos = coordinator.currentPosition() {
                    let p = project(pos)
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                    }
                    .position(p)
                }

                // Status chrome
                VStack {
                    HStack {
                        Spacer()
                        trackingBadge
                            .padding(10)
                    }
                    Spacer()
                }
            }
            .clipped()
        }
        .frame(height: 320)
    }

    @ViewBuilder
    private var trackingBadge: some View {
        let tracking = coordinator.isARTracking
        Label(tracking ? "Tracking" : "Hold steady", systemImage: tracking ? "dot.circle.fill" : "hand.raised.fill")
            .font(.caption2)
            .foregroundStyle(tracking ? .green : .orange)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(6)
    }

    // MARK: - Bounding

    private func allPointsToBound() -> [SIMD2<Float>] {
        var points: [SIMD2<Float>] = []
        points.append(contentsOf: coordinator.corners)
        points.append(contentsOf: coordinator.doorways.map { $0.position })
        points.append(contentsOf: coordinator.devices.map { $0.position })
        if let cur = coordinator.currentPosition() { points.append(cur) }
        // Include painted cells' centers so the view adapts to the walked area
        for cell in coordinator.paintedCells {
            points.append(SIMD2<Float>(
                Float(Double(cell.x) * coordinator.gridResolution),
                Float(Double(cell.z) * coordinator.gridResolution)
            ))
        }
        return points
    }

    private func boundingRect(of points: [SIMD2<Float>]) -> CGRect {
        guard !points.isEmpty else {
            return CGRect(x: -3, y: -3, width: 6, height: 6)
        }
        let xs = points.map { CGFloat($0.x) }
        let ys = points.map { CGFloat($0.y) }
        let minX = xs.min() ?? -3
        let minY = ys.min() ?? -3
        let maxX = xs.max() ?? 3
        let maxY = ys.max() ?? 3
        let w = max(maxX - minX, 1.0)
        let h = max(maxY - minY, 1.0)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }
}

#Preview {
    RoomScanView()
        .modelContainer(for: [HomeConfiguration.self, Room.self, Doorway.self, DevicePlacement.self, HeatmapPoint.self], inMemory: true)
}
