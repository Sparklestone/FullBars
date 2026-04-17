import SwiftUI
import SwiftData

/// The new Settings tab — edit home, ISP plan, subscription, data sharing.
/// Replaces the old `SettingsView` once the new shell is wired up.
struct SettingsHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [HomeConfiguration]
    @State private var subscription = SubscriptionManager.shared
    @State private var presentingPaywall = false
    @State private var presentingHomeEditor = false
    @State private var presentingIspEditor = false
    @State private var presentingReset = false

    private let cyan = FullBars.Design.Colors.accentCyan
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.10)
    private var home: HomeConfiguration? { HomeSelection.activeHome(from: homes) }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    subscriptionCard
                    homeCard
                    if homes.count > 1 { homeSwitcherCard }
                    addHomeCard
                    ispCard
                    dataSharingCard
                    advancedCard
                    footer
                }
                .padding(20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentingPaywall) { ProPaywallView(inline: false, onDismiss: { presentingPaywall = false }) }
        .sheet(isPresented: $presentingHomeEditor) {
            if let home { HomeEditorSheet(home: home) }
        }
        .sheet(isPresented: $presentingIspEditor) {
            if let home { IspEditorSheet(home: home) }
        }
        .alert("Reset onboarding?", isPresented: $presentingReset) {
            Button("Reset", role: .destructive) { resetOnboarding() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll have to re-enter your home details the next time you open the app. Existing scans will remain.")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: subscription.isPro ? "checkmark.seal.fill" : "crown.fill")
                    .foregroundStyle(subscription.isPro ? .green : .yellow)
                Text(subscription.isPro ? "FullBars Pro" : "FullBars Free")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            if subscription.isPro {
                Text("All features unlocked. Thanks for supporting the app!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Multi-home, share badge, rescan history, PDF export, and advanced mesh placement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    presentingPaywall = true
                } label: {
                    Text(String(localized: "settings.upgrade_to_pro"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(cyan)
                        .foregroundStyle(.black)
                        .cornerRadius(10)
                        .accessibilityIdentifier(AccessibilityID.Settings.upgradeButton)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Home

    private var homeCard: some View {
        Button { presentingHomeEditor = true } label: {
            // a11y ID applied to the outer button below
            HStack {
                Image(systemName: "house.fill").foregroundStyle(cyan).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(home?.name ?? "No home set")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    if let home {
                        Text("\(home.dwellingType) · \(home.squareFootage) sq ft · \(home.numberOfFloors) floor\(home.numberOfFloors == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Settings.editHomeButton)
    }

    // MARK: - ISP

    private var ispCard: some View {
        Button { presentingIspEditor = true } label: {
            HStack {
                Image(systemName: "speedometer").foregroundStyle(cyan).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Internet plan")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                    if let home, !home.ispName.isEmpty {
                        Text("\(home.ispName) — \(Int(home.ispPromisedDownloadMbps)) Mbps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Settings.editISPButton)
    }

    // MARK: - Data sharing

    private var dataSharingCard: some View {
        HStack {
            Image(systemName: "chart.bar.fill").foregroundStyle(cyan).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Share anonymous data")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Text("Helps us build real-world Wi-Fi insights.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { home?.dataCollectionOptIn ?? false },
                set: { newValue in
                    home?.dataCollectionOptIn = newValue
                    try? modelContext.save()
                }
            ))
            .tint(cyan)
            .labelsHidden()
            .accessibilityIdentifier(AccessibilityID.Settings.dataSharingToggle)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Advanced

    private var advancedCard: some View {
        VStack(spacing: 0) {
            Button {
                presentingReset = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill").foregroundStyle(.orange).frame(width: 24)
                    Text(String(localized: "settings.reset_onboarding"))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier(AccessibilityID.Settings.resetOnboarding)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Home switcher (when >1 home)

    private var homeSwitcherCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active home")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(homes) { h in
                Button {
                    HomeSelection.setActive(h)
                } label: {
                    HStack {
                        Image(systemName: home?.id == h.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(home?.id == h.id ? cyan : .secondary)
                        Text(h.name)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(h.squareFootage) sq ft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Add another home (Pro)

    private var addHomeCard: some View {
        Button {
            if HomeSelection.canAddAnotherHome(currentCount: homes.count, isPro: subscription.isPro) {
                addNewHome()
            } else {
                presentingPaywall = true
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(cyan)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Add another home")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                        if !subscription.isPro {
                            Text("PRO")
                                .font(.system(.caption2, design: .rounded).weight(.heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(cyan)
                                .foregroundStyle(.black)
                                .cornerRadius(4)
                        }
                    }
                    Text(subscription.isPro
                         ? "Scan a second property — rental, vacation, parents' house."
                         : "Upgrade to Pro to scan multiple homes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func addNewHome() {
        let next = HomeConfiguration(
            name: "Home \(homes.count + 1)",
            dwellingType: DwellingType.house.rawValue,
            squareFootage: 1500,
            numberOfFloors: 1,
            floorLabelsJSON: "[\"Main Floor\"]",
            numberOfPeople: 1,
            hasMeshNetwork: false,
            meshNodeCount: 0,
            ispName: "",
            ispPromisedDownloadMbps: 0,
            ispPromisedUploadMbps: 0,
            zipCode: "",
            dataCollectionOptIn: false
        )
        modelContext.insert(next)
        try? modelContext.save()
        HomeSelection.setActive(next)
        presentingHomeEditor = true
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("FullBars")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Version 1.0")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    // MARK: - Actions

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        // Note: we keep HomeConfiguration + Rooms in SwiftData so user doesn't lose scans.
        // ContentView will observe hasCompletedOnboarding on next launch; for in-session
        // reset, a restart is required (documented in the alert copy).
    }
}

// MARK: - Home editor sheet

private struct HomeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var home: HomeConfiguration
    private let cyan = FullBars.Design.Colors.accentCyan

    @State private var sqftText: String = ""
    @State private var name: String = ""
    @State private var numberOfPeople: Int = 2
    @State private var numberOfFloors: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Home") {
                    TextField("Name", text: $name)
                    TextField("Square footage", text: $sqftText).keyboardType(.numberPad)
                }
                Section("Layout") {
                    Stepper("Floors: \(numberOfFloors)", value: $numberOfFloors, in: 1...5)
                    Stepper("People: \(numberOfPeople)", value: $numberOfPeople, in: 1...20)
                }
                Section("Mesh") {
                    Toggle("Mesh network", isOn: $home.hasMeshNetwork)
                    if home.hasMeshNetwork {
                        Stepper("Mesh nodes: \(home.meshNodeCount)", value: $home.meshNodeCount, in: 1...8)
                    }
                }
            }
            .navigationTitle("Edit home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        home.name = name.isEmpty ? home.name : name
                        home.squareFootage = Int(sqftText) ?? home.squareFootage
                        home.numberOfFloors = numberOfFloors
                        home.numberOfPeople = numberOfPeople
                        if home.floorLabels.count != numberOfFloors {
                            home.floorLabels = HomeConfiguration.defaultFloorLabels(for: numberOfFloors)
                        }
                        if !home.hasMeshNetwork { home.meshNodeCount = 0 }
                        try? modelContext.save()
                        dismiss()
                    }
                    .bold()
                    .tint(cyan)
                }
            }
            .onAppear {
                name = home.name
                sqftText = "\(home.squareFootage)"
                numberOfPeople = home.numberOfPeople
                numberOfFloors = home.numberOfFloors
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ISP editor sheet

private struct IspEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var home: HomeConfiguration
    private let cyan = FullBars.Design.Colors.accentCyan

    @State private var downloadText: String = ""
    @State private var uploadText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    TextField("ISP name", text: $home.ispName)
                    TextField("ZIP code", text: $home.zipCode).keyboardType(.numberPad)
                }
                Section("Promised speeds") {
                    TextField("Download (Mbps)", text: $downloadText).keyboardType(.numberPad)
                    TextField("Upload (Mbps)", text: $uploadText).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Internet plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        home.ispPromisedDownloadMbps = Double(downloadText) ?? home.ispPromisedDownloadMbps
                        home.ispPromisedUploadMbps = Double(uploadText) ?? home.ispPromisedUploadMbps
                        try? modelContext.save()
                        dismiss()
                    }
                    .bold()
                    .tint(cyan)
                }
            }
            .onAppear {
                downloadText = home.ispPromisedDownloadMbps > 0 ? "\(Int(home.ispPromisedDownloadMbps))" : ""
                uploadText = home.ispPromisedUploadMbps > 0 ? "\(Int(home.ispPromisedUploadMbps))" : ""
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack { SettingsHomeView() }
        .modelContainer(for: [HomeConfiguration.self, Room.self], inMemory: true)
}
