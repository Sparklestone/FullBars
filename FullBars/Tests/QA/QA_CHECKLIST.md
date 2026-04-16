# FullBars — Pre-Launch Manual QA Checklist

Run this before every TestFlight submission. Pair it with the automated tests
(`./run_tests.sh`) — automated covers logic + persistence, manual covers UX,
sensors, ARKit, and anything visual.

Device matrix: at minimum one older phone (iPhone 12 / SE-class) and one
recent phone (iPhone 15 Pro class) so you catch both performance and layout
issues on small screens.

---

## 0. Fresh-install hygiene

- [ ] Delete the app from the device, reinstall from Xcode/TestFlight.
- [ ] Onboarding appears on first launch.
- [ ] Force-quit mid-onboarding → reopen → resumes gracefully (no crash).
- [ ] Deny location / motion / local-network permissions when prompted.
      App should explain why it needs each and not soft-lock.
- [ ] Revisit Settings.app → Privacy → toggle each permission off.
      Return to app — it should degrade, not crash.

## 1. Onboarding flow

- [ ] All onboarding screens render end-to-end.
- [ ] Back button returns to previous step without losing entered data.
- [ ] Square footage accepts digits only.
- [ ] Floor count stepper clamps at 1…5.
- [ ] People count stepper clamps at 1…20.
- [ ] ISP fields are optional — completing without them still lets you finish.
- [ ] "Finish" writes exactly one `HomeConfiguration`, no duplicates.
- [ ] Onboarding does not re-appear after completion (relaunch to confirm).

## 2. Home Scan tab — empty state

- [ ] Empty state renders with "Scan your first room" hero.
- [ ] "Start scan" button launches the room walkthrough full-screen cover.
- [ ] Home-header stat pills show correct values from onboarding data.
- [ ] Multi-floor homes show the floor list under the stats.

## 3. Room walkthrough (core flow)

- [ ] Speed test runs before the walk; result is shown.
- [ ] Corner-mark step — can mark ≥3 corners, "Done" enables only then.
- [ ] Doorway-mark step — can skip and can add one or more.
- [ ] Device-mark step — can drop a router pin and mesh nodes.
- [ ] Painted-floor step — walking visibly paints the floor map.
- [ ] Painted coverage gate — "Finish" requires ≥ some threshold.
- [ ] Cancel mid-scan → no partial Room is persisted.
- [ ] Background the app during a scan → return → state survives (or fails
      gracefully with a message, never a silent crash).

## 4. Results tab

- [ ] Overall grade circle animates in and matches the average score.
- [ ] Each room row shows correct grade letter + color + Mbps + ping.
- [ ] Plan comparison card appears only when ISP data is present.
- [ ] "Share your Wi-Fi badge" CTA is visible.
      - Free user → tap shows paywall.
      - Pro user → tap opens the QR share sheet.
- [ ] Tapping a room row navigates into RoomDetailView without lag.

## 5. Room detail view

- [ ] Grade ring + metric tiles render for all grades A…F.
- [ ] Layer toggles (Heatmap / Dead zones / Doorways / Devices / Painted)
      each hide/show their layer correctly.
- [ ] The room outline is centered and scaled to fit the canvas.
- [ ] Recommendations section appears when `recommendationCount > 0`.
- [ ] Rescan history
      - Free tier: shows only latest scan, history list is hidden OR gated.
      - Pro tier: shows every past scan for that slot, newest first.

## 6. Share badge (Pro)

- [ ] QR code renders and is scannable with the native camera.
- [ ] Scanning opens the verification URL with correct query params
      (grade, score, download, upload, room count).
- [ ] Share sheet opens and can send to Messages / Mail / Save Image.
- [ ] Rendered PNG is not blurry on Retina.

## 7. Settings tab

- [ ] Subscription card
      - Free → "Upgrade to Pro" opens paywall.
      - Pro → shows "All features unlocked".
- [ ] Edit home sheet — changes persist after save + relaunch.
- [ ] Edit ISP sheet — changes persist after save + relaunch.
- [ ] Data-sharing toggle flips and persists.
- [ ] Reset onboarding — warning alert appears, reset flag is stored.
- [ ] Multi-home
      - Free + 1 home → "Add another home" shows paywall.
      - Pro + any count → adds a new home and switches active.
      - Active-home switcher only appears when `homes.count > 1`.

