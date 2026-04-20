# FullBars — WiFi Coverage Analyzer for iOS

## What This App Does
FullBars is an iOS app that helps homeowners diagnose WiFi coverage issues room by room. Users walk through their home holding their phone, and the app measures signal strength, speed, and latency at every point. It generates a heatmap, grades each room (A–F), identifies weak spots, and provides actionable recommendations (e.g., move your router, add a mesh node).

## Owner
Aaron Finkelstein (finkelstein.aaron@gmail.com) — solo developer, building this as a consumer product for the App Store.

## Tech Stack
- **Language:** Swift (SwiftUI + SwiftData)
- **Min iOS:** 17.0
- **Architecture:** MVVM with `@Observable` ViewModels, SwiftData `@Model` for persistence
- **Backend:** Supabase (anonymized analytics upload), CloudKit (user data sync — manual via CloudKitSyncService, NOT SwiftData automatic sync)
- **Admin dashboard:** Next.js + Vercel (ad/recommendation management)
- **CI:** GitHub Actions (ci.yml, testflight.yml, swiftlint.yml)
- **Distribution:** Fastlane → TestFlight

## Project Structure
```
FullBars/
  Models/          — SwiftData @Model classes (Room, HomeConfiguration, HeatmapPoint, etc.)
  Views/
    HomeScan/      — Room scan walkthrough (RoomScanView, HomeScanHomeView)
    Results/       — Room detail, floor maps, full report, share badge
    Onboarding/    — OnboardingFlow (new), OnboardingView (legacy)
    Settings/      — SettingsHomeView (new), SettingsView (legacy)
    Components/    — Shared UI components
  ViewModels/      — @Observable view models
  Services/        — Network, BLE, grading, speed test, analytics, CloudKit sync
  Utilities/       — Constants, Extensions, Formatters, AccessibilityIdentifiers
  Tests/           — Unit, Integration, UI, Snapshots
FullBarsWidget/    — Lock screen widget extension
fastlane/          — Fastfile for TestFlight builds
dashboard/         — Next.js admin dashboard (Vercel)
Supabase/          — Edge functions for analytics
```

## Key Architecture Decisions

### Three-Tab Shell
The app uses `AppShell.swift` as the root view with three tabs: Home Scan, Results, Settings. The old five-tab layout (Dashboard, Signal, Speed, Home Scan, Settings) is deprecated but the old views still exist.

### fullScreenCover for Room Scan
`RoomScanView` is presented via `.fullScreenCover` on the **TabView in AppShell** — NOT inside any NavigationStack. This is intentional. Presenting from inside a NavigationStack causes the navigation bar's safe area to leak into the cover and create layout gaps.

### SwiftData Models Use Double, Not Float
All `@Model` stored properties that hold decimal values MUST be `Double`. Using `Float` causes a runtime crash because SwiftData's SQLite backing store uses Double. This was a production crash that took significant debugging.

### Design Tokens
Colors, corner radii, and spacing are centralized in `Constants.swift` under `FullBars.Design`. The accent color is `accentCyan`. The app is dark-mode only.

### Subscription Model
Free tier: 3 rooms. Pro tier unlocks unlimited rooms + rescan history. Managed by `SubscriptionManager`.

## Common Pitfalls (Read Before Making Changes)

### SwiftUI Layout
- **Never use `Color.clear.frame(width: X)` without a height constraint** inside a VStack. `Color` views are greedy and expand infinitely, causing the parent HStack to balloon. Always use `Color.clear.frame(width: X, height: 1)` or use a `Spacer()` instead.
- **`.ignoresSafeArea()` on a background vs on content** — these behave very differently. `.background(bg.ignoresSafeArea())` extends the background under the safe area while keeping content positioned normally. `.ignoresSafeArea()` on the content itself makes content overlap the status bar.
- **fullScreenCover and NavigationStack** — never present a fullScreenCover from inside a NavigationStack if you want the presented view to control its own layout. The navigation environment leaks through.

