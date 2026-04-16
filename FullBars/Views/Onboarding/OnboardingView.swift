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
    @State private var dataOptIn: Bool = true  // locked on for now; private mode coming soon
    @State private var subscription = SubscriptionManager.shared

    private let electricCyan = FullBars.Design.Colors.accentCyan
    private let totalSteps = 7 // welcome, dwelling, household, ISP, data opt-in, paywall, ready

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
                    case 1: dwellingStep
                    case 2: householdStep
                    case 3: ispStep
                    case 4: dataOptInStep
                    case 5: paywallStep
                    case 6: readyStep
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
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
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

    // MARK: - Step 1: Dwelling Type

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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedDwelling == type ? electricCyan : Color.white.opacity(0.1), lineWidth: selectedDwelling == type ? 2 : 1)
            )
            .cornerRadius(12)
        }
    }

    // MARK: - Step 2: Household Info

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

    // MARK: - Step 3: ISP Info

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
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
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

                Text("Don't know? Check your bill or ISP's website. You can always update this later in Settings.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 4: Data Collection Opt-In

    private var dataOptInStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "chart.bar.fill",
                title: "Help improve WiFi for everyone",
                subtitle: "Share anonymous usage data to help us build insights about real-world WiFi performance."
            )

            VStack(spacing: 16) {
                // What we collect
                VStack(alignment: .leading, spacing: 12) {
                    dataPointRow(icon: "checkmark.circle.fill", text: "Speed vs. ISP promised speed", color: .green)
                    dataPointRow(icon: "checkmark.circle.fill", text: "Coverage quality (strong/moderate/weak %)", color: .green)
                    dataPointRow(icon: "checkmark.circle.fill", text: "Device count and interference levels", color: .green)
                    dataPointRow(icon: "checkmark.circle.fill", text: "Dwelling type and approximate size", color: .green)
                }

                Divider().opacity(0.2)

                // What we don't collect
                VStack(alignment: .leading, spacing: 12) {
                    dataPointRow(icon: "xmark.circle.fill", text: "Your name, email, or any personal info", color: .red)
                    dataPointRow(icon: "xmark.circle.fill", text: "Your location or address", color: .red)
                    dataPointRow(icon: "xmark.circle.fill", text: "Network names or passwords", color: .red)
                }
            }
            .padding(.horizontal, 24)

            // Toggle
            VStack(spacing: 12) {
                Button(action: { withAnimation { dataOptIn = true } }) {
                    HStack {
                        Image(systemName: dataOptIn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(dataOptIn ? .green : .secondary)
                        Text("Share data — use FullBars free")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Free")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .padding(14)
                    .background(dataOptIn ? electricCyan.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(dataOptIn ? electricCyan : Color.white.opacity(0.1), lineWidth: dataOptIn ? 2 : 1)
                    )
                    .cornerRadius(12)
                }

                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("Keep data private")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Spacer()
                    Text("Coming soon")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
        }
    }

    private func dataPointRow(icon: String, text: String, color: Color) -> some View {
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

    // MARK: - Step 5: Paywall

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

    // MARK: - Step 6: Ready

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
                summaryRow("Data sharing", value: dataOptIn ? "Opted in (Free)" : "Private")
                summaryRow("Plan", value: subscription.isPro ? "FullBars Pro" : "Free (1 room included)")
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
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
            if currentStep == 5 {
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
                    Text(subscription.isPro ? "" : "Try it free first — 1 room included")
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
                        .background(electricCyan)
                        .foregroundStyle(.black)
                        .cornerRadius(14)
                }
            }

            if currentStep > 0 && currentStep < totalSteps - 1 && currentStep != 5 {
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
        profile.dataCollectionOptIn = dataOptIn
        profile.hasCompletedSetup = true

        withAnimation(.easeOut(duration: 0.3)) {
            isComplete = true
        }
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
}
