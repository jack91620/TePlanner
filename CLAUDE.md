# TePlanner — guide for Claude Code

A Tesla-integrated trip-planner iOS app. Mirrors the Android app under
`android/` (see `docs/ios-port-plan.md` for the parity plan).

## Layout

```
Package.swift              # SPM library + tests (no exec target)
project.yml                # XcodeGen spec — describes TePlannerApp.xcodeproj
Podfile / Podfile.lock     # CocoaPods → AMap iOS SDK deps
Config.xcconfig.example    # Template for per-machine config (real values
                           # in Config.xcconfig, gitignored — bundle id,
                           # AMap key, backend URL)

Sources/
  TePlannerKit/            # All cross-platform UI + logic + services.
                           # Pure SPM, builds on macOS for fast tests.
    Models/                # RouteModels, Vehicle, ChargingStation, AuthModels
    Services/              # APIService, SecureStorage (Keychain),
                           #   SettingsStore (UserDefaults)
    ViewModels/            # ContentViewModel — to be replaced by HomeViewModel
    Views/                 # ItineraryView
    ContentView.swift      # Old route-planning form, kept until HomeView lands
    MapView.swift          # MapKit view, will be replaced by AMap-backed view

TePlannerApp/              # iOS app target (driven by project.yml).
                           # Imports TePlannerKit + AMap SDK. Cannot build
                           # on macOS — needs the simulator/device.
  TePlannerApp.swift       # @main, AMap SDK init + privacy compliance
  RootView.swift           # TabView shell
  AMapDemoView.swift       # Throwaway smoke test for AMap SDK
  PlannerPlaceholderView.swift  # Wraps old ContentView during transition
  Info.plist               # CFBundleIdentifier + AMapAPIKey from xcconfig

Tests/
  TePlannerTests/          # XCTest, depends on TePlannerKit only
```

Generated and gitignored: `TePlannerApp.xcodeproj`,
`TePlannerApp.xcworkspace`, `Pods/`. Run `make project` after a fresh
clone or any `project.yml` / `Podfile` change.

## Build & test

```
make project       # First time / after project.yml or Podfile change:
                   # runs xcodegen + pod install
make build         # swift build (macOS host) — fastest sanity check
make build-ios     # xcodebuild TePlannerKit for iOS Simulator
make build-app     # Build the full TePlannerApp .app bundle
make run-app       # Build + install + launch on simulator
make test          # swift test on macOS (~1s, recommended default)
make test-ios      # xcodebuild test on iOS Simulator
make test-all      # both
make doctor        # toolchain + simulator + scheme diagnostics
make clean         # wipe .build, .derivedData
make clean-project # also wipe xcodeproj/xcworkspace/Pods
```

Override the simulator: `make test-ios SIMULATOR='iPhone 16 Pro'`.

Schemes:
- `TePlanner-Package` (SPM) — the only scheme with a test action.
- `TePlannerKit` (SPM) — library only.
- `TePlannerApp` (xcodeproj) — the app, requires the workspace.

## Conventions

- Swift 5.9+ tools, deployment target iOS 17 / macOS 14.
- SwiftUI + Combine. View models are `@MainActor ObservableObject`.
- Services are protocol-first (e.g. `APIServiceProtocol`,
  `SecureStorage`, `SettingsStore`) so tests can inject mocks.
- New shared types in `TePlannerKit` should be `public` if the app
  target or tests reference them — past commits had to retroactively
  add `public` (commit `7ab4e07`). Default to `internal` only when the
  type is genuinely private to the library.
- No comments unless the *why* is non-obvious. No emojis in code.
- JSON wire format must match the Android app's `data/model/*.kt`
  classes — `ModelDecodingTests` pin this.

## AMap SDK notes

- The iOS API key lives in `Config.xcconfig` (gitignored). The xcconfig
  injects it into `Info.plist` as `AMapAPIKey`. The app reads it back
  in `TePlannerApp.bootstrapAMapSDK()` and hands it to `AMapServices`.
- Privacy compliance (`MAMapView`, `AMapSearchAPI`,
  `AMapLocationManager` × `updatePrivacy*`) MUST run before any AMap
  type is instantiated. This mirrors Android's `MapsInitializer` /
  `ServiceSettings` calls in `TePlannerApp.kt`.
- AMap pods are static-linked (see `Podfile`) so the binary contains
  no dynamic AMap framework — simpler signing for CLI builds.

## Known gotchas

- `MapView.swift` uses MapKit's `MapMarker`, deprecated in iOS 17.
  This file will be replaced by an AMap-backed view, don't "fix" the
  warning in isolation.
- If `swift build` fails with `PCH was compiled with module cache path
  '/Users/.../TePlanner/.build/...'` — the repo was previously at a
  different path. Run `make clean`.
- Do not touch `.swiftpm/xcode/xcuserdata/` or `*.xcuserstate`. They
  are Xcode-local UI state and are gitignored.
- A fresh clone won't build the app until `make project` runs (since
  the xcodeproj/xcworkspace are generated). `make build`/`test` works
  immediately because those go through SPM.

## Verifying UI changes

1. `make run-app` — builds, installs, launches on the simulator.
2. `make sim-screenshot` — saves a PNG to `tmp/screenshots/`. Paste
   it back into the conversation.
3. `make log-app` — streams the app's structured logs (see below).

## Logging

We use Apple's unified logging via `os.Logger`, all under the
`com.teplanner.ios` subsystem so they're filterable. Categories:

| Category | What's in it |
| --- | --- |
| `app` | App lifecycle, AMap SDK init, RootView routing |
| `api` | Every HTTP request: method/path, status, body preview on errors, decode failures |
| `auth` | AuthSession login/logout/token refresh |
| `oauth` | LoginViewModel state, WKWebView nav, callback URL detection, JS extraction |
| `vehicle` | HomeViewModel state, vehicle pick, wake retry attempts |
| `map` | AMap marker / camera updates |

Streaming logs:

```
make log-app                       # simulator
make log-device DEVICE='iPhone'    # paired real device (USB or Wi-Fi)
```

For ad-hoc filtering you can use the underlying commands:

```
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.teplanner.ios" AND category == "api"'

log stream --device 'iPhone' \
  --predicate 'subsystem == "com.teplanner.ios" AND category == "oauth"'
```

After-the-fact (e.g. tester sends you a `sysdiagnose`):

```
log show --predicate 'subsystem == "com.teplanner.ios"' --last 1h
```

Token values, full URLs with query params, and other sensitive data
are marked `.private` so they're redacted in archived logs on
non-tethered devices. Lengths and prefixes are `.public` for triage.

## Test strategy

Default to `make test` (macOS host) — fastest, no simulator boot,
covers all view-model / service / model logic. Use `make test-ios`
only when the change touches SwiftUI views or other iOS-only APIs.
The AMap-using code lives in the `TePlannerApp/` target which has no
unit tests yet (it's mostly thin glue).
