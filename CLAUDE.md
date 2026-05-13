# TePlanner — guide for Claude Code

A Tesla-integrated automation companion iOS app for the China
market. Started as a port of an earlier Android prototype (see
`docs/android-migration-guide.md` for the historical mapping; the
`android/` source tree was deleted on 2026-05-09 since the iOS app
is well past parity with its own automation engine, hub-style
home, and Vehicle Command Protocol backend).

## Layout

Phase B repo restructure (2026-05-09): all iOS code now lives under
`apps/ios/`. Android lands in `apps/android/` (Phase F), HarmonyOS in
`apps/harmony/` (Phase G). The shared OpenAPI-generated SDKs live in
`packages/clients/{swift,kotlin,arkts}/` (Phase C). Backend stays at
the same path (`backend/`).

```
apps/ios/                        # iOS app + Swift Package, Phase B
  Package.swift                  # SPM library + tests (no exec target)
  project.yml                    # XcodeGen spec — describes TePlannerApp.xcodeproj
  Podfile / Podfile.lock         # CocoaPods → AMap iOS SDK deps
  Config.xcconfig.example        # Template for per-machine config (real
                                 # values in Config.xcconfig, gitignored —
                                 # bundle id, AMap key, backend URL, Team
                                 # ID, build number)
  Sources/
    TePlannerKit/          # Cross-platform logic + services. Pure SPM,
                           # builds on macOS for fast tests. No SwiftUI
                           # views live here — they're all in TePlannerApp/
                           # since they touch AMap.
    Models/                # Vehicle, RouteModels, ChargingStation,
                           #   AuthModels, POIResult, VehicleAlert,
                           #   ChargingSession, ScheduledDeparture,
                           #   AlongRouteModels (POIs / route-only / charging-plan)
    Services/              # APIService, AuthSession, KeychainStorage,
                           #   SettingsStore, Log, POISearchService,
                           #   ChargingSessionStore + Tracker,
                           #   ChargeLimitSuggestion (charge-limit suggester),
                           #   ScheduledDepartureStore
    Automations/           # Phase 5 reminder/automation engine —
                           #   Automation protocol, AutomationEngine,
                           #   per-rule structs (CampMode, SentryMode,
                           #   CabinOverheat, ChargeComplete)
    ViewModels/            # HomeViewModel, LoginViewModel,
                           #   RoutePreviewViewModel (3-step orchestration),
                           #   SearchViewModel, NearbyChargersViewModel,
                           #   RecentTripsViewModel, ChargingStatsViewModel

  TePlannerApp/            # iOS app target (driven by project.yml).
                           # Imports TePlannerKit + AMap SDK. Builds and
                           # runs on iPhone 17 simulator on Apple Silicon
                           # thanks to the AMap retag (see Known gotchas).
  TePlannerApp.swift       # @main, AMap SDK init + privacy compliance,
                           #   LocalNotificationScheduler bootstrap
  RootView.swift           # Login / Hub switch based on AuthSession
  LoginView.swift          # Tesla OAuth (WKWebView via TeslaWebView)
  TeslaWebView.swift       # WKWebView wrapper with callback detection
  HubView.swift            # Top-level home (Tesla-app-style hub).
                           # Owns HomeViewModel + AutomationEngine + the
                           # ChargingSessionTracker. Renders status card,
                           # alert pill, "下次出行", charge-limit suggestion,
                           # entries to 充电规划 / 自动化提醒 / 电池管理.
                           # Also handles VCP pairing prompt.
  MapHomeView.swift        # 充电规划 sub-page: AMap + search + recenter
                           # button + bottom drawer (附近 / 最近 tabs).
                           # Receives viewModel from Hub via @ObservedObject.
  BatteryView.swift        # 电池管理: charge-limit (manual + presets),
                           # monthly stats grid, history list.
  AutomationsListView.swift  # 自动化提醒 sub-page: per-rule toggles +
                             # threshold sliders. Reads engine.registeredRules.
  AlertPillView.swift      # Top-of-Hub overlay for the highest-priority
                           # alert (camp/sentry/cabin/charge complete).
  ScheduledDepartureSheet.swift # Set/edit "下次出行" time + lead minutes.
  RoutePlanningSettingsSheet.swift # 路线规划设置 sheet (target SOC etc.).
  ChargingStationDetailView.swift # Tap a row in 附近 → detail sheet.
  SearchView.swift         # POI keyword search (AMap iOS SDK).
  NearbyChargersView.swift # 附近 tab content; filter chips.
  RecentTripsView.swift    # 最近 tab content.
  HomeBottomSheet.swift    # Tab container hosting Nearby + Recent.
  AMapVehicleMapView.swift # MAMapView wrapper: vehicle marker, polyline,
                           # charging-stop pins, recenter token.
  AlongRoutePOIService.swift # AMapRoutePOISearch wrapper (Phase 8.2 —
                           # iOS SDK does the road-corridor along-route
                           # search the Web Service can't do).
  AMapPOISearchService.swift # POI keyword search adapter for SearchViewModel.
  LocalNotificationScheduler.swift # UN scheduler for AlertPill criticals
                           # and the Phase 5.5 出发前预热 reminder.
  Info.plist               # CFBundleIdentifier + AMapAPIKey + BackendURL
                           # from xcconfig; ITSAppUsesNonExemptEncryption=NO.

  Tests/
    TePlannerTests/        # XCTest, depends on TePlannerKit only.
                           # 156 tests; covers VMs, services, automation
                           # engine rules, charging session tracker,
                           # charge-limit suggester, model decoding.

backend/                   # FastAPI backend (api.teplanner.cloud).
  app/integrations/amap/web_client.py  # Phase 8.1: AMap REST client
                           # (single map vendor across iOS SDK + backend).
  app/integrations/tesla/  # Tesla Fleet API client + VCP-aware
                           # _send_command (routes via tesla-http-proxy).
  app/api/v1/routes.py     # POST /routes/route + /routes/charging-plan
                           # (the 1-shot /routes/plan was deleted in
                           # Slice 8.2.4 — fail-fast principle).
  app/api/v1/charging.py   # /charging/nearby + /stations/{id}.
  app/api/v1/vehicles.py   # State + signed commands: climate-keeper /
                           # sentry / preheat / charge-limit. All routed
                           # through tesla-http-proxy with VIN lookup.
  scripts/register_partner.py  # Tesla Fleet API partner + public-key
                                # registration.

e2e/
  hurl/                    # Backend HTTP contract tests.
  maestro/                 # iOS UI flows; alphabetical execution.
    _helpers/              # ensure_logged_in (handles VCP pairing prompt
                           # dismiss too) + enter_planning.
```

