# Design tokens ↔ Figma sync

Single source of truth: `packages/design-tokens/tokens.json`. Three
generated artifacts:

| Artifact | Path | Purpose |
| --- | --- | --- |
| `Tokens.swift` | `apps/ios/Sources/TePlannerKit/Theme/Tokens.swift` | SwiftUI consumes this |
| `Tokens.kt` | `apps/android/core/ui/.../Tokens.kt` | Compose consumes this (Phase F) |
| `tokens-studio.json` | `packages/design-tokens/tokens-studio.json` | Tokens Studio Figma plugin consumes this |

```
                edit
       ┌──────────────────┐
       ▼                  │
  tokens.json   ────►  make tokens
       ▲                  │
       │                  ├──► Tokens.swift  (iOS code)
       │                  ├──► Tokens.kt     (Android code)
   PR back                └──► tokens-studio.json  ──► Figma
       │                                              Variables
   designer
   in Figma
```

## For developers

```bash
# Edit token spec
$EDITOR packages/design-tokens/tokens.json

# Regenerate all three artifacts
make tokens

# Commit everything — generated artifacts MUST be checked in
git add packages/design-tokens/ apps/ios/Sources/TePlannerKit/Theme/Tokens.swift \
        apps/android/core/ui/src/main/java/cloud/teplanner/android/core/ui/Tokens.kt
```

CI runs `make tokens-verify` — regenerates and fails if anything in
the three artifacts differs from committed. Catches hand-edits to
generated files and "forgot to run `make tokens`" cases.

### Token type cheatsheet

| `type` | Use for | Generates |
| --- | --- | --- |
| `color` | hex colors (alerts, accents, washes) | `Color(red:green:blue:)` |
| `dimension` | spacing, radius, opacity | `CGFloat` / `Dp` |
| `typography` | Hero numbers, code displays, splash logo | `Font` / `TextStyle` |
| `shadow` | Drop shadows (subtle/default/drawer) | `ShadowSpec` (apply via `.tokenShadow(_:)`) |
| `ios_system_color` | iOS dynamic system colors (surface.*) | `Color(.system*)` — skipped on Android + Figma |

`ios_system_color` tokens (surface.canvas/card/elevated/fill) only
appear in `Tokens.swift`. Phase F decides whether to map them to
Material 3 surface roles or use explicit light/dark hex pairs.

## For designers

Tokens Studio plugin pulls `tokens-studio.json` from GitHub →
publishes to Figma Variables in the design system file.

### One-time setup

1. Install **Tokens Studio for Figma** (Figma → Plugins → Browse).
2. Open the TePlanner Design System Figma file.
3. Run the plugin → **Settings** → **Sync** → **GitHub**:
   - Repo: `<github-owner>/TePlanner`
   - Branch: `ios-development` (or current main)
   - File path: `packages/design-tokens/tokens-studio.json`
   - Personal Access Token: a GitHub PAT with `repo` scope (designer's own)
4. **Pull** — populates Figma with the 43 tokens from JSON.
5. **Push to Figma** (plugin button) — writes tokens as Figma
   Variables, ready to use in designs.

### Making changes

The designer's edits flow back via a GitHub PR:

1. In Tokens Studio plugin, edit token values (color tweak, new
   spacing tier, etc.).
2. Plugin's **Push** button → opens GitHub PR against
   `tokens-studio.json` (designer reviews the diff before merging).
3. PR triggers `make tokens-verify` — CI will FAIL because the
   developer-side `tokens.json` hasn't been updated yet.
4. Developer pulls the PR locally, mirrors the change to
   `tokens.json` (the actual SoT), runs `make tokens`, force-pushes.
5. CI green → merge.

`tokens.json` is the authoritative source — `tokens-studio.json` is
a derived artifact. Step 4 keeps the source up-to-date; step 5
proves the generators agree.

### What the plugin won't show

The 4 `surface.*` tokens (canvas / card / elevated / fill) live only
in iOS code as `Color(.systemBackground)` references — iOS's runtime
dynamic colors. Designers see them in screenshots, not in the Figma
Variables panel. If you need to mock iOS surface backgrounds in
Figma, use these reference hexes (light mode):

| Token | Light mode | Dark mode |
| --- | --- | --- |
| `surface.canvas` | `#FFFFFF` | `#000000` |
| `surface.card` | `#F2F2F7` | `#1C1C1E` |
| `surface.elevated` | `#FFFFFF` | `#2C2C2E` |
| `surface.fill` | `#76768024` | `#76768024` |

(Source: Apple HIG semantic colors.)
