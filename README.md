# FullBars

FullBars is an iOS app that scans, grades, and visualizes your home Wi-Fi coverage room by room using ARKit and RoomPlan. Walk through each room with your iPhone and get a signal-quality grade (A–D), heatmap overlay, weak spot detection, speed test history, and actionable recommendations for improving coverage.

## Features

- **Room-by-room scanning** — ARKit + RoomPlan captures room geometry while sampling Wi-Fi signal strength, latency, and throughput at each position.
- **Coverage grading** — each room gets an A–D letter grade based on signal, speed, jitter, and packet loss.
- **Heatmap & weak spots** — visualize signal strength across your floor plan and pinpoint weak spots.
- **Speed tests** — run on-demand speed tests and track results over time.
- **BLE device scanner** — detect nearby Bluetooth devices (routers, extenders, mesh nodes).
- **Multi-home & multi-floor** — Pro users can manage multiple homes and floors.
- **Coverage planner** — get mesh-placement suggestions based on your scan data.

## Requirements

- iOS 17+
- iPhone with ARKit support (LiDAR recommended)
- Xcode 16+

## Getting started

```bash
git clone https://github.com/Sparklestone/FullBars.git
cd FullBars
open FullBars.xcodeproj
```

Select an iOS Simulator or connected device and hit **Cmd+R**.

## Running tests

**Unit tests (fast, ~1s):**

```bash
make test
```

**UI tests (requires simulator, ~3 min):**

```bash
make test-ui
```

**All tests:**

```bash
make test-all
```

## CI

Every push and PR to `main` triggers a GitHub Actions workflow that runs unit tests on a `macos-15` runner and enforces a line-coverage floor. See [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Project structure

```
FullBars/
├── Models/          SwiftData @Model types (Room, Home, HeatmapPoint, …)
├── Views/           SwiftUI views organized by feature
├── ViewModels/      ObservableObject view models
├── Services/        Network, ARKit, BLE, speed test, grading services
├── Utilities/       Constants, extensions, formatters, launch handlers
└── Tests/
    ├── Unit/        Fast isolated unit tests
    ├── Integration/ SwiftData persistence tests
    ├── UI/          XCUITest flows (onboarding, key flows, populated state)
    └── Snapshots/   swift-snapshot-testing scaffold (see Snapshots/README.md)
```

## License

All rights reserved.