Generated and gitignored (all under `apps/ios/`):
`TePlannerApp.xcodeproj`, `TePlannerApp.xcworkspace`, `Pods/`,
`Config.xcconfig`, `.build/`, `.derivedData/`. Plus root
`deploy/ExportOptions.plist` + `build/`. Run `make project` after a
fresh clone or any `project.yml` / `Podfile` change.

## Build & test

```
make project       # First time / after project.yml or Podfile change
make build         # swift build (macOS host) — fastest sanity check
make build-ios     # xcodebuild TePlannerKit for iOS Simulator
make build-app     # Build the full TePlannerApp .app bundle
make run-app       # Build + install + launch on simulator
make run-device    # Build + install + launch on a paired iPhone
make test          # swift test on macOS (~1s, default for VM/service work)
make test-ios      # xcodebuild test on iOS Simulator
make test-all      # both
make test-backend  # backend pytest (skips locally if no python; runs on server)
make precommit     # ★ pre-commit gate: iOS unit + backend unit + Hurl (~5s)
make doctor        # toolchain + simulator + scheme diagnostics
make sim-screenshot          # PNG of booted simulator → tmp/screenshots/
make log-app                 # stream simulator app logs (com.teplanner.ios)
make log-device DEVICE=X     # stream device logs (Tahoe-quirky; use Xcode for now)
make list-devices            # list paired iPhones
make clean                   # wipe .build, .derivedData
make clean-project           # also wipe xcodeproj/xcworkspace/Pods
make e2e-api                 # Hurl HTTP contract tests
make e2e-ios                 # Maestro UI flows
make e2e                     # both (api → ios)
make next-build              # Bump CURRENT_PROJECT_VERSION in Config.xcconfig
make archive                 # Restore device-tagged AMap → archive →
                             #   re-tag for sim (Apple Silicon two-mode swap)
make export-ipa              # Export IPA from latest archive
make upload-testflight       # archive → export → altool upload
```

E2E layout: `e2e/hurl/*.hurl` (backend contracts) and
`e2e/maestro/*.yaml` (iOS flows, run alphabetically).

