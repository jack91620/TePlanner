# Cross-platform Maestro flows

Same YAML body, run on iOS and Android. Each cross-platform test is
two files:

```
cross_platform/
  automations_smoke_{ios,android}.yaml  # automations list reachable
  hub_smoke_{ios,android}.yaml          # status card + 3 nav cards visible
  battery_smoke_{ios,android}.yaml      # Hub → 电池管理 → BatteryView visible
_shared/
  automations_smoke.yaml
  hub_smoke.yaml
  battery_smoke.yaml
```

The shared file uses Maestro selectors keyed on the **same string**
across platforms:

| Element | iOS | Android |
|---|---|---|
| Hub status card | `accessibilityIdentifier("hub_status_card")` | `Modifier.testTag("hub_status_card")` |
| Hub automations entry card | `accessibilityIdentifier("hub_entry_automations")` | `Modifier.testTag("hub_entry_automations")` |
| Hub planning entry card | `accessibilityIdentifier("hub_entry_planning")` | `Modifier.testTag("hub_entry_planning")` |
| Hub battery entry card | `accessibilityIdentifier("hub_entry_battery")` | `Modifier.testTag("hub_entry_battery")` |
| BatteryView root | `accessibilityIdentifier("battery_view")` | `Modifier.testTag("battery_view")` |
| Per-rule list row | `accessibilityIdentifier("automation_row_<id>")` | `Modifier.testTag("automation_row_<id>")` |

Maestro's `id:` selector resolves both via the OS accessibility tree.

## Run

```bash
# iOS sim — uses the existing _helpers/ensure_logged_in.yaml
make e2e-ios FLOW=cross_platform/automations_smoke_ios.yaml

# Android emulator
make e2e-android FLOW=cross_platform/automations_smoke_android.yaml

# Or both back-to-back (after iOS sim + Android emulator are booted)
bash e2e/maestro/cross_platform/run_both.sh
```

## Authoring rule

When adding a new cross-platform flow:

1. Write the assertions in `_shared/<feature>.yaml` (no `appId`)
2. Wrap with `cross_platform/<feature>_ios.yaml` (sets appId,
   logs in via Tesla OAuth helper, runs the shared flow, screenshots)
3. Wrap with `cross_platform/<feature>_android.yaml` (sets appId,
   relaunches app to fresh state, runs the shared flow)
4. Verify the assertions touch ONLY identifiers present in both
   platforms — if the shared flow uses `id: hub_battery_ring` and
   only iOS exposes that tag, Android run will fail.

## Known limitations

- Tesla OAuth WebView on Android is currently driven manually (no
  reliable Maestro flow for it). Pre-login the emulator account.
- Android e2e accounts (`android_*@test.local`) are auto-created by
  the OAuth-without-user_id path which is being deprecated by the
  2026-05-11 OAuth-VIN-dedup work. Long-term Android tests will use
  the dedup'd canonical account.
