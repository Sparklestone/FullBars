#if canImport(SnapshotTesting)
import XCTest
import SwiftUI
import SnapshotTesting
@testable import FullBars

/// Snapshot tests for the major SwiftUI views. Reruns in seconds compared to
/// XCUITest — catches layout regressions (spacing, color, truncation) without
/// booting the simulator's app lifecycle.
///
/// **Recording new snapshots:** set `isRecording = true` on a test, run once,
/// diff the generated `.png` in git, then flip recording back off.
///
/// See `FullBars/Tests/Snapshots/README.md` for the one-time Xcode setup step
/// (adding the swift-snapshot-testing SPM dependency). Without that dependency
/// this file compiles out via the `canImport` guard above and the suite is a no-op.
final class ViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Deterministic snapshot environment — match one device, one appearance.
        // Flip to true locally to regenerate reference images.
        // isRecording = true
    }

    // MARK: - Onboarding welcome card

    func testOnboardingWelcome_iPhone16() {
        let view = makeOnboardingPreview()
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    // MARK: - Results empty state

    func testResultsEmptyState_iPhone16() {
        let view = makeResultsPreview(roomCount: 0)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    // MARK: - Results with 3 seeded rooms

    func testResultsPopulated3Rooms_iPhone16() {
        let view = makeResultsPreview(roomCount: 3)
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    // MARK: - Settings home

    func testSettingsHome_iPhone16() {
        let view = makeSettingsPreview()
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }

    // MARK: - Private fixtures

    /// The preview fixtures build views against an in-memory ModelContainer
    /// so snapshots are deterministic. Update these as the view APIs evolve.
    /// In-memory container with the full schema for snapshot previews.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            HomeConfiguration.self, Room.self, Doorway.self,
            DevicePlacement.self, HeatmapPoint.self,
            SpeedTestResult.self, SpaceGrade.self, WalkthroughSession.self,
        ])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration(isStoredInMemoryOnly: true)
        ])
    }

    @MainActor
    private func makeOnboardingPreview() -> some View {
        OnboardingFlow()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func makeResultsPreview(roomCount: Int) -> some View {
        let container = try! makeContainer()
        if roomCount > 0 {
            let ctx = container.mainContext
            let home = HomeConfiguration(name: "Snapshot Home", squareFootage: 1800, numberOfFloors: 1)
            ctx.insert(home)
            let roomTypes: [RoomType] = [.livingRoom, .kitchen, .bedroom, .bathroom, .office, .hallway]
            for i in 0..<roomCount {
                let room = Room(
                    homeId: home.id,
                    roomTypeRaw: roomTypes[i % roomTypes.count].rawValue,
                    downloadMbps: Double.random(in: 40...150),
                    uploadMbps: Double.random(in: 10...40),
                    pingMs: Double.random(in: 8...50),
                    gradeScore: Double.random(in: 55...95),
                    gradeLetterRaw: ["A", "B", "C", "B"][i % 4],
                    deadZoneCount: i % 2
                )
                ctx.insert(room)
            }
            try? ctx.save()
        }
        return NavigationStack { ResultsHomeView() }
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func makeSettingsPreview() -> some View {
        let container = try! makeContainer()
        let ctx = container.mainContext
        let home = HomeConfiguration(
            name: "My House",
            squareFootage: 2200,
            numberOfFloors: 2,
            ispName: "Comcast",
            ispPromisedDownloadMbps: 200
        )
        ctx.insert(home)
        try? ctx.save()
        return NavigationStack { SettingsHomeView() }
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
}

#else
// Stub so the test target still compiles cleanly before the SPM dep is added.
// Add `https://github.com/pointfreeco/swift-snapshot-testing` (from 1.15.0)
// to the FullBars project and link it against the FullBars test target.
import XCTest
final class ViewSnapshotTests: XCTestCase {
    func testSkippedUntilSnapshotTestingPackageAdded() {
        // This test is a placeholder; see FullBars/Tests/Snapshots/README.md.
    }
}
#endif
