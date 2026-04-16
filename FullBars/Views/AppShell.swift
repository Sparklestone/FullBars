import SwiftUI
import SwiftData

/// The new three-tab shell: Home Scan / Results / Settings.
/// Replaces the old five-tab layout (Dashboard, Signal, Speed, Home Scan, Settings).
struct AppShell: View {
    @State private var settingsVM = SettingsViewModel()
    private let cyan = FullBars.Design.Colors.accentCyan

    var body: some View {
        TabView {
            NavigationStack { HomeScanHomeView() }
                .tabItem { Label("Home Scan", systemImage: "figure.walk.motion") }
                .accessibilityLabel("Home Scan Tab")

            NavigationStack { ResultsHomeView() }
                .tabItem { Label("Results", systemImage: "chart.bar.doc.horizontal") }
                .accessibilityLabel("Results Tab")

            NavigationStack { SettingsHomeView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .accessibilityLabel("Settings Tab")
        }
        .tint(cyan)
        .preferredColorScheme(.dark)
        .background(Color(red: 0.05, green: 0.05, blue: 0.10))
        .environment(\.displayMode, settingsVM.displayMode)
    }
}

#Preview {
    AppShell()
        .modelContainer(for: [
            HomeConfiguration.self,
            Room.self,
            Doorway.self,
            DevicePlacement.self,
            HeatmapPoint.self
        ], inMemory: true)
}
