import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.fullbars.app", category: "App")

@main
struct FullBarsApp: App {
    let modelContainer: ModelContainer?
    @State private var showError = false
    @State private var errorMessage = ""

    init() {
        #if DEBUG
        UITestingLaunchHandler.applyPreContainer()
        #endif

        do {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            let container = try ModelContainer(
                for: NetworkMetrics.self,
                    SpeedTestResult.self,
                    BLEDevice.self,
                    HeatmapPoint.self,
                    ActionItem.self,
                    SpaceGrade.self,
                    WalkthroughSession.self,
                    AnonymousDataSnapshot.self,
                    HomeConfiguration.self,
                    Room.self,
                    Doorway.self,
                    DevicePlacement.self,
                configurations: config
            )
            self.modelContainer = container

            #if DEBUG
            UITestingLaunchHandler.applyPostContainer(container)
            #endif
        } catch {
            logger.error("Could not initialize ModelContainer: \(error.localizedDescription)")
            self.modelContainer = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = modelContainer {
                    ContentView()
                        .modelContainer(container)
                } else {
                    DataErrorView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct DataErrorView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Unable to Load Data")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("FullBars couldn't initialize its database. Try restarting the app or reinstalling if the problem persists.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
