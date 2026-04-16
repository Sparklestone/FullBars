# Snapshot tests

These tests use [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
to catch layout regressions in the major SwiftUI views without booting the full
XCUITest runner. Reruns are O(seconds), XCUITest is O(minutes).

## One-time setup

1. In Xcode, open `FullBars.xcodeproj`.
2. **File → Add Package Dependencies…**
3. Enter `https://github.com/pointfreeco/swift-snapshot-testing`
4. Dependency Rule: **Up to Next Major**, starting from `1.15.0`.
5. Add package.
6. On the target picker, add `SnapshotTesting` to the **FullBarsTests** target
   (NOT the app target — snapshots don't ship to users).

The test file (`ViewSnapshotTests.swift`) is guarded by `#if canImport(SnapshotTesting)`,
so the test target builds fine before step 6; the snapshot tests are just no-ops
until the dependency is linked.

## Recording new snapshots

1. In the test you want to regenerate, flip `isRecording = true` in `setUp()`.
2. Run the test once — it'll fail, writing a reference image to
   `FullBars/Tests/Snapshots/__Snapshots__/`.
3. Inspect the PNG in git; if it looks right, commit it.
4. Flip `isRecording` back to `false`.

## Conventions

- One device config per file of tests (start with `.iPhone13` — matches our
  primary simulator destination).
- Name tests `testViewName_DeviceName` so failing snapshots are obvious.
- Build view fixtures with an in-memory SwiftData `ModelContainer` — never touch
  the user-default on-disk store.
- Don't snapshot animations or motion — the assertion is a still frame.
