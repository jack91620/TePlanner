# Feature: <name>

> **One-line description** of what the user can now do that they couldn't before.

**Status:** draft / in-progress / shipped — yyyy-mm-dd
**Owner:** <name>
**Related issues / PRs:** <links if any>

---

## Backend

### Endpoints

For each new or changed endpoint, list the path + the request/response
shape **as a diff against the current `/openapi.json`** (or "new
endpoint" with the full shape). Reviewers should be able to read this
section and reproduce the wire format without opening the FastAPI source.

```
PUT /api/v1/example/{id}
  request:  { field_a: str, field_b: int? = null }
  response: { id: str, field_a: str, computed_field: bool }
```

### Migrations

Schema changes go here. State the alembic revision id when written.
"None" if the feature is API-only.

### Behavior changes (no API surface)

For backend-only changes (e.g. push fan-out, rule evaluation tweaks)
describe the observable difference for clients.

---

## Clients — acceptance per platform

Each platform must show a checked box before the feature ships. If a
platform is intentionally deferred (Phase G, future TestFlight, etc.)
say so explicitly + link the tracking issue.

### iOS

- [ ] Surface: <which screen / sheet>
- [ ] Visible behavior: <user-observable outcome — be specific about
      colors, copy, animations if they're load-bearing>
- [ ] `accessibilityIdentifier` for any new tappable element
- [ ] File(s) touched: `apps/ios/...`

### Android

- [ ] Surface: <which screen>
- [ ] Visible behavior: <same observable outcome as iOS, modulo M3
      idioms — call out *intentional* divergences>
- [ ] `Modifier.testTag(...)` matching the iOS identifier
- [ ] File(s) touched: `apps/android/...`

### HarmonyOS NEXT

- [ ] Surface: <screen> | **Deferred to Phase G.x** (link)
- [ ] (same shape as above)

---

## Maestro flow

Path to the new YAML under `e2e/maestro/`. Should run on **both**
iOS sim and Android emulator using the shared accessibility identifier.
Skip if Harmony-only.

```
e2e/maestro/<feature_name>.yaml
```

What it asserts:
- <happy path step 1>
- <happy path step 2>
- <key edge case if any>

---

## Out of scope / known gaps

What this slice intentionally doesn't do — to head off scope creep
and reviewer "shouldn't this also...?" questions.

---

## Rollout

How the change reaches users. For backend: deploy timing (server git
pull). For client: TestFlight build number when available. For
breaking schema changes: migration order.
