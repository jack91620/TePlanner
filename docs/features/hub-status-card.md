# Component: HubStatusCard

> Top card on Hub showing vehicle state at a glance: name, connection
> badge, battery ring, range hero, status chips, and (when known) the
> car's current address.

**Status:** iOS shipped — 2026-04-xx (pre-tokens); spec'd for cross-platform reuse — 2026-05-13
**Owner:** dongxinbo
**Related:** First component to use the design-token sync pipeline ([Tier 3](../design-tokens-figma-sync.md)). Reference for Phase F Android port.

---

## Intent

This document is **not** a new-feature spec. The component exists on
iOS today (`HubView.swift:478-529`). The doc:

1. Locks the visual contract via design tokens, so the Android port
   and any future Figma redesign stay aligned.
2. Lists every element → token binding so a designer can rebuild the
   frame in Figma using the Variables / Styles we synced in Tier 1.
3. Names accessibility identifiers so Maestro flows cover both
   platforms with the same selectors.

---

## Anatomy

```
┌──────────────────────────────────────────────────┐
│  ┌──────────────┐                                │
│  │ displayName  │  ⬤ 充电中            <stateBadge>│   ← row 1 (name + state)
│  └──────────────┘                                │
│                                                  │
│   ╭─────╮                                        │
│   │ 75% │   413                                  │   ← row 2 (ring + range hero)
│   │ ▮▮▮ │   km 续航                              │
│   ╰─────╯                                        │
│                                                  │
│  ┌──❄──┐ ┌──⚡──┐ ┌──🚗──┐ (chips wrap)          │   ← row 3 (status chips, flow layout)
│  │ 空调 │ │ 充电 │ │ 哨兵 │                       │
│  └──────┘ └──────┘ └──────┘                       │
│                                                  │
│  ▾ 浦东新区 xxx 路 123 号                         │   ← row 4 (location, optional)
└──────────────────────────────────────────────────┘
```

iOS source: `apps/ios/TePlannerApp/HubView.swift` — `statusCard` (line
478) + `batteryRing` (747) + `stateBadge` (802) + `chipsSection`
(637).

---

## Token bindings

### Container

| Element | Property | Token | Notes |
| --- | --- | --- | --- |
| Card | background | `surface.card` (Figma Variable) via `.thinMaterial` | iOS uses `.thinMaterial` which approximates `surfaceCard` with translucency over the Hub background; Figma fills with solid `surfaceCard` |
| Card | corner radius | `radius.hub_card` = 14 ✅ | Dedicated radius for Hub thinMaterial cards (13 sites use this — see tokens.json comment) |
| Card | inner padding | `spacing.lg` = 16 ✅ | Normalized from one-off `padding(18)` |
| Card | inner vertical gap | `spacing.md_plus` = 14 ✅ | |

### Row 1 — name + state

| Element | Property | Token / Variable |
| --- | --- | --- |
| `displayName` text | font | Figma **Text style** "title3 semibold" (no token — uses SwiftUI built-in `.title3.weight(.semibold)`. Candidate for `typography.heading.card`.) |
| `displayName` text | color | system label primary (no token) |
| `stateBadge` icon + label | font | SwiftUI `.caption.weight(.semibold)` |
| `stateBadge` color (waking) | foreground | `color.state.waking` ✅ (systemOrange) |
| `stateBadge` color (ready) | foreground | `color.state.ready` ✅ (systemGreen) |
| `stateBadge` color (offline) | foreground | `color.state.offline` ✅ (systemGray) |
| `stateBadge` color (error) | foreground | `color.state.error` ✅ (systemRed) |

iOS emits these as `Color(.systemX)` for runtime Dark Mode adaptation.
Tokens Studio export uses Apple's documented light-mode hex equivalents
(e.g. `#FF9500` for systemOrange) so the designer can bind them in
Figma — the `description` field on each Variable flags it as
"runtime is dynamic" so designers know the Figma hex is an approximation.

### Row 2 — ring + range

