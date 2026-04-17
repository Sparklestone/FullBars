# FullBarsWidget — Setup Guide

Source files are in `FullBarsWidget/`. Follow these steps in Xcode to wire
the target into the project.

## 1. Add the Widget Extension target

1. **File → New → Target… → Widget Extension**
2. Product name: `FullBarsWidget`
3. Uncheck "Include Configuration App Intent" (we use `StaticConfiguration`)
4. Finish — Xcode creates the target and scheme
5. Delete the Xcode-generated `.swift` file; replace with
   `FullBarsWidget/FullBarsWidget.swift` from this repo.

## 2. Enable App Groups on **both** targets

### Main app (FullBars)
1. Select the **FullBars** target → Signing & Capabilities → **+ Capability → App Groups**
2. Add `group.com.fullbars.shared`

### Widget (FullBarsWidget)
1. Select the **FullBarsWidget** target → same steps
2. Add the same group identifier `group.com.fullbars.shared`

## 3. Migrate the SwiftData store to the shared container

In `FullBarsApp.swift`, change the `ModelConfiguration` init to use the
shared container:

```swift
let storeURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.fullbars.shared")!
    .appending(path: "default.store")

let config = ModelConfiguration(
    url: storeURL,
    isStoredInMemoryOnly: false,
    allowsSave: true
)
```

> **Note:** On first launch after this change the old on-device store won't
> be visible. You can add a one-time migration that copies the old store to
> the new URL, or simply let users re-scan.

## 4. Share model files with the widget target

In Xcode's file inspector, add these files to **both** the FullBars and
FullBarsWidget targets (check the box):

- `Models/HomeConfiguration.swift`
- `Models/Room.swift`
- `Utilities/Constants.swift` (for `FullBars.Design.Colors` used by `GradeLetter`)
- `Models/SpaceGrade.swift` (contains `GradeLetter`)

## 5. Build & run

- Select the **FullBarsWidget** scheme and run on a simulator.
- Long-press the home / lock screen to add the widget.
- The widget reads the latest grade from the shared SwiftData store every
  30 minutes, and whenever WidgetKit decides to refresh.

## Supported widget families

| Family                  | What it shows |
|------------------------|--------------|
| `systemSmall`          | Grade letter, score, room count |
| `accessoryCircular`    | Grade letter + score (lock screen) |
| `accessoryRectangular` | Grade letter, score, room count (lock screen) |