Maestro reads creds from `e2e/maestro/.env` (gitignored — copy from
`.env.example`). Maestro needs Java; the Makefile points `JAVA_HOME`
at brew openjdk.

Stable Maestro selectors are `accessibilityIdentifier` strings —
prefer them over hardcoded Chinese text:
- `login_button`, `hub_status_card`, `hub_menu_button`
- `hub_entry_planning`, `hub_entry_automations`, `hub_entry_battery`
- `hub_charge_limit_card`, `hub_departure_card`
- `home_search_button`, `map_menu_button`, `recenter_button`
- `search_field`, `search_result_<n>`, `send_to_vehicle_button`
- `nearby_filter_<type>`, `nearby_charger_<n>`
- `station_plan_route_button`, `station_open_in_amap_button`
- `automations_save_button`, `automation_toggle_<kind>`,
  `automation_slider_<kind>`
- `manual_charge_limit_slider`, `apply_manual_charge_limit_button`,
  `daily_charge_limit_slider`, `trip_charge_limit_slider`
- `battery_view`, `charging_stats_view`

Override the simulator: `make test-ios SIMULATOR='iPhone 16 Pro'`.

Schemes:
- `TePlanner-Package` (SPM) — the only scheme with a test action.
- `TePlannerKit` (SPM) — library only.
- `TePlannerApp` (xcodeproj) — the app, requires the workspace.

## Conventions

- Swift 5.9+ tools, deployment target iOS 17 / macOS 14.
- SwiftUI + Combine. View models are `@MainActor ObservableObject`.
- Services are protocol-first (e.g. `APIServiceProtocol`,
  `SecureStorage`, `SettingsStore`, `AlongRoutePOIProvider`,
  `ChargingSessionStore`) so tests can inject mocks.
- New shared types in `TePlannerKit` should be `public` if the app
  target or tests reference them.
- No comments unless the *why* is non-obvious. No emojis in code.
- **Fail-fast principle**: don't keep cascading fallbacks. Errors
  propagate to the caller; `nil` / empty results are only legitimate
  when they have a clear semantic (e.g. "no POIs in this segment").
  Saved as `feedback_fail_fast.md` in memory — applies project-wide.
- JSON wire format pinned by `ModelDecodingTests`.
- **Cross-platform feature spec**: any feature that touches more than
  one client (iOS / Android / Harmony) gets a doc under
  `docs/features/<slice>.md` using `docs/features/_template.md`.
  The doc is the single PR-blocking artifact: backend endpoints +
  per-platform acceptance + Maestro flow path. Catches the "iOS first,
  Android port later, both drift" failure mode. See
  `docs/features/firing-indicator.md` as a worked example.

## Architecture cheat sheet

**Hub-and-spoke navigation** (Phase 6, see `f8f9e06`):

```
RootView
└── NavigationStack
    └── HubView                    ← landing
        ├─ Status card (battery ring + range hero)
        ├─ AlertPillView (conditional)
        ├─ "下次出行" card (Phase 5.5)
        ├─ Charge-limit suggestion (Phase 5.6, conditional)
        ├─ NavigationLink → MapHomeView (充电规划)
        ├─ NavigationLink → AutomationsListView (自动化提醒)
        └─ NavigationLink → BatteryView (电池管理)
```

**Route planning flow** (Phase 8.2 — three steps, all required):

```
RoutePreviewViewModel.load()
  1. POST /routes/route (origin, destination)        → polyline + dist + dur
  2. AlongRoutePOIService.searchChargingStations     → AMap iOS SDK alongby
                                                       (chunked at ~50km
                                                       to stay under SDK 70km
                                                       hint, 100-pt cap)
  3. POST /routes/charging-plan (polyline, POIs,     → greedy stop selection
       initial SOC)                                    + arrival SOC
  4. Merge → RoutePlanResponse                       → render in
                                                       RoutePreviewView
```

There is no fallback path. If any step fails, the user sees an error.

**Automation engine** (Phase 5, see `4e7d784`):