## 8. Subscription / StoreKit (use a Sandbox account)

- [ ] Paywall fetches products without spinner hang.
- [ ] Purchase monthly → unlocks Pro features immediately.
- [ ] Restore purchases works after a fresh install.
- [ ] Cancel in Sandbox → Pro downgrades back to Free within one launch.

## 9. Dark mode + accessibility

- [ ] App is locked to dark mode — no accidental light-mode leaks.
- [ ] Dynamic Type at XL and XXL: no text truncation on key screens.
- [ ] VoiceOver can reach every tab, CTA, and navigation button.
- [ ] Reduce-motion honored: animations are shortened or skipped.
- [ ] Color-only grade indicators also have a letter/label.

## 10. Error + edge cases

- [ ] Airplane mode → speed test fails gracefully with retry UI.
- [ ] Corrupt / empty Room (no corners) → detail view renders without crash.
- [ ] 0-Mbps speed test → grade falls through to "F" (not NaN).
- [ ] 10+ rooms in a home → results list scrolls smoothly.
- [ ] Very large painted cell count → no dropped frames on scroll.

## 11. Performance sanity

- [ ] Cold launch under 2.5s on an iPhone 12-class device.
- [ ] No noticeable frame drops in Results scroll with 20 rooms.
- [ ] Memory stays under 300 MB during a full room scan.
- [ ] No Instruments "Leaks" hits after scanning 3 rooms.

## 12. Release checklist

- [ ] Build number bumped.
- [ ] Version string matches marketing version.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) is up to date.
- [ ] App Store screenshots refreshed (the new 3-tab shell is different).
- [ ] App Store description mentions any new Pro features.
- [ ] TestFlight tester group has at least 3 external testers lined up.

---

## Severity rubric

When filing a bug during this pass:

- **P0 / block launch** — crash, data loss, payment failure, or any step that
  prevents completing a scan.
- **P1** — a user can recover, but it's awkward or obviously broken.
- **P2** — polish, spacing, wording, minor visual glitch.

---

## 13. Automated-test gates (must pass before signing the checklist)

Before you start the manual pass, confirm the automated suite is green:

- [ ] `./run_tests.sh unit` passes locally — all of these should be in the log:
      - `GradingServiceTests` — signal/speed/latency/reliability/interference scoring
      - `DiagnosticsEngineTests` — issue detection rules and severity
      - `CoveragePlanningServiceTests` — dead-zone clustering + multi-floor
      - `HomeConfigurationTests` / `HomeSelectionTests` / `RoomGeometryTests` / `RescanHistoryTests`
      - `SwiftDataPersistenceTests` — @Model CRUD + relationships
      - `SpeedTestAndGradePersistenceTests` — HeatmapPoint/SpeedTestResult/SpaceGrade round-trip
- [ ] `./run_tests.sh ui` passes locally — all of these:
      - `OnboardingSmokeUITests` — app launches, onboarding renders, tab shell, empty state
      - `KeyFlowsUITests` — home-scan empty CTA, rapid tab switching, background/foreground,
        rotation, settings sub-navigation
- [ ] `.test-logs/` committed nowhere (it is `.gitignore`d; confirm no stray log files staged).

## 14. Device matrix (pick at least 3)

| Device                   | Why                                                    |
|--------------------------|--------------------------------------------------------|
| iPhone SE (2nd/3rd gen)  | Smallest screen, oldest chip — catches layout + perf   |
| iPhone 12 / 13           | A14-class, reflects a large share of live devices      |
| iPhone 15 Pro            | ARKit + RoomPlan primary target                        |
| iPhone 16 / 16 Pro       | Latest chip + current Simulator default                |
| iPad (10th gen or newer) | Landscape + split view                                 |

- [ ] Run §1–§7 on at least one small-screen phone and one recent phone.
- [ ] Run §3 (walkthrough) on a real device — ARKit/RoomPlan don't work in Simulator.

## 15. Regression spot-check after merging a fix

- [ ] Re-run `./run_tests.sh` (all).
- [ ] Re-run only the section of this checklist that touches the changed area.
- [ ] If a P0 was just fixed, add a regression test under `FullBars/Tests/Unit/`
      before closing the bug — "fix + test" must land together.
