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
  TePlannerKit/            # Cross-platform logic + services. Pure SPM,
                           # builds on macOS for fast tests. No SwiftUI
                           # views live here anymore — all views are in
                           # TePlannerApp/ since they touch AMap.
    Models/                # RouteModels, Vehicle, ChargingStation, AuthModels
    Services/              # APIService, AuthSession, SecureStorage (Keychain),
                           #   SettingsStore (UserDefaults), Log
    ViewModels/            # HomeViewModel, LoginViewModel

TePlannerApp/              # iOS app target (driven by project.yml).
                           # Imports TePlannerKit + AMap SDK. Cannot build
                           # on macOS — needs a real device (see "Known
                           # gotchas" — simulator is blocked by AMap on
                           # Apple Silicon).
  TePlannerApp.swift       # @main, AMap SDK init + privacy compliance
  RootView.swift           # Login/Home switch based on AuthSession
  LoginView.swift          # Tesla OAuth (WKWebView via TeslaWebView)
  TeslaWebView.swift       # WKWebView wrapper with callback detection
  HomeView.swift           # Vehicle status header over AMap map
  AMapVehicleMapView.swift # MAMapView wrapper showing vehicle marker
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
make e2e-api       # Hurl HTTP contract tests against api.teplanner.cloud
make e2e-ios       # Maestro UI flows against the booted simulator
make e2e           # both (api first, then ios)
make next-build    # Bump CURRENT_PROJECT_VERSION in Config.xcconfig
make archive       # Signed Release .xcarchive (needs DEVELOPMENT_TEAM)
make export-ipa    # Export IPA from archive (needs deploy/ExportOptions.plist)
make upload-testflight  # altool upload (needs ASC_API_KEY_ID + ASC_API_KEY_ISSUER env)
```

E2E layout: `e2e/hurl/*.hurl` (backend contracts) and `e2e/maestro/*.yaml`
(iOS flows, run alphabetically). Maestro reads creds from
`e2e/maestro/.env` (gitignored — copy from `.env.example`). Maestro
needs Java; the Makefile points `JAVA_HOME` at the brew openjdk by
default. Stable selectors are `accessibilityIdentifier` strings
(`login_button`, `home_search_button`, `search_field`,
`search_result_<n>`, `send_to_vehicle_button`) — prefer them over
hardcoded Chinese text.

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

- **AMap pods need a retag pass to run on Apple Silicon simulator**
  (legacy fat binaries with no arm64-simulator slice). `Podfile`'s
  `post_install` runs `scripts/retag-amap-for-sim.sh`, which uses
  `vtool -set-build-version 7` to rewrite each `.o` file's load
  commands so the linker accepts arm64 slices for iphonesimulator.
  Pods-target dummy objects are too small to hold the new load
  command and get dropped (they're empty). If you ever see
  `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` come back, the
  script also strips it from `Pods/Target Support Files/**/*.xcconfig`
  on each `pod install`.
- xcodebuild may print `[MT] IDERunDestination: Supported platforms
  for the buildables in the current scheme is empty` if the retag
  hasn't run. Re-run `make project` or `pod install` and rebuild.
- Use `-destination 'generic/platform=iOS'` for device builds (and
  `'generic/platform=iOS Simulator'` if you need a placeholder for
  AMap-related debugging). The Makefile targets do this.
- If `swift build` fails with `PCH was compiled with module cache path
  '/Users/.../TePlanner/.build/...'` — the repo was previously at a
  different path. Run `make clean`.
- Do not touch `.swiftpm/xcode/xcuserdata/` or `*.xcuserstate`. They
  are Xcode-local UI state and are gitignored.
- A fresh clone won't build the app until `make project` runs (since
  the xcodeproj/xcworkspace are generated). `make build`/`test` works
  immediately because those go through SPM.

## Verifying UI changes

Simulator path is the default — works on Apple Silicon thanks to the
AMap retag (see Known gotchas). Default `SIMULATOR=iPhone 17`; override
with `make run-app SIMULATOR='iPhone 17 Pro'` etc.

1. `make run-app` — builds, installs, launches on the simulator.
2. `make sim-screenshot` — saves a PNG to `tmp/screenshots/`. Paste
   it back into the conversation.
3. `make log-app` — streams the app's structured logs (see below).

Real-device path (when you need to verify AMap rendering against
real GPS / map tiles, or test push / Tesla OAuth on real network):

1. `make list-devices` — confirm the iPhone is paired and connected.
2. `make run-device DEVICE='iPhone Name'` — builds (signed),
   installs, launches.
3. Device logs: macOS Tahoe broke `log stream --device` and
   libimobiledevice's `idevicesyslog` doesn't auto-mount the iOS 17+
   DDI, so the cleanest way is to run via Xcode (▶) and watch the
   debug console. `make log-device` is wired but no longer streams
   reliably on Tahoe.
4. Real-device screenshots: take on-phone (Power+VolUp) and AirDrop
   to the Mac.

## TestFlight upload

For App Store Connect / TestFlight uploads (paid Apple Developer
Program required, China region settings live on the ASC side):

1. Set `DEVELOPMENT_TEAM` in `Config.xcconfig` (10-char Team ID, not
   the cert hash).
2. `cp deploy/ExportOptions.example.plist deploy/ExportOptions.plist`
   and replace `REPLACE_WITH_YOUR_TEAM_ID`.
3. Create an **App Store Connect API Key** (Users and Access → Keys
   → App Manager role). Download the `.p8`, note the Key ID and
   Issuer ID. Export them so `altool` finds the key (xcrun looks
   under `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`):
   ```
   export ASC_API_KEY_ID=<10-char key id>
   export ASC_API_KEY_ISSUER=<issuer uuid>
   ```
4. `make next-build` once per upload (each TestFlight build needs a
   higher CFBundleVersion than the previous one for the same
   MARKETING_VERSION).
5. `make upload-testflight` archives → exports → uploads. Build is
   visible in App Store Connect ~10–30 min later.

Bundled at upload-time: `PrivacyInfo.xcprivacy` (declares precise
location, email, OtherUserContent for the VIN; UserDefaults +
FileTimestamp + SystemBootTime API reasons), `Assets.xcassets`
single-size 1024×1024 marketing icon (Xcode generates derivatives),
`NSAllowsLocalNetworking=true` ATS exception (HTTP to LAN/localhost
during dev — production endpoints are HTTPS so no broader exception
needed).

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