| Element | Property | Token / Variable |
| --- | --- | --- |
| Ring track | stroke | `Color.primary.opacity(Tokens.colorRingTrackAlpha)` ✅ (`color.ring.track_alpha` = 0.08) |
| Ring fill | stroke | Battery-tier-driven via `batteryColor(for:)`: `<20% → color.battery.critical`, `<50% → low`, `<80% → normal`, `>=80% → full` ✅ |
| Ring stroke width | line width | `10` (no token — fixed pixel) |
| Ring diameter | frame | `92` (no token) |
| Ring center SOC text | font | `typography.metric.compact` = 22pt bold monoDigit ✅ |
| Ring center SOC text | color | same as ring fill (battery-level-driven) |
| Battery icon below SOC | font | SwiftUI `.caption` |
| HStack ring↔range gap | spacing | `spacing.xl` = 24 ✅ |
| Range number | font | `typography.metric.hero` = 44pt semibold monoDigit ✅ |
| Range number | color | system label primary (known state) / secondary (unknown) |
| "km 续航" caption | font | SwiftUI `.caption` |
| "km 续航" caption | color | system label secondary |

### Row 3 — status chips

| Element | Property | Token / Variable |
| --- | --- | --- |
| Chip background | fill | `<chip.color>.opacity(0.12)` — color varies by chip type (空调 / 充电 / 哨兵 ...). **Each chip kind = a token in `chip.<kind>.bg`** with 0.12 alpha |
| Chip text + icon color | foreground | `<chip.color>` (full alpha) |
| Chip text | font | SwiftUI `.caption2.weight(.medium)` |
| Chip padding | h / v | iOS literal `8` / `4` = `spacing.sm` / `spacing.xs` ✅ |
| Chip shape | clip | Capsule (= corner radius `radius.capsule` = 50, but auto-pill on iOS Capsule shape) |
| Chip row gap | spacing | `6` (no token — between `spacing.xs=4` and `spacing.sm=8`) |

### Row 4 — location (optional)

| Element | Property | Token / Variable |
| --- | --- | --- |
| Icon `location.fill` + text | font | SwiftUI `.caption` |
| Text color | foreground | system label secondary |
| Visibility | conditional | only when `viewModel.locationName != nil` |

---

## State matrix

| Vehicle state | stateBadge | batteryRing center | Range hero | Chip row |
| --- | --- | --- | --- | --- |
| `idle` / `loading` | `ProgressView` spinner | "—" (secondary) | "—" + "续航未知" | hidden |
| `waking` | "连接中" + moon.zzz, orange | "—" (secondary) | last known or "—" | hidden |
| `ready` (charging) | "充电中" + ⬤, green | actual SOC + colored icon | actual km, primary | populated |
| `ready` (complete) | "充电完成" + ⬤, green | actual SOC + colored icon | actual km, primary | populated |
| `ready` (idle) | "在线" + ⬤, green | actual SOC + colored icon | actual km, primary | populated |
| `offline` | "离线" + slash, gray | last known SOC | last known km | last known |
| `error(msg)` | msg + warning, red, 1-line | last known or "—" | last known or "—" | last known |

---

## Clients — acceptance per platform

### iOS

- [x] Surface: `HubView.swift:478` (`statusCard` computed property)
- [x] `accessibilityIdentifier`: `hub_status_card` (parent) + `hub_battery_ring` (ring) — already in code
- [x] All `typography.metric.*` tokens applied ✅ (Tier 2 sweep)
- [x] Card padding `18` → `Tokens.spacingLg` (16) ✅
- [x] Corner radius `14` → `Tokens.radiusHubCard` (14) ✅ — promoted to dedicated radius (13 sites use it)
- [x] 4 state-badge colors → `Tokens.colorState{Waking,Ready,Offline,Error}` ✅
- [x] 4 battery-tier colors → `Tokens.colorBattery{Critical,Low,Normal,Full}` ✅
- [x] Ring track opacity → `Tokens.colorRingTrackAlpha` ✅

### Android

- [ ] Surface: `apps/android/app/.../hub/HubScreen.kt` (does not exist yet — Phase F)
- [ ] Visible behavior: 1:1 match the iOS state matrix above, modulo M3 idioms:
  - `Surface(color = MaterialTheme.colorScheme.surfaceContainerLow)` ≈ `.thinMaterial`
  - `CircularProgressIndicator` replaces SwiftUI's `Circle().trim(...)`
  - Chip → M3 `AssistChip` or `FilterChip` with custom container color
