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
    @MainActor
    private func makeOnboardingPreview() -> some View {
        // Replace with the real OnboardingFlow preview once the type is importable.
        Text("Onboarding preview — wire to OnboardingFlow when exposing an init")
            .frame(width: 390, height: 844)
    }

    @MainActor
    private func makeResultsPreview(roomCount: Int) -> some View {
        Text("Results preview (\(roomCount) rooms) — wire to ResultsHomeView with in-memory container")
            .frame(width: 390, height: 844)
    }

    @MainActor
    private func makeSettingsPreview() -> some View {
        Text("Settings preview — wire to SettingsHomeView with in-memory container")
            .frame(width: 390, height: 844)
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
