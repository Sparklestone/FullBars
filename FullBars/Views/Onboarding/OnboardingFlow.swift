import SwiftUI
import SwiftData
import CoreLocation
import CoreBluetooth
import CoreMotion
import AVFoundation

/// The new onboarding flow. Writes a real `HomeConfiguration` into SwiftData
/// (replacing the old UserDefaults-backed `UserProfile`), captures ISP plan
/// speed for the "you're getting X% of your plan" insight, and walks the user
/// through the four permissions we need.
///
/// This view is used by `ContentView` when `hasCompletedOnboarding == false`.
struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isComplete: Bool

    @State private var step: Step = .welcome
    @State private var subscription = SubscriptionManager.shared

    // Form state
    @State private var dwellingType: DwellingType = .house
    @State private var squareFootageText: String = "1500"
    @State private var numberOfFloors: Int = 1
    @State private var floorLabels: [String] = ["Main"]
    @State private var numberOfPeople: Int = 2
    @State private var hasMeshNetwork: Bool = false
    @State private var meshNodeCount: Int = 0
    @State private var ispName: String = ""
    @State private var ispDownloadText: String = ""
    @State private var ispUploadText: String = ""
    @State private var zipCode: String = ""
    @State private var dataCollectionOptIn: Bool = true

    // Permission state (checked on permissions step)
    @State private var cameraGranted = false
    @State private var locationGranted = false
    @State private var bluetoothGranted = false
    @State private var motionGranted = false
    @State private var locationManager = LocationPermissionHelper()

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if step != .welcome {
                    progressBar
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 12)

                ScrollView {
                    content
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }

                Spacer(minLength: 8)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: numberOfFloors) { _, newValue in
            floorLabels = HomeConfiguration.defaultFloorLabels(for: newValue)
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(cyan)
                    .frame(width: geo.size.width * step.progress, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Step Routing

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:       welcomeStep
        case .dwelling:      dwellingStep
        case .size:          sizeStep
        case .floors:        floorsStep
        case .people:        peopleStep
        case .mesh:          meshStep
        case .isp:           ispStep
        case .permissions:   permissionsStep
        case .dataSharing:   dataSharingStep
        case .paywall:       paywallStep
        case .ready:         readyStep
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .shadow(color: cyan.opacity(0.3), radius: 20)
                Image(systemName: "wifi")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(cyan)
            }
            Text("Welcome to FullBars")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("We'll walk your home room by room and show you exactly where your Wi-Fi falls short — and what to do about it.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 40)
    }

    // MARK: - Dwelling

    private var dwellingStep: some View {
        VStack(spacing: 24) {
            header(icon: "house.fill",
                   title: "What type of home?",
                   subtitle: "Helps us calibrate expectations for coverage and speed.")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DwellingType.allCases, id: \.self) { type in
                    selectionCard(
                        icon: type.icon,
                        label: type.rawValue,
                        isSelected: dwellingType == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) { dwellingType = type }
                    }
                }
            }
        }
    }

    // MARK: - Size

    private var sizeStep: some View {
        VStack(spacing: 24) {
            header(icon: "ruler",
                   title: "How big is your home?",
                   subtitle: "Approximate square footage. Check your listing or assessor's record if you're not sure.")

            VStack(spacing: 12) {
                HStack {
                    Text("Square feet")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("1500", text: $squareFootageText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                        .frame(width: 120)
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .cornerRadius(12)

                // Quick chips
                HStack(spacing: 8) {
                    ForEach([800, 1200, 1800, 2500, 3500], id: \.self) { v in
                        Button("\(v)") {
                            squareFootageText = "\(v)"
                        }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Floors

    private var floorsStep: some View {
        VStack(spacing: 24) {
            header(icon: "building.2.fill",
                   title: "How many floors?",
                   subtitle: "We'll let you scan each floor separately.")

            HStack(spacing: 20) {
                stepperButton(system: "minus", enabled: numberOfFloors > 1) {
                    numberOfFloors = max(1, numberOfFloors - 1)
                }
                Text("\(numberOfFloors)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
                    .frame(width: 80)
                stepperButton(system: "plus", enabled: numberOfFloors < 5) {
                    numberOfFloors = min(5, numberOfFloors + 1)
                }
            }

            if numberOfFloors > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Label your floors")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(0..<numberOfFloors, id: \.self) { idx in
                        HStack {
                            Text("Floor \(idx + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)
                            TextField("Name", text: Binding(
                                get: { floorLabels.indices.contains(idx) ? floorLabels[idx] : "" },
                                set: { newVal in
                                    if !floorLabels.indices.contains(idx) {
                                        floorLabels = HomeConfiguration.defaultFloorLabels(for: numberOfFloors)
                                    }
                                    floorLabels[idx] = newVal
                                }
                            ))
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: - People

    private var peopleStep: some View {
        VStack(spacing: 24) {
            header(icon: "person.2.fill",
                   title: "How many people live here?",
                   subtitle: "Helps us gauge how hard your network has to work.")

            HStack(spacing: 20) {
                stepperButton(system: "minus", enabled: numberOfPeople > 1) {
                    numberOfPeople = max(1, numberOfPeople - 1)
                }
                Text("\(numberOfPeople)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
                    .frame(width: 80)
                stepperButton(system: "plus", enabled: numberOfPeople < 20) {
                    numberOfPeople = min(20, numberOfPeople + 1)
                }
            }
        }
    }

    // MARK: - Mesh

    private var meshStep: some View {
        VStack(spacing: 24) {
            header(icon: "dot.radiowaves.left.and.right",
                   title: "Mesh network?",
                   subtitle: "Mesh systems use multiple access points (Eero, Google Nest WiFi, Orbi, etc.).")

            VStack(spacing: 12) {
                selectionRow(
                    icon: "wifi.router.fill",
                    title: "Single router",
                    subtitle: "Just one device for Wi-Fi",
                    isSelected: !hasMeshNetwork
                ) {
                    hasMeshNetwork = false
                    meshNodeCount = 0
                }

                selectionRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Mesh network",
                    subtitle: "Router plus one or more nodes",
                    isSelected: hasMeshNetwork
                ) {
                    hasMeshNetwork = true
                    if meshNodeCount == 0 { meshNodeCount = 1 }
                }
            }

            if hasMeshNetwork {
                VStack(spacing: 14) {
                    Text("Number of mesh nodes (not counting the router)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 20) {
                        stepperButton(system: "minus", enabled: meshNodeCount > 1) {
                            meshNodeCount = max(1, meshNodeCount - 1)
                        }
                        Text("\(meshNodeCount)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(cyan)
                            .frame(width: 60)
                        stepperButton(system: "plus", enabled: meshNodeCount < 8) {
                            meshNodeCount = min(8, meshNodeCount + 1)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - ISP

    private var ispStep: some View {
        VStack(spacing: 20) {
            header(icon: "speedometer",
                   title: "Your internet plan",
                   subtitle: "Critical: we compare your measured speeds to what you're paying for.")

            VStack(spacing: 14) {
                labeledField("Provider", placeholder: "Xfinity, Verizon Fios, Spectrum…", text: $ispName)
                HStack(spacing: 12) {
                    labeledField("Download (Mbps)", placeholder: "500", text: $ispDownloadText, keyboard: .numberPad)
                    labeledField("Upload (Mbps)", placeholder: "50", text: $ispUploadText, keyboard: .numberPad)
                }
                labeledField("ZIP code", placeholder: "94103", text: $zipCode, keyboard: .numberPad)
            }

            Text("Don't know? Check your bill or ISP's website. You can change this later in Settings.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Permissions

    private var permissionsStep: some View {
        VStack(spacing: 20) {
            header(icon: "lock.shield",
                   title: "Permissions we need",
                   subtitle: "Tap each to grant. You can't scan rooms without these.")

            VStack(spacing: 10) {
                permissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    subtitle: "Augmented reality walkthrough",
                    granted: cameraGranted
                ) {
                    AVCaptureDevice.requestAccess(for: .video) { ok in
                        DispatchQueue.main.async { cameraGranted = ok }
                    }
                }

                permissionRow(
                    icon: "location.fill",
                    title: "Location (Precise, While Using)",
                    subtitle: "Required to read Wi-Fi signal strength",
                    granted: locationGranted
                ) {
                    locationManager.request { granted in
                        DispatchQueue.main.async { locationGranted = granted }
                    }
                }

                permissionRow(
                    icon: "dot.radiowaves.left.and.right",
                    title: "Bluetooth",
                    subtitle: "Detect interference from nearby devices",
                    granted: bluetoothGranted
                ) {
                    bluetoothGranted = true // iOS asks on first CBCentralManager usage
                }

                permissionRow(
                    icon: "figure.walk.motion",
                    title: "Motion & Fitness",
                    subtitle: "Detect walking vs. standing still",
                    granted: motionGranted
                ) {
                    // Touch the motion manager to trigger the iOS prompt; result
                    // will show up when the user first scans. We mark as granted
                    // optimistically — this is strictly a UX nudge.
                    let manager = CMMotionActivityManager()
                    let now = Date()
                    manager.queryActivityStarting(from: now, to: now, to: .main) { _, _ in }
                    motionGranted = true
                }
            }
        }
    }

    // MARK: - Data Sharing

    private var dataSharingStep: some View {
        VStack(spacing: 20) {
            header(icon: "chart.bar.fill",
                   title: "Help improve Wi-Fi for everyone",
                   subtitle: "Share fully anonymous scan results to help build real-world insights.")

            VStack(alignment: .leading, spacing: 10) {
                bullet(icon: "checkmark.circle.fill", text: "Measured speeds vs. your ISP plan", color: .green)
                bullet(icon: "checkmark.circle.fill", text: "Coverage quality by dwelling type", color: .green)
                bullet(icon: "checkmark.circle.fill", text: "Device counts and interference levels", color: .green)
                Divider().opacity(0.2)
                bullet(icon: "xmark.circle.fill", text: "No name, email, or address", color: .red)
                bullet(icon: "xmark.circle.fill", text: "No network names or passwords", color: .red)
                bullet(icon: "xmark.circle.fill", text: "No GPS coordinates", color: .red)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)

            Toggle(isOn: $dataCollectionOptIn) {
                Text("Share anonymous data")
                    .foregroundStyle(.white)
            }
            .tint(cyan)
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
    }

    // MARK: - Paywall

    private var paywallStep: some View {
        Group {
            if subscription.isPro {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("You're a Pro!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Every feature unlocked.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                ProPaywallView(inline: true, onDismiss: nil)
            }
        }
    }

    // MARK: - Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.3), radius: 20)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.green)
            }
            Text("You're all set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                summaryRow("Home", "\(dwellingType.rawValue), \(squareFootageText) sq ft")
                summaryRow("Floors", numberOfFloors == 1 ? floorLabels.first ?? "Main" : floorLabels.joined(separator: " · "))
                summaryRow("People", "\(numberOfPeople)")
                if hasMeshNetwork {
                    summaryRow("Network", "Mesh (1 router + \(meshNodeCount) nodes)")
                } else {
                    summaryRow("Network", "Single router")
                }
                if !ispName.isEmpty {
                    let dl = Int(ispDownloadText) ?? 0
                    summaryRow("ISP", "\(ispName) — \(dl) Mbps")
                }
                summaryRow("Plan", subscription.isPro ? "FullBars Pro" : "Free")
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Text("Open Home Scan to walk your first room.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button(action: primaryAction) {
                Text(primaryLabel)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cyan)
                    .foregroundStyle(.black)
                    .cornerRadius(14)
            }
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)

            if step != .welcome && step != .ready {
                Button {
                    withAnimation { step = step.previous ?? .welcome }
                } label: {
                    Text("Back")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var primaryLabel: String {
        switch step {
        case .welcome:    return "Get started"
        case .paywall:    return subscription.isPro ? "Continue" : "Maybe later"
        case .ready:      return "Open Home Scan"
        default:          return "Next"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .size:
            let n = Int(squareFootageText) ?? 0
            return n >= 100 && n <= 50000
        case .isp:
            // ISP is optional-ish — allow progression either way; validate if entered.
            return true
        default:
            return true
        }
    }

    private func primaryAction() {
        if step == .ready {
            save()
            return
        }
        if let next = step.next {
            withAnimation(.easeInOut(duration: 0.25)) { step = next }
        } else {
            save()
        }
    }

    // MARK: - Save

    private func save() {
        // Floor labels sanity
        if floorLabels.count != numberOfFloors {
            floorLabels = HomeConfiguration.defaultFloorLabels(for: numberOfFloors)
        }

        let encoded = (try? JSONEncoder().encode(floorLabels)).flatMap { String(data: $0, encoding: .utf8) } ?? "[\"Main\"]"

        let sqft = Int(squareFootageText) ?? 1500
        let dl = Double(ispDownloadText) ?? 0
        let ul = Double(ispUploadText) ?? 0

        let config = HomeConfiguration(
            name: "Home",
            dwellingType: dwellingType.rawValue,
            squareFootage: sqft,
            numberOfFloors: numberOfFloors,
            floorLabelsJSON: encoded,
            numberOfPeople: numberOfPeople,
            hasMeshNetwork: hasMeshNetwork,
            meshNodeCount: hasMeshNetwork ? meshNodeCount : 0,
            ispName: ispName,
            ispPromisedDownloadMbps: dl,
            ispPromisedUploadMbps: ul,
            zipCode: zipCode,
            dataCollectionOptIn: dataCollectionOptIn
        )
        modelContext.insert(config)
        try? modelContext.save()

        // Legacy UserProfile mirror — keeps the rest of the app (grading, data
        // collection service) working until we migrate them fully.
        let profile = UserProfile()
        profile.dwellingType = dwellingType
        profile.squareFootage = squareFootageBucket(from: sqft)
        profile.numberOfFloors = numberOfFloors
        profile.numberOfPeople = numberOfPeople
        profile.ispName = ispName
        profile.ispPromisedSpeed = dl > 0 ? dl : 100
        profile.dataCollectionOptIn = dataCollectionOptIn
        profile.floorLabels = floorLabels
        profile.hasCompletedSetup = true

        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }

    private func squareFootageBucket(from sqft: Int) -> SquareFootageRange {
        switch sqft {
        case ..<800: return .small
        case ..<1500: return .medium
        case ..<2500: return .large
        case ..<4000: return .veryLarge
        default: return .huge
        }
    }

    // MARK: - Shared UI

    private func header(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(cyan)
                .shadow(color: cyan.opacity(0.5), radius: 12)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func selectionCard(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? cyan : .secondary)
                Text(label)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isSelected ? cyan.opacity(0.15) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
    }

    private func selectionRow(icon: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? cyan : .secondary)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(cyan)
                }
            }
            .padding(14)
            .background(isSelected ? cyan.opacity(0.1) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? cyan : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
    }

    private func stepperButton(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? cyan : .secondary.opacity(0.3))
                .frame(width: 52, height: 52)
                .background(enabled ? cyan.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(14)
        }
        .disabled(!enabled)
    }

    private func labeledField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(.body, design: .rounded))
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func permissionRow(icon: String, title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(granted ? .green : cyan)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(granted ? .green : .secondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func bullet(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Steps

private enum Step: Int, CaseIterable {
    case welcome, dwelling, size, floors, people, mesh, isp, permissions, dataSharing, paywall, ready

    var next: Step? { Step(rawValue: rawValue + 1) }
    var previous: Step? { Step(rawValue: rawValue - 1) }
    var progress: CGFloat {
        CGFloat(rawValue) / CGFloat(Step.allCases.count - 1)
    }
}

// MARK: - Location permission helper
//
// CoreLocation's API is delegate-based; this wrapper converts it to a closure.
private final class LocationPermissionHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func request(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            completion(true)
        default:
            completion(false)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let granted = manager.authorizationStatus == .authorizedAlways ||
                      manager.authorizationStatus == .authorizedWhenInUse
        completion?(granted)
    }
}

#Preview {
    OnboardingFlow(isComplete: .constant(false))
        .modelContainer(for: [HomeConfiguration.self, Room.self, Doorway.self, DevicePlacement.self], inMemory: true)
}