### SwiftData
- All decimal model properties must be `Double` (not `Float`).
- **No static stored properties inside `@Model` classes.** `private static let logger = ...` inside an `@Model` will break schema generation. Declare loggers as file-level `private let` outside the class instead.
- **All `ModelContainer` init sites must list the same models.** Both `FullBarsApp.swift` and `PersistenceService.swift` create containers — they must register identical `@Model` type lists. After adding a new model, grep for `ModelContainer(` to find all sites.
- **CloudKit entitlements conflict with `cloudKitDatabase: .none`.** Do not add iCloud/CloudKit entitlements to the app unless you want SwiftData's automatic CloudKit sync. `CloudKitSyncService` handles sync manually via CKContainer API. The entitlements were removed in April 2026 to fix a `loadIssueModelContainer` crash.
- **`#Predicate` macros can't capture outer object properties.** Extract values into local `let` bindings before use: `let idVal = obj.id; #Predicate { $0.id == idVal }`.
- When adding new properties to `@Model` classes, SwiftData's lightweight migration handles simple additions. For complex changes, implement `VersionedSchema` + `MigrationPlan` (not yet done — on the roadmap).

### TestFlight Deployment
- Always bump the build number before archiving. The Fastfile uses a timestamp but rebuilding within the same minute causes duplicate rejection.
- Run `agvtool new-version -all $(date +%Y%m%d%H%M)` or let Fastlane handle it.

### Data Collection
- Data collection is mandatory — no opt-out toggle. Users accept anonymous data collection during onboarding via standard acceptance language.
- `dataCollectionOptIn` property exists in `UserProfile` for backwards compatibility but is always `true`.
- The onboarding data step is informational (community value framing), not a choice.
- `AnalyticsUploadService` checks `home.dataCollectionOptIn` before uploading.
- Users can request data deletion in Settings (legal requirement).

## Current State (as of April 2026)

### What Works
- 5-step guided room scan: (1) corners → (2) entries/exits → (3) devices → (4) floor painting → (5) Find My-style signal-guided speed test at optimal location. Auto-sorted corners prevent hourglass polygons.
- Per-room grading (A–F) with signal, speed, and latency factors
- **Relative heatmap coloring** — colors are relative to all rooms in the house: green (strongest) → orange (weakest above -80 dBm), red for weak spots only. Managed by `WholeHouseAnalysisService.SignalRange`.
- Weak spot detection with clustered zones (yellow = weak, red = dead)
- Floor plan stitching via doorway connections
- PDF/share export of room report cards
- CloudKit sync (manual via CloudKitSyncService), Supabase analytics upload
- Lock screen widget
- Onboarding flow with address autocomplete, ISP detection, floor labeling
- **Whole-house analysis** on Results page: mesh system recommendation when rooms have uneven signal/speed (>2x speed gap or >15 dBm signal spread), plus aggregated whole-house recommendations with set-logic deduplication. Service: `WholeHouseAnalysisService`.

### Important: ISP Promised Speed Removed
ISP "promised speed" has been removed from all UI. Users don't know their promised WiFi speed, so `ispPromisedDownloadMbps`, `ispPromisedUploadMbps`, and `ispPromisedSpeed` model properties are **kept for migration safety** but always set to `0`. Do NOT add UI that references these values. The ISP editor in Settings only shows ISP name and ZIP code.

### Important: Data Collection Defaults to ON
`dataCollectionOptIn` defaults to `true` in `HomeConfiguration.init`. This is intentional — users accept data collection during onboarding via standard acceptance language. Do not change this default.

### Known Issues / TODO
- `ResultsHomeView.swift` still has its own `.fullScreenCover` for rescan that's inside a NavigationStack — may need the same treatment as AppShell if it shows a layout gap
- No `VersionedSchema` / `MigrationPlan` for SwiftData migrations yet
- `Cache ImageRenderer output` for PDF/share export (performance optimization, not yet implemented)
- CloudKit container (`iCloud.com.fullbars.app`) not yet provisioned in App Store Connect — entitlements were removed to prevent SwiftData crash; need to provision before re-enabling
- `PersistenceService.swift` is a legacy singleton — largely unused but still compiled; its container init was fixed to match FullBarsApp's model list
- **April 2026 dev spec pending implementation** — 13 changes including free tier expansion (3 rooms), onboarding rewrite (8 steps, data acceptance, display mode selection, ISP auto-detect), combined assessment flow, PDF export, ISP Report Card, guided Fix-It flows. Full spec: `FullBars_Dev_Spec.md`

## Testing
- Unit tests in `Tests/Unit/`
- Integration tests in `Tests/Integration/`
- UI tests in `Tests/UI/`
- Snapshot tests in `Tests/Snapshots/`
- Run all: `make test` or `./run_tests.sh`
