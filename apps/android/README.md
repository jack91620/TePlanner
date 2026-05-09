# Tautomation — Android (Phase F)

Native Kotlin + Jetpack Compose client for the TePlanner backend.
Targets Android 8.0+ (API 26) with focus on mainland China devices
(Mi / Huawei [Android 13 fork] / OPPO / vivo / Xiaomi).

## First-time setup

1. **Android Studio + SDK** — install Android Studio Ladybug or newer.
   First-launch wizard downloads the SDK to `~/Library/Android/sdk`
   (~3 GB). Pick **Standard** install + accept all licenses.
2. **Create AVD** — Tools → Device Manager → Create Virtual Device
   → Pixel 8 / API 36. (Smaller emulators work too, just need
   Play Services for AMap.)
3. **Open project** — File → Open → select `apps/android/`
   (NOT the repo root). Android Studio will prompt to sync Gradle
   on first open; first sync is ~5 min as it downloads dependencies.
4. **local.properties** — already created from
   `local.properties.example` with the real AMap + JPush keys. Don't
   commit it; `.gitignore` keeps it out.
5. **Run** — pick the `app` configuration + your AVD → Run. You
   should see "Tautomation" + "Phase F.0 — toolchain ready".

## Module layout

```
apps/android/
├── settings.gradle.kts        # composite-build root, includes :app + :core:*
├── build.gradle.kts           # plugin versions
├── gradle.properties          # JVM args + AndroidX flags
├── local.properties           # secrets (gitignored)
├── app/                       # UI shell, MainActivity, AndroidManifest
└── core/
    ├── network/               # Retrofit + auth interceptor + generated SDK
    ├── push/                  # JPush wrapper + OEM helpers
    └── ui/                    # shared Compose components
```

## Phase plan inside Android

- **F.0 ✅ scaffolding** — this commit. Toolchain wired, modules
  declared, AMap + JPush deps pulled, hello-world Activity.
- **F.1 (1w) auth + bootstrap** — LoginScreen + email/password →
  POST /auth/login, EncryptedSharedPreferences token storage,
  splash → hub navigation.
- **F.2 (2w) hub + automation list/detail/builder** — mirrors iOS
  HubView + AutomationsHomeView + RuleDetailView + RuleBuilderView.
- **F.3 (2w) map + nearby chargers + route preview** — embeds
  AMap Android SDK 3D map + along-route POI search (parity with iOS
  AMapVehicleMapView + AlongRoutePOIService).
- **F.4 (1w) push + scheduled departures + charging stats + polish**
  — JPush registers via core:push, hits POST /devices/register
  {platform: jpush, provider_token: <registration_id>}.

## Backend coupling

This app only talks to **api.teplanner.cloud** — same backend the
iOS app uses. No new endpoints required for Phase F (Phase A.0–A.5
already canonicalized snooze, rule order, scheduled departure,
charging sessions, suggester, user settings; Phase E added
PushDispatcher routing for `platform=jpush`).

For local-dev backend (`http://10.0.2.2:8000` on emulator), set
`BACKEND_BASE_URL=http://10.0.2.2:8000` in `local.properties`.
The `network_security_config.xml` already whitelists 10.0.2.2 for
cleartext.
