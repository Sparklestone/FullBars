# Contributing to FullBars

## Development setup

1. Clone the repo and open the Xcode project:

```bash
git clone https://github.com/Sparklestone/FullBars.git
cd FullBars
open FullBars.xcodeproj
```

2. Select an iOS 17+ simulator or a connected device and build with **Cmd+R**.

## Branch workflow

The `main` branch has branch protection enabled — all changes go through pull requests.

1. Create a feature branch: `git checkout -b feature/my-change`
2. Make your changes and add tests where appropriate.
3. Run the test suite locally: `make test`
4. Push and open a PR against `main`.
5. CI must pass before merging (unit tests + coverage floor + SwiftLint).

## Running tests

| Command | What it runs | Time |
|---------|-------------|------|
| `make test` | Unit tests only | ~1 s |
| `make test-ui` | UI tests (simulator) | ~3 min |
| `make test-all` | Both | ~3 min |
| `make coverage` | Print line coverage % | instant |
| `make lint` | SwiftLint (strict) | ~5 s |
| `make clean` | Remove build artifacts | instant |

## CI gates

Every PR must pass:

- **Unit tests** — `FullBarsTests` target, run on `macos-15` with Xcode 16.
- **Coverage floor** — overall line coverage must stay above 5% (we're raising this as the suite grows).
- **SwiftLint** — strict mode, triggered only when `.swift` files change.

## Code style

We use [SwiftLint](https://github.com/realm/SwiftLint) with the config in `.swiftlint.yml`. Install locally with `brew install swiftlint`. The key rules relaxed for now are `line_length` and `function_body_length` — we'll tighten these over time.

## Test conventions

- **Unit tests** go in `FullBars/Tests/Unit/`. Name files `<TypeUnderTest>Tests.swift`.
- **Integration tests** (SwiftData round-trips) go in `FullBars/Tests/Integration/`.
- **UI tests** (XCUITest) go in `FullBars/Tests/UI/`.
- **Snapshot tests** go in `FullBars/Tests/Snapshots/` and require the `swift-snapshot-testing` SPM package (see `Tests/Snapshots/README.md`).
- Use the `point(signal:latency:download:...)` helper pattern for building test fixtures.

## Accessibility

All interactive elements should have `.accessibilityIdentifier()` modifiers using the `AccessibilityID` enum (see `Utilities/AccessibilityIdentifiers.swift`). This keeps identifiers consistent between the app and UI tests.

## Localization

User-facing strings use `String(localized:)` with keys defined in `Localizable.xcstrings`. When adding new strings, add the key there and use `String(localized: "key")` in code.

## Questions?

Open an issue or reach out to the maintainer.
