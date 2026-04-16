# Test setup — one-time instructions

Do these once, then `./run_tests.sh` whenever you want to run tests.

## 1. Register the test targets in Xcode

From the project root (the folder with `FullBars.xcodeproj`):

```bash
gem install xcodeproj   # skip if you already have it
ruby add_test_targets.rb
```

This creates two targets if they don't already exist:

- `FullBarsTests` — unit + integration tests (hosted by the app)
- `FullBarsUITests` — XCUITest smoke tests

…and registers every file under `FullBars/Tests/` with the right target.

## 2. Reopen Xcode

Close and reopen `FullBars.xcodeproj` so it picks up the new targets. You'll
see them in the scheme selector and under Product → Test.

## 3. `-UITesting-*` launch args — IMPLEMENTED

**Status:** wired as of 2026-04-15 in `FullBars/Utilities/UITestingLaunchHandler.swift`
and invoked from `FullBarsApp.init()` under `#if DEBUG`.

Contracts honored by the app:

- `-UITesting-ResetState` — clears `hasCompletedOnboarding` in `UserDefaults`,
  so the next launch lands in onboarding.
- `-UITesting-SkipOnboarding` — sets `hasCompletedOnboarding = true` and seeds
  a default `HomeConfiguration` if none exists.
- `-UITesting-NoRooms` — implies `SkipOnboarding`, and additionally deletes
  every persisted `Room` so the empty state is guaranteed.

Implementation is split in two phases to straddle the SwiftData container:

- `applyPreContainer()` — flips `UserDefaults` before `ModelContainer` is built.
- `applyPostContainer(_:)` — seeds/wipes SwiftData after the container exists.

If you add new flags, extend `UITestingLaunchHandler` (don't sprinkle
`ProcessInfo` checks around the app) and document the contract here.

## 4. Run the suite

```bash
./run_tests.sh           # everything
./run_tests.sh unit      # logic + persistence only (fast)
./run_tests.sh ui        # XCUITest only (slower — boots Simulator)
```

Logs land in `.test-logs/` so you can diff failures across runs.

## 5. CI (optional, when you're ready)

GitHub Actions with a macOS runner can run `./run_tests.sh unit` on every
push. UI tests are flakier on CI — run them nightly rather than per-PR.