`Automation` protocol in `apps/ios/Sources/TePlannerKit/Automations/`. Each
rule (CampMode / SentryMode / CabinOverheat / ChargeComplete) is a
small struct with `evaluate(context) -> VehicleAlert?` and an
optional `primaryAction`. `AutomationEngine` runs the registry on
each polling tick, exposes `@Published alerts`, and dispatches
primary actions through `APIService` (typed `AutomationAction`
enum so rules don't carry an API dependency).

`LocalNotificationScheduler` watches engine alerts and
schedules/cancels iOS local notifications on critical-severity
transitions. Same scheduler also handles the Phase 5.5 preheat
reminder.

## AMap SDK notes

- The iOS API key lives in `apps/ios/Config.xcconfig` (gitignored). The xcconfig
  injects it into `Info.plist` as `AMapAPIKey`. The app reads it back
  in `TePlannerApp.bootstrapAMapSDK()` and hands it to `AMapServices`.
- The backend uses the **AMap Web Service** (separate key,
  `AMAP_WEB_API_KEY` in server `.env`) for routing + geocoding +
  nearby search. Phase 8.1 dropped Tencent maps so iOS SDK + backend
  are now a single vendor.
- Privacy compliance (`MAMapView`, `AMapSearchAPI`,
  `AMapLocationManager` × `updatePrivacy*`) MUST run before any AMap
  type is instantiated. See `TePlannerApp.bootstrapAMapSDK()`.
- Along-route POI search (Phase 8.2) is **iOS-side**:
  `AlongRoutePOIService` wraps `AMapRoutePOISearchRequest` with the
  `chargingPile` enum, chunks long polylines, async/await. Backend
  doesn't sample-search anymore.

## Tesla VCP (Phase 7) — vehicle commands

Tesla deprecated the direct REST command endpoint on 2023-10-09.
All `set_charge_limit` / `set_climate_keeper_mode` / `set_sentry_mode`
/ `auto_conditioning_start` calls require Vehicle Command Protocol
(signed messages with a partner ECDH-P256 key, paired per-vehicle).

Server-side infrastructure:

- Partner ECDH key at `~/teplanner-keys/private.pem` on the VM
  (gitignored).
- Public key served at
  `https://api.teplanner.cloud/.well-known/appspecific/com.tesla.3p.public-key.pem`
  (via existing nginx `/.well-known/` alias).
- `tesla-http-proxy` runs as `systemctl unit tesla-http-proxy.service`
  on `127.0.0.1:4443` with self-signed TLS, holds the private key,
  signs each command before forwarding to the Fleet API.
- `backend/scripts/register_partner.py` registers both the partner
  account and the public key with Tesla's cloud.

Client-side flow:

- `TeslaClient._send_command()` (backend) routes signed commands to
  the proxy URL (`TESLA_VEHICLE_COMMAND_PROXY_URL` setting); state
  reads stay direct.
- Backend command handlers convert numeric `vehicle_id` → VIN before
  calling the proxy (proxy keys on VIN; deprecated REST accepted
  either, but the signed path requires VIN).
- iOS shows a one-time "配对车辆" prompt after Tesla OAuth completes
  (see `HubView.promptVCPPairingIfNeeded`). Tap opens
  `https://tesla.com/_ak/api.teplanner.cloud` which hands off to
  the Tesla mobile app to bind the partner key with the user's
  vehicle. Hub menu has a permanent "配对车辆控制" entry too.

If a vehicle command returns 403 with "Vehicle Command Protocol
required", the user hasn't completed pairing yet (or paired a
different vehicle). The friendly message is in
`APIError.errorDescription`.

## Known gotchas

