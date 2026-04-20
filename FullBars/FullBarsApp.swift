import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.fullbars.app", category: "App")

@main
struct FullBarsApp: App {
    let modelContainer: ModelContainer?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var dbError: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        UITestingLaunchHandler.applyPreContainer()
        #endif

        self.modelContainer = Self.makeContainer()
    }

    /// Attempts to create a ModelContainer. On failure, nukes the store and retries once.
    private static func makeContainer() -> ModelContainer? {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        // First attempt
        do {
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
            #if DEBUG
            UITestingLaunchHandler.applyPostContainer(container)
            #endif
            return container
        } catch {
            logger.error("ModelContainer failed: \(error.localizedDescription)")
            logger.error("Full error: \(String(describing: error))")
        }

        // Nuke ALL .store files in Application Support
        logger.info("Deleting SwiftData stores for recovery...")
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.contains(".store") {
                    try? fm.removeItem(at: file)
                    logger.info("Deleted: \(file.lastPathComponent)")
                }
            }
        }

        // Second attempt after nuke
        do {
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
            logger.info("ModelContainer initialized after store reset")
            return container
        } catch {
            logger.error("ModelContainer STILL failed after reset: \(String(describing: error))")
            return nil
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await AnalyticsUploadService.shared.retryPendingUploads()
                    }
                }
            }
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

            // Debug info to help diagnose
            #if DEBUG
            Button("Copy Debug Info") {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path() ?? "?"
                let files = (try? FileManager.default.contentsOfDirectory(atPath: appSupport))?.joined(separator: "\n") ?? "none"
                UIPasteboard.general.string = "AppSupport: \(appSupport)\nFiles:\n\(files)"
            }
            .font(.caption)
            .foregroundStyle(.cyan)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
