# Feature: Tesla OAuth callback dedup by VIN

> Stop creating duplicate user accounts when the same Tesla VIN re-authorizes.

**Status:** draft — 2026-05-10
**Owner:** dongxinbo
**Related:** post-mortem in `warm-roaming-engelbart.md` "2026-05-10 P0" section

---

## Why

iOS `getTeslaAuthUrl()` calls `GET /auth/tesla/authorize` without a
`user_id` query param (the user hasn't logged in yet). Backend
creates a new anonymous user `android_<uuid>@test.local`, returns
the user_id. iOS persists in keychain; OAuth completes; user is now
"logged in" via that anonymous account.

Problem: **every fresh install / cleared keychain / new device =
new anon account**, all bound to the same Tesla VIN. As of 2026-05-10
prod had 242 such accounts on a single VIN. The push spam incident
exposed the operational pain: telemetry write to one anon account's
state leaked through to push to that account's APNs token, even
though the user was actively using a different anon account on
their iPhone.

We deleted 240 of the 242 in cleanup, but with no code change the
leak resumes the next time a fresh install of iOS hits OAuth.

## Backend

### Endpoints

```
GET /auth/tesla/callback        ← unchanged signature
POST /auth/tesla/callback       ← unchanged signature
```

### Behavior change (no API surface)

After `exchange_and_store()` succeeds (we now have valid Tesla
tokens for whatever user_id was in the OAuth state):

1. Immediately call `tesla_client.list_vehicles()` to get the VIN(s).
2. For each VIN, query `Vehicle` table for any existing rows pointing
   to a different `user_id`.
3. If found:
   a. Pick the **oldest** matching `user_id` as canonical.
   b. Re-point the just-saved `TeslaToken` to canonical's user_id
      (i.e. delete the new TeslaToken, copy its tokens to the
      canonical user's TeslaToken row).
   c. Delete the just-created anonymous user (cascade drops empty
      AutomationRule rows; presets get re-seeded next list call).
   d. Return the canonical `user_id` in the OAuth callback response
      / page.
4. If no match: keep the new user as-is (legitimately first-time).

iOS receives the canonical `user_id`, persists in keychain, future
launches use it.

### Migrations

None — pure read + delete on existing tables.

---

## Clients — acceptance per platform

### iOS

- [ ] Surface: existing OAuth callback handler + LoginViewModel
- [ ] Visible behavior: same UX (success page → app reads user_id from
      response). Internally the user_id received MAY be a pre-existing
      user instead of a freshly-created anon.
- [ ] Files touched:
      - `apps/ios/Sources/TePlannerKit/ViewModels/LoginViewModel.swift`
        — store the returned user_id (already does)
      - `apps/ios/Sources/TePlannerKit/Services/SecureStorage.swift`
        — overwrite stored user_id with the canonical one

### Android

- [ ] Same behavior as iOS, no UI change. `AuthSession.login()` already
      consumes whatever user_id the backend returns.

### HarmonyOS NEXT

- [ ] **Deferred to Phase G.x**

---

## Maestro flow

Hard to test cleanly since it requires Tesla OAuth interaction.
Instead: a backend pytest that:
- Creates anon user A1, calls `/auth/tesla/callback` with mocked
  vehicle list returning VIN X
- Creates anon user A2, same VIN X
- Asserts A2 was deleted, A1 returned as canonical, both share the
  Tesla token

`backend/tests/test_oauth_vin_dedup.py`.

---

## Out of scope

- **Email / phone primary login**: long term, replace OAuth-as-login
  with email + Tesla-as-link. Not this slice.
- **Cleanup of historical accounts**: already done manually 2026-05-10
  (242 → 2 users).
- **`@test.local` email rename**: the anonymous-email naming is just
  cosmetic; rename when implementing email login as the primary path.

## Critical files

- `backend/app/services/tesla_auth_service.py:exchange_and_store`
- `backend/app/api/v1/auth.py:tesla_callback` (both GET + POST)
- New: `backend/app/services/tesla_auth_service.py:_dedup_by_vin` helper
- `backend/tests/test_oauth_vin_dedup.py` (new)

## Estimated cost

- 2-3 hours code + tests
- 1 hour real-device verification (need to OAuth from a fresh sim
  install + verify keychain user_id matches an existing one)