- **AMap pods need a retag pass on Apple Silicon simulator**
  (legacy fat binaries with no arm64-simulator slice). `Podfile`'s
  `post_install` runs `scripts/retag-amap-for-sim.sh`, which uses
  `vtool -set-build-version 7` to rewrite each `.o` file's load
  commands so the linker accepts arm64 slices for iphonesimulator.
  Pods-target dummy objects are too small to hold the new load
  command and get dropped (they're empty).
- **Archive builds need device-tagged slices** — the sim retag is
  destructive. `make archive` runs `scripts/restore-amap-device.sh`
  (copies the `.orig` backup back) before xcodebuild, then re-runs
  the sim retag afterward so simulator dev keeps working. No
  manual swap needed.
- **`DEVELOPMENT_TEAM` lives only in `apps/ios/Config.xcconfig`.** Don't put
  an empty string in `project.yml`'s `settings.base` — it'll override
  the xcconfig and break signed builds.
- **Backend on Tencent Cloud needs Clash for GitHub access.** The VM
  proxies git over `127.0.0.1:7890` (clash-meta running as systemd
  service); set via `git config http.https://github.com/.proxy ...`
  globally. See `feedback_*` memory.
- **Android emulator DNS dies on corporate Wi-Fi.** Default AVD
  forwards DNS via QEMU NAT → host resolver, and macOS corporate
  resolvers (`192.168.4.x` etc.) refuse queries from QEMU. `make
  android-boot` now launches with `-dns-server 8.8.8.8,114.114.114.114`
  so `api.teplanner.cloud` resolves. If you boot the emulator from
  Android Studio instead of make, you'll see `Unable to resolve
  host` — restart via `make android-boot` or set the DNS in the
  AVD's advanced settings.
- If `swift build` fails with `PCH was compiled with module cache
  path '/Users/.../TePlanner/.build/...'` — the repo was previously
  at a different path. Run `make clean`.
- Do not touch `.swiftpm/xcode/xcuserdata/` or `*.xcuserstate`.
- A fresh clone won't build the app until `make project` runs.
  `make build` / `make test` work immediately because they're SPM-only.

## Verifying UI changes

Simulator path is the default — works on Apple Silicon thanks to the
AMap retag. Default `SIMULATOR=iPhone 17`; override with
`make run-app SIMULATOR='iPhone 17 Pro'` etc.

1. `make run-app` — builds, installs, launches on the simulator.
2. `make sim-screenshot` — saves a PNG to `tmp/screenshots/`.
3. `make log-app` — streams the app's structured logs.

For Maestro flow updates: `JAVA_HOME=/opt/homebrew/opt/openjdk/...
maestro test e2e/maestro/<flow>.yaml`. The full suite is 10 flows
(~5 min). When you change Hub structure or login, also rerun
`_helpers/ensure_logged_in.yaml` consumers.

Real-device path (when you need real GPS, real network, or real Tesla
commands):

1. `make list-devices` — confirm the iPhone is paired.
2. `make run-device DEVICE='iPhone Name'` — builds (signed),
   installs, launches.
3. Device logs: macOS Tahoe broke `log stream --device` so use Xcode
   (▶) and watch the debug console.
4. Real-device screenshots: take on-phone (Power+VolUp) and AirDrop
   to the Mac.

## Backend deploy

**Workflow rule**: server is git-pull-only. **Never `scp` files
to the server**, even for "fast" iteration — it creates state drift
between working tree and HEAD that's painful to clean up. Every
change goes:

  local edit → `make precommit` → `git commit` → `git push origin
  ios-development` → ssh server → `git fetch + git reset --hard
  origin/ios-development` → restart backend.

**Infra changes** (systemd units, nginx vhost, system cron) live in
`ops/{systemd,nginx,cron}/` and deploy via:

```
SSHPASS='...' bash ops/install-infra.sh --dry-run   # see drift
SSHPASS='...' bash ops/install-infra.sh             # apply
```

sha256-diff against `/etc/...` before upload, only reload affected
daemons, idempotent. See `ops/systemd/README.md` for unit list +
`ops/RUNBOOK.md` for the full asset map.

Server tracks `origin/ios-development`. After pushing local commits:

```
ssh ubuntu@82.156.248.135
cd ~/TePlanner && git fetch origin ios-development \
                && git reset --hard origin/ios-development
sudo systemctl restart teplanner-backend
curl -sS https://api.teplanner.cloud/health   # 200
sudo journalctl -u teplanner-backend --since "30 sec ago" | grep "cron tick complete"
```

`reset --hard` instead of `pull` because the server occasionally
ends up with stray modifications (a daily-review autonomous run, a
manual experiment); reset converges cleanly. If anything important
on the server isn't yet in git, commit it locally first via the
proper flow before resetting.

**Don't run `bash start.sh -d -s` on prod.** `start.sh` is a dev
convenience wrapper that spawns `uvicorn --reload` outside systemd —
on prod it collides with the `teplanner-backend.service` unit that's
supposed to own port 8000, sending systemd into an infinite restart
loop (6124× in the 2026-05-14 incident). The orphan still serves
traffic so the issue hides behind `/health` 200, but the monitor's
journalctl-based polling-stale check fires endlessly. Use systemctl.

Tesla `tesla-http-proxy` is its own systemd service:
`sudo systemctl status tesla-http-proxy`. Don't restart it casually
— the per-vehicle session cache in `~/.tesla-cache.json` would be
warm, and a cold start adds latency to the first command.

The watchdog at `/home/ubuntu/ops/server-monitor.sh` is a copy of
`ops/server-monitor.sh` in the repo — `git pull` doesn't touch the
deployed copy. To update it run
`SSHPASS=... ./ops/install-server-monitor.sh` (also re-registers
the cron entry; safe to re-run).

See `reference_backend_deploy.md` (memory) for ssh creds workflow.

## TestFlight upload

For App Store Connect / TestFlight uploads (paid Apple Developer
Program required, China region settings live on the ASC side):

1. Set `DEVELOPMENT_TEAM` in `apps/ios/Config.xcconfig` (10-char Team ID).
2. `cp deploy/ExportOptions.example.plist deploy/ExportOptions.plist`
   and replace `REPLACE_WITH_YOUR_TEAM_ID`.
3. Create an **App Store Connect API Key** (Users and Access → Keys
   → App Manager role). Download the `.p8`, note Key ID + Issuer ID.
   Move to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.
   Export:
   ```
   export ASC_API_KEY_ID=<10-char key id>
   export ASC_API_KEY_ISSUER=<issuer uuid>
   ```
4. `make next-build` once per upload.
5. `make upload-testflight` archives → exports → uploads. Build is
   visible in App Store Connect ~10–30 min later.

Bundled at upload-time:
- `Info.plist` — `ITSAppUsesNonExemptEncryption=NO` skips ASC's
  per-build encryption questionnaire (we use only iOS standard TLS
  and Keychain — no proprietary or replacement crypto, EAR
  §740.17(b)(1) exempt).
- `PrivacyInfo.xcprivacy` — declares precise location, email,
  OtherUserContent for the VIN; UserDefaults + FileTimestamp +
  SystemBootTime API reasons.
- `Assets.xcassets` — single 1024×1024 marketing icon (Xcode
  generates derivatives).
- `NSAllowsLocalNetworking=true` — ATS exception for HTTP to
  LAN/localhost during dev; production endpoints are HTTPS.

The archive flow auto-handles AMap pod sim/device swap; you don't
need to redo `pod install` between sim runs and uploads.

## Logging

Apple's unified logging via `os.Logger`, all under the
`com.teplanner.ios` subsystem so they're filterable. Categories:

| Category | What's in it |
| --- | --- |
| `app` | App lifecycle, AMap SDK init, RootView routing, VCP pairing prompt |
| `api` | Every HTTP request: method/path, status, body preview on errors |
| `auth` | AuthSession login/logout/token refresh |
| `oauth` | LoginViewModel state, WKWebView nav, callback URL detection |
| `vehicle` | HomeViewModel state, automation actions, charging session events |
| `search` | RoutePreviewViewModel orchestration, POI search |
| `map` | AMap marker / camera / polyline updates |

Streaming logs:

```
make log-app                       # simulator
make log-device DEVICE='iPhone'    # paired real device (USB or Wi-Fi)
```

For ad-hoc filtering, use the underlying commands:

```
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.teplanner.ios" AND category == "api"'
```

After-the-fact (e.g. tester sends a `sysdiagnose`):

```
log show --predicate 'subsystem == "com.teplanner.ios"' --last 1h
```

Tokens / full URLs / sensitive data are marked `.private` and get
redacted in archived logs on non-tethered devices. Lengths and
prefixes are `.public` for triage.

## Test strategy

**Workflow rule**: every feature commit ships with the matching
test. Pre-commit must pass `make precommit` (iOS unit + backend
pytest + Hurl HTTP contracts; ~5s total). Maestro flows + iOS
simulator tests are heavier and run before pushing significant UI
changes — but they should never go red on `main`.

| Layer | Make target | Runtime | When to run |
|---|---|---|---|
| iOS unit (Swift package) | `make test` | ~1s | every iteration |
| Backend unit (pytest) | `make test-backend` | ~1s | every backend change |
| Hurl HTTP contracts | `make e2e-api` | ~1s | every API change |
| **Pre-commit gate** | **`make precommit`** | **~5s** | **before each commit** |
| iOS sim tests (SwiftUI) | `make test-ios` | ~30s | before UI-heavy push |
| Maestro flows | `make e2e-ios` | ~5min | before significant UI push |

When adding new backend endpoints: write the Hurl contract test the
same commit. When adding iOS UI surface: write the Maestro flow the
same commit. Don't let the test debt accumulate.

The AMap-using code in `apps/ios/TePlannerApp/` (Hub, MapHomeView, AlongRoute
service, sheets) has unit-test coverage gaps; Maestro is the safety
net there. Adding pure-logic tests when extracting helpers is
appreciated.
