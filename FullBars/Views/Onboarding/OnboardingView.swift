import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentStep = 0
    @State private var profile = UserProfile()

    // Setup fields
    @State private var selectedDwelling: DwellingType = .house
    @State private var selectedSqFt: SquareFootageRange = .medium
    @State private var numberOfFloors: Int = 1
    @State private var numberOfPeople: Int = 2
    @State private var ispName: String = ""
    @State private var ispSpeed: Double = 100
    @State private var dataOptIn: Bool = true
    @State private var subscription = SubscriptionManager.shared
    @State private var selectedDetailLevel: DisplayMode = .basic
    @State private var isDetectingSpeed = false
    @State private var detectedSpeed: Double?

    private let electricCyan = FullBars.Design.Colors.accentCyan
    private let totalSteps = 8 // welcome, detail level, dwelling, household, ISP, data acceptance, paywall, ready

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                if currentStep > 0 {
                    progressBar
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                }

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: detailLevelStep
                    case 2: dwellingStep
                    case 3: householdStep
                    case 4: ispStep
                    case 5: dataAcceptanceStep
                    case 6: paywallStep
                    case 7: readyStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation buttons
                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusSmall)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadiusSmall)
                    .fill(electricCyan)
                    .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps - 1), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(electricCyan.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .shadow(color: electricCyan.opacity(0.3), radius: 20)

                Image(systemName: "wifi")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(electricCyan)
            }

            Text("Welcome to FullBars")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Let's set up your profile so we can give you the most accurate WiFi analysis for your space.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Step 1: Detail Level

    private var detailLevelStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "slider.horizontal.3",
                title: "How much detail do you want?",
                subtitle: "You can change this anytime in Settings."
            )

            VStack(spacing: 12) {
                detailCard(
                    mode: .basic,
                    icon: "gauge.with.dots.needle.33percent",
                    title: "Keep it simple",
                    description: "Letter grades, friendly language, and clear recommendations.",
                    selected: selectedDetailLevel == .basic
                )
                detailCard(
                    mode: .technical,
                    icon: "waveform.path.ecg",
                    title: "Show me everything",
                    description: "dBm values, latency charts, channel analysis, and raw metrics.",
                    selected: selectedDetailLevel == .technical
                )
            }
            .padding(.horizontal, 24)
        }
    }

    private func detailCard(mode: DisplayMode, icon: String, title: String, description: String, selected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedDetailLevel = mode }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(selected ? electricCyan : .secondary)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? .white : .secondary)
                    Text(description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? electricCyan : .white.opacity(0.3))
                    .font(.title3)
            }
            .padding(16)
            .background(selected ? electricCyan.opacity(0.12) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                    .stroke(selected ? electricCyan : Color.white.opacity(0.1), lineWidth: selected ? 2 : 1)
            )
            .cornerRadius(FullBars.Design.Layout.cornerRadius)
        }
    }

    // MARK: - Step 2: Dwelling Type

    private var dwellingStep: some View {
        VStack(spacing: 24) {
            stepHeader(icon: "house.fill", title: "What type of space?", subtitle: "This helps us understand your coverage needs.")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DwellingType.allCases, id: \.self) { type in
                    dwellingCard(type)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func dwellingCard(_ type: DwellingType) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedDwelling = type } }) {
            VStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(selectedDwelling == type ? electricCyan : .secondary)

                Text(type.rawValue)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedDwelling == type ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(selectedDwelling == type ? electricCyan.opacity(0.15) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                    .stroke(selectedDwelling == type ? electricCyan : Color.white.opacity(0.1), lineWidth: selectedDwelling == type ? 2 : 1)
            )
            .cornerRadius(FullBars.Design.Layout.cornerRadius)
        }
    }

    // MARK: - Step 3: Household Info

    private var householdStep: some View {
        VStack(spacing: 28) {
            stepHeader(icon: "person.2.fill", title: "About your space", subtitle: "This helps us calibrate your coverage expectations.")

            VStack(spacing: 24) {
                // Square footage
                VStack(alignment: .leading, spacing: 8) {
                    Text("Approximate size")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Picker("Size", selection: $selectedSqFt) {
                        ForEach(SquareFootageRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                HStack(spacing: 24) {
                    // Floors
                    VStack(spacing: 8) {
                        Text("Floors")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            stepperButton(systemName: "minus", enabled: numberOfFloors > 1) {
                                numberOfFloors = max(1, numberOfFloors - 1)
                            }
                            Text("\(numberOfFloors)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(electricCyan)
                                .frame(width: 40)
                            stepperButton(systemName: "plus", enabled: numberOfFloors < 5) {
                                numberOfFloors = min(5, numberOfFloors + 1)
                            }
                        }
                    }

                    Divider().frame(height: 60).opacity(0.3)

                    // People
                    VStack(spacing: 8) {
                        Text("People")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            stepperButton(systemName: "minus", enabled: numberOfPeople > 1) {
                                numberOfPeople = max(1, numberOfPeople - 1)
                            }
                            Text("\(numberOfPeople)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(electricCyan)
                                .frame(width: 40)
                            stepperButton(systemName: "plus", enabled: numberOfPeople < 12) {
                                numberOfPeople = min(12, numberOfPeople + 1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func stepperButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? electricCyan : .secondary.opacity(0.3))
                .frame(width: 36, height: 36)
                .background(enabled ? electricCyan.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(10)
        }
        .disabled(!enabled)
    }

    // MARK: - Step 4: ISP Info

    private var ispStep: some View {
        VStack(spacing: 24) {
            stepHeader(icon: "speedometer", title: "Your internet plan", subtitle: "We'll compare your actual speeds against what you're paying for.")

            VStack(spacing: 20) {
                // ISP Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Internet provider")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Comcast, AT&T, Verizon...", text: $ispName)
                        .font(.system(.body, design: .rounded))
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(FullBars.Design.Layout.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: FullBars.Design.Layout.cornerRadius)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }

                // Promised Speed
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Promised download speed")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(ispSpeed)) Mbps")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(electricCyan)
                    }

                    Slider(value: $ispSpeed, in: 10...1000, step: 10)
                        .tint(electricCyan)

                    HStack {
                        Text("10 Mbps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("1 Gbps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Auto-detect button
                if detectedSpeed == nil && !isDetectingSpeed {
                    Button {
                        Task { await autoDetectSpeed() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Auto-detect my speed")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(electricCyan)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(electricCyan.opacity(0.12))
                        .cornerRadius(FullBars.Design.Layout.cornerRadius)
                    }
                } else if isDetectingSpeed {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(electricCyan)
                        Text("Running quick speed test…")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if let detected = detectedSpeed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Detected ~\(Int(detected)) Mbps — slider updated")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.green.opacity(0.8))
                    }
                    .padding(.vertical, 6)
                }

                Text("Don't know? Tap auto-detect or check your bill. You can always update this later in Settings.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 5: Data Acceptance

    private var dataAcceptanceStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "chart.bar.fill",
                title: "Help build better WiFi for everyone",
                subtitle: "FullBars collects anonymous usage data to power community insights — like average speeds by ISP and coverage benchmarks."
            )

            VStack(spacing: 16) {
                // Community value
                VStack(alignment: .leading, spacing: 14) {
                    acceptanceRow(icon: "person.3.fill", text: "See how your WiFi compares to others in your area", color: electricCyan)
                    acceptanceRow(icon: "chart.line.uptrend.xyaxis", text: "Help identify ISPs that underdeliver on promised speeds", color: electricCyan)
                    acceptanceRow(icon: "lightbulb.fill", text: "Power smarter recommendations for everyone", color: electricCyan)
                }

                Divider().opacity(0.2)

                // Privacy assurances
                VStack(alignment: .leading, spacing: 14) {
                    acceptanceRow(icon: "lock.shield.fill", text: "No personal info — ever. No name, email, or address.", color: .green)
                    acceptanceRow(icon: "eye.slash.fill", text: "No network names or passwords leave your device.", color: .green)
                    acceptanceRow(icon: "number", text: "Data is aggregated and never tied to you.", color: .green)
                }
            }
            .padding(.horizontal, 24)

            // Privacy Policy link
            VStack(spacing: 8) {
                Text("By continuing, you accept anonymous data collection.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link("Read our Privacy Policy", destination: URL(string: "https://fullbars.app/privacy")!)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(electricCyan)
            }
            .padding(.horizontal, 24)
        }
    }

    private func acceptanceRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 6: Paywall

    private var paywallStep: some View {
        VStack(spacing: 16) {
            if subscription.isPro {
                // Already subscribed — skip ahead
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("You're a Pro!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("All features are unlocked.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                ProPaywallView(inline: true, onDismiss: nil)
            }
        }
    }

    // MARK: - Step 7: Ready

    private var readyStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .shadow(color: .green.opacity(0.3), radius: 20)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.green)
            }

            Text("You're all set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                summaryRow("Space", value: "\(selectedDwelling.rawValue), \(selectedSqFt.rawValue)")
                summaryRow("Floors", value: "\(numberOfFloors)")
                summaryRow("People", value: "\(numberOfPeople)")
                if !ispName.isEmpty {
                    summaryRow("ISP", value: "\(ispName) — \(Int(ispSpeed)) Mbps")
                }
                summaryRow("Data", value: "Anonymous usage data collected")
                summaryRow("Plan", value: subscription.isPro ? "FullBars Pro" : "Free (3 rooms included)")
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(FullBars.Design.Layout.cornerRadius)
            .padding(.horizontal, 24)

            Text("Start by running a speed test or doing a walkthrough of your space.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Shared Components

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(electricCyan)
                .shadow(color: electricCyan.opacity(0.5), radius: 12)

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 16) {
            // On the paywall step, the paywall itself has CTA buttons — so we show
            // a "Try it first" skip and a "Continue" if already Pro.
            if currentStep == 6 {
                // Paywall step
                if subscription.isPro {
                    Button(action: { advanceStep() }) {
                        Text("Continue")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(electricCyan)
                            .foregroundStyle(.black)
                            .cornerRadius(14)
                    }
                }
                Button(action: { advanceStep() }) {
                    Text(subscription.isPro ? "" : "Try it free first — 3 rooms included")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .opacity(subscription.isPro ? 0 : 1)
            } else {
                Button(action: { advanceStep() }) {
                    Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isDetectingSpeed ? electricCyan.opacity(0.4) : electricCyan)
                        .foregroundStyle(.black)
                        .cornerRadius(14)
                }
                .disabled(isDetectingSpeed)
            }

            if currentStep > 0 && currentStep < totalSteps - 1 && currentStep != 6 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) { currentStep -= 1 }
                }) {
                    Text("Back")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else if currentStep == 0 {
                Button(action: { skipToEnd() }) {
                    Text("Skip setup")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        if currentStep == totalSteps - 1 {
            saveAndComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        }
    }

    private func autoDetectSpeed() async {
        isDetectingSpeed = true
        let service = SpeedTestService()
        if let speed = await service.quickSpeedEstimate() {
            // Round to nearest 25 Mbps tier for slider alignment
            let rounded = max(10, (speed / 25).rounded() * 25)
            await MainActor.run {
                detectedSpeed = speed
                ispSpeed = min(1000, rounded)
                isDetectingSpeed = false
            }
        } else {
            await MainActor.run {
                isDetectingSpeed = false
            }
        }
    }

    private func skipToEnd() {
        // If user skips, use sane defaults so downstream math (speed deficit, etc.) doesn't break.
        if ispSpeed <= 0 { ispSpeed = 100 }
        saveAndComplete()
    }

    private func saveAndComplete() {
        profile.dwellingType = selectedDwelling
        profile.squareFootage = selectedSqFt
        profile.numberOfFloors = numberOfFloors
        profile.numberOfPeople = numberOfPeople
        profile.ispName = ispName
        profile.ispPromisedSpeed = ispSpeed
        profile.dataCollectionOptIn = true
        profile.hasCompletedSetup = true
        // Persist display mode preference
        UserDefaults.standard.set(selectedDetailLevel.rawValue, forKey: "displayMode")

        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
}
