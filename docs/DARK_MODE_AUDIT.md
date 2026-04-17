# Dark Mode Audit — FullBars

**Date:** 2026-04-17  
**Status:** Pass — no changes required

## Summary

FullBars is a dark-mode-first app. Every top-level view applies
`.preferredColorScheme(.dark)`, and child components inherit this setting
automatically via SwiftUI's environment propagation.

## Top-level views with `.preferredColorScheme(.dark)`

AppShell, OnboardingView, OnboardingFlow, ProPaywallView, DashboardView,
CoveragePlannerView, MultiFloorDeadZoneView, WalkthroughSetupView,
WiFiReportCardView, ShareBadgeView, RoomScanView, HomeScanHomeView,
ResultsHomeView, RoomDetailView, SettingsHomeView.

## Child views (inherit from parent — no modifier needed)

MetricCard, SignalTrendsView, ARWalkthroughView, ConnectionDetailsCard,
BeforeAfterView, SpaceGradeView, GradeReportView, GradeExplainerView,
BLEScannerView, FloorPlanView, SpeedGaugeView, ActionItemsView,
AnimatedRingView, SignalStrengthIndicator, QuickActionCard,
SignalMonitorView, DiagnosticsView, WholeHomeCoverageView, HeatmapView,
GuidedWalkthroughView, ShareSheet, SpeedTestView.

## Color system

All custom colours live in `FullBars.Design.Colors` (Constants.swift) as
hard-coded RGB values chosen for dark backgrounds. Inline `Color(red:…)`
in views mirrors those values (e.g., `Color(red: 0.05, green: 0.05,
blue: 0.10)` for the near-black background).

No view reads `@Environment(\.colorScheme)` — none needs to, since the
scheme is always `.dark`.

## Recommendations (future)

- Extract remaining inline `Color(red:…)` calls into `FullBars.Design.Colors`
  for a single source of truth.
- If light-mode support is ever added, convert constants to an Asset Catalog
  with dark/light variants and adopt `Color("assetName")`.
