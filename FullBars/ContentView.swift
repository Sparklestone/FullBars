import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingFlow(isComplete: $hasCompletedOnboarding)
            } else {
                AppShell()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            HomeConfiguration.self,
            Room.self,
            Doorway.self,
            DevicePlacement.self,
            HeatmapPoint.self
        ], inMemory: true)
}
