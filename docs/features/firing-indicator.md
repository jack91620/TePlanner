# Feature: Automation list "正在触发" indicator

> Show users at a glance which automation rules are currently active vs merely enabled-but-quiet.

**Status:** shipped — 2026-05-10
**Owner:** dongxinbo

---

## Backend

### Endpoints

```
GET /api/v1/automations/  →  RuleResponse[] now includes:
  is_firing: bool          # true if enabled AND last_fired_at >= now - 30min
  firing_since: datetime?  # last_fired_at when is_firing, else null
```

No new endpoint; field added to existing list response.

### Migrations

None — derived field, computed at serialize time.

### Behavior changes (no API surface)

`_row_to_response()` (`backend/app/api/v1/automations.py`) now consults
`last_fired_at` (already loaded from PushedAlert ledger) and a 30-minute
heuristic window to populate the new fields.

**Known limitation:** the 30-minute window is a heuristic. State_duration
rules with sticky conditions (camp/sentry) keep firing every tick, so the
window catches them well. State_transition rules (charge complete) flag
"firing" for ~30 min after the user gets the push — acceptable since
that's roughly the user-attention window for these alerts.

A real per-trigger liveness check (querying current telemetry against
state_duration thresholds, checking dismissed_at for state_transition)
will replace the heuristic when alert acknowledgement tracking lands.

---

## Clients

### iOS

- [x] Surface: AutomationsHomeView (`apps/ios/TePlannerApp/AutomationsHomeView.swift`)
- [x] Visible behavior:
      - Firing rule's trigger-icon tile flips to solid red `#D32F2F` with
        white ⚠ icon + bounce symbolEffect
      - Red "正在触发" capsule next to rule name
      - Whole row gets 12% red `listRowBackground`
      - Top-of-list red banner: "N 条规则正在触发" + comma-separated names
- [x] `accessibilityIdentifier`: `automation_row_<id>` (existing)
- [x] Files touched:
      - `apps/ios/Sources/TePlannerKit/Automations/Interpreters/RuleSpec.swift`
        (add `isFiring` + `firingSince` to RuleRecord)
      - `apps/ios/TePlannerApp/AutomationsHomeView.swift`
        (replace `firingKinds` engine workaround with `record.isFiring`)

### Android

- [x] Surface: AutomationsListScreen (`apps/android/app/.../automations/AutomationsListScreen.kt`)
- [x] Visible behavior: Same red tile + white ⚠ + "正在触发" capsule + 12%
      red row background. Top-of-list banner deferred (LazyColumn doesn't
      have iOS List Sections natively; can add with a sticky item later).
- [x] `Modifier.testTag(...)`: **DEFERRED** — Android automation row has no
      testTag yet; tracked in #131 (cross-platform Maestro setup).
- [x] Files touched:
      - `apps/android/core/network/.../AutomationModels.kt`
        (add `isFiring` + `firingSince` to RuleResponse)
      - `apps/android/app/.../automations/AutomationsListScreen.kt`
        (red tile + capsule)

### HarmonyOS NEXT

- [ ] **Deferred to Phase G.2** (Hub + automation CRUD slice)

---

## Maestro flow

**DEFERRED** — needs the Android testTag work first (issue #131).
Once both platforms expose `automation_row_<id>` in accessibility,
we can write `e2e/maestro/automation_firing_indicator.yaml` that:
- Boots a test user with a force-fired rule (admin-only POST to mark
  PushedAlert; doesn't exist yet)
- Asserts `automation_row_<id>` contains text "正在触发"
- Runs on both iOS sim and Android emulator with `make e2e-ios` and
  `make e2e-android`

---

## Out of scope

- The 30-min heuristic — real liveness tracking needs a separate slice
  (`PushedAlert.acknowledged_at` + per-trigger condition check at GET
  time)
- Maestro automation — needs the testTag PR first
- Top banner on Android — LazyColumn item with same content; small UI
  task, not blocking the headline feature

---

## Rollout

- Backend: deployed via `git push origin ios-development` + ssh
  `git reset --hard` + `bash start.sh -d -s` (2026-05-10 14:xx)
- iOS: code in `ios-development` branch; ships in next TestFlight build
  the user requests
- Android: built locally + verified on emulator; install via
  `make android-run` for now

---

## Lessons (delete from real feature docs; kept here as the template's worked example)

This was the *first* feature using this template. The trigger was a real
incident: a previous version of this feature shipped iOS-only, the Hub
"1 条触发中" subtitle drove the UX, and the data pipeline (`applyServerAlerts`)
was never wired in production — so the indicator never fired in the wild.
The template's "Backend / Clients / Maestro" structure exists specifically
to catch this class of "feature without a contract" bug before review.
