import SwiftUI
import SwiftData

struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @Environment(\.modelContext) var modelContext

    @State private var showClearConfirmation = false
    @State private var showResetConfirmation = false
    @State private var showPaywall = false
    @State private var subscription = SubscriptionManager.shared

    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Subscription Status
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Plan")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(electricCyan)
                                    Spacer()
                                    Text(subscription.isPro ? "Pro" : "Free")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(subscription.isPro ? .green : .secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background((subscription.isPro ? Color.green : Color.white).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                if !subscription.isPro {
                                    Button { showPaywall = true } label: {
                                        HStack {
                                            Image(systemName: "crown.fill")
                                                .foregroundStyle(electricCyan)
                                            Text("Upgrade to FullBars Pro")
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(electricCyan.opacity(0.1)))
                                    }
                                } else {
                                    Button("Restore Purchases") {
                                        Task { await subscription.restore() }
                                    }
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Display Mode Toggle (Prominent)
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("View Mode")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Technical Details")
                                            .font(.subheadline)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { viewModel.displayMode == .technical },
                                            set: { viewModel.displayMode = $0 ? .technical : .basic }
                                        ))
                                        .tint(electricCyan)
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(viewModel.displayMode == .technical
                                            ? "Showing dBm values, charts, and raw metrics throughout the app."
                                            : "Showing simplified grades and friendly language."
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Display Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Display")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 12) {
                                    ToggleRow(title: "Show Advanced Metrics", isOn: $viewModel.showAdvancedMetrics)
                                }

                                HStack(spacing: 6) {
                                    Image(systemName: "moon.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("Dark mode optimized for low-light signal analysis")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // ISP Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Your Internet Plan")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("ISP Name")
                                            .font(.subheadline)
                                        Spacer()
                                        TextField("e.g. Comcast", text: $viewModel.ispName)
                                            .font(.subheadline)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundStyle(electricCyan)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Promised Speed")
                                                .font(.subheadline)
                                            Spacer()
                                            Text(viewModel.ispPromisedSpeed > 0
                                                ? "\(Int(viewModel.ispPromisedSpeed)) Mbps"
                                                : "Not set")
                                                .fontWeight(.semibold)
                                                .foregroundStyle(electricCyan)
                                        }

                                        Slider(
                                            value: $viewModel.ispPromisedSpeed,
                                            in: 0...2000,
                                            step: 25
                                        )
                                        .tint(electricCyan)

                                        Text("Set this to compare speed test results against what you pay for")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Monitoring Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Monitoring")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 16) {
                                    PickerRow(
                                        title: "Auto-Refresh Interval",
                                        selection: $viewModel.autoRefreshInterval,
                                        options: [(1, "1 second"), (2, "2 seconds"), (5, "5 seconds"), (10, "10 seconds")]
                                    )

                                    ToggleRow(title: "Notify on Signal Drop", isOn: $viewModel.notifyOnSignalDrop)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Signal Drop Threshold")
                                                .font(.subheadline)
                                            Spacer()
                                            Text("\(viewModel.signalDropThreshold) dBm")
                                                .fontWeight(.semibold)
                                                .foregroundStyle(electricCyan)
                                        }

                                        Slider(
                                            value: .init(
                                                get: { Double(viewModel.signalDropThreshold) },
                                                set: { viewModel.signalDropThreshold = Int($0) }
                                            ),
                                            in: -90...(-60)
                                        )
                                        .tint(electricCyan)

                                        Text("Alert when signal drops below this threshold")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        // Data Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Data")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 12) {
                                    PickerRow(
                                        title: "Data Retention",
                                        selection: $viewModel.dataRetentionDays,
                                        options: [(7, "7 days"), (14, "14 days"), (30, "30 days"), (90, "90 days")]
                                    )

                                    Button(action: { showClearConfirmation = true }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "trash").foregroundStyle(.red)
                                            Text("Clear All Data")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.red)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }

                        // About Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                VStack(spacing: 12) {
                                    HStack {
                                        Text("App Version").font(.subheadline)
                                        Spacer()
                                        Text("1.0.0").foregroundStyle(.secondary).font(.subheadline)
                                    }
                                    HStack {
                                        Text("Build Number").font(.subheadline)
                                        Spacer()
                                        Text("42").foregroundStyle(.secondary).font(.subheadline)
                                    }

                                    Divider().opacity(0.3)

                                    Link(destination: URL(string: "https://fullbars.app/privacy")!) {
                                        HStack {
                                            Text("Privacy Policy").font(.subheadline).fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "arrow.up.right").font(.caption)
                                        }
                                        .foregroundStyle(electricCyan)
                                        .contentShape(Rectangle())
                                    }

                                    Link(destination: URL(string: "https://apps.apple.com")!) {
                                        HStack {
                                            Text("Rate App").font(.subheadline).fontWeight(.semibold)
                                            Spacer()
                                            Image(systemName: "star.fill").font(.caption)
                                        }
                                        .foregroundStyle(electricCyan)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }

                        // Reset Section
                        SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reset")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(electricCyan)

                                Divider().opacity(0.3)

                                Button(action: { showResetConfirmation = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.counterclockwise").foregroundStyle(.orange)
                                        Text("Reset to Defaults")
                                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { ProPaywallView() }
            .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData(context: modelContext)
                }
            } message: {
                Text("This will delete all collected data. This action cannot be undone.")
            }
            .alert("Reset to Defaults?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("This will restore all settings to their default values.")
            }
        }
    }
}

private struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: FullBars.Design.Colors.accentCyan.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    private let electricCyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Toggle("", isOn: $isOn).tint(electricCyan)
        }
    }
}

private struct PickerRow: View {
    let title: String
    @Binding var selection: Int
    let options: [(Int, String)]

    var body: some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .labelsHidden()
        }
    }
}

#Preview {
    SettingsView()
}