- [ ] `Modifier.testTag("hub_status_card")` + `Modifier.testTag("hub_battery_ring")`
- [ ] Compose `Tokens.kt` symbols already generated and ready: `typographyMetricHero`, `typographyMetricCompact`, `spacingMdPlus`, `radiusCard` etc.
- [ ] File(s) to add: `apps/android/app/src/main/java/cloud/teplanner/android/hub/HubStatusCard.kt`

### HarmonyOS NEXT

- [ ] **Deferred to Phase G.1** (Hub landing slice — first Harmony screen)

---

## Maestro flow

Existing: `e2e/maestro/01_hub_smoke.yaml` already asserts
`hub_status_card` and `hub_battery_ring` visibility post-login. No
new flow needed for this spec — it's documentation of an existing
component, not a feature change.

When Android port lands, the same flow should run via
`make e2e-android` once `Modifier.testTag(...)` matches the iOS
identifiers.

---

## Design checklist — Figma frame

For the designer rebuilding this card in Figma:

1. **Create a frame** `HubStatusCard`, 360×auto (typical iPhone 17 card width).
2. **Background**: rectangle, corner radius bound to Variable `radius/hub_card` (14), fill bound to color Variable `color/surface/card` (`#F2F2F7` — Apple light-mode `secondarySystemBackground`; runtime is dynamic on iOS, designer's hex is the light-mode approximation).
3. **Row 1 HStack**:
   - Left text: bind to **Text style** `typography/...` (not present — use Figma's built-in `Title 3 SemiBold` or create new Text style `heading/card`)
   - Right: state badge (4 variants — design at least 1, list others in component description)
4. **Row 2 HStack** spacing 24px (Variable `number/spacing/xl`):
   - 92×92 ring (4 variants for battery tier — colors hardcoded for now)
   - Range text bound to Text style `typography/metric/hero` ✅
   - "km 续航" caption — Text style `typography/...` (Figma built-in `Caption Regular`)
5. **Row 3** auto-layout wrap with 6px gap, each chip is a 24×auto pill, color-tinted at 12% opacity.
6. **Row 4** optional row (in Figma: a component property `hasLocation: bool` that hides/shows this row).

**Variables you can directly bind** (all 57 tokens minus typography/shadow which live in Styles):
- `number/spacing/{xs,sm,sm_plus,md,md_plus,lg,xl,xxl}` (auto-layout gaps + paddings)
- `number/radius/{card,tile,capsule,hub_card}` (corner radii)
- `number/color/ring/track_alpha` + `number/color/badge/*_alpha` + `number/color/wash/*_alpha` (opacity)
- `color/alert/...`, `color/trigger_accent/...`, `color/badge/...`, `color/wash/...` (real hex)
- `color/state/{waking,ready,offline,error}` (light-mode approximation of iOS systemColor)
- `color/battery/{critical,low,normal,full}` (light-mode approximation of iOS systemColor)
- `color/surface/{canvas,card,elevated,fill}` (light-mode approximation of iOS dynamic surface)

**Text styles** (typography composites — go through Figma Styles panel, not Variables):
- `typography/metric/{hero,compact}`, `typography/code/{display,input}`,
  `typography/placeholder_icon/{sm,md,lg}`, `typography/splash/logo`

**Effect styles** (shadow composites — Figma Styles, not Variables):
- `shadow/{subtle,default,drawer}`

When you finish the frame, send the URL with `?node-id=<X>` and I'll
read it via Figma MCP to confirm token bindings match this spec.

---

## Out of scope (for this slice)

- `chip.<kind>.bg` tokens — chip colors are per-action-kind (空调 / 充电 / 哨兵 ...) and currently live on the `StatusChip` model. Tokenize when consolidating the chip color palette across HubQuickActions + status chip rows.
- Top-level `typography/heading/card` token — currently uses SwiftUI built-in `.title3.weight(.semibold)`. Probably worth a token when we add the second card-header instance.
- Android implementation — Phase F.
- Dark-mode hex pairs for `ios_system_color` tokens in Tokens Studio export — currently light-mode only. Phase F will need light + dark Variables modes; defer to that slice.

---

## Rollout

- iOS: already in production via the Hub. No behavior change in this slice — purely documentation.
- Android: ships with Phase F Hub screen.
- Harmony: ships with Phase G.1.
