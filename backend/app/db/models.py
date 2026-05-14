"""Database models."""

from datetime import datetime
from typing import Optional

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(AsyncAttrs, DeclarativeBase):
    """Base class for all models."""

    pass


class User(Base):
    """User model."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    # WeChat login fields
    openid = Column(String(64), unique=True, nullable=True, index=True)
    unionid = Column(String(64), unique=True, nullable=True)
    # Email/password login fields (for Android)
    email = Column(String(128), unique=True, nullable=True, index=True)
    password_hash = Column(String(256), nullable=True)
    # Common fields
    nickname = Column(String(64), nullable=True)
    avatar_url = Column(String(512), nullable=True)
    phone = Column(String(20), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)

    # Relationships
    tesla_tokens = relationship("TeslaToken", back_populates="user", lazy="selectin")
    vehicles = relationship("Vehicle", back_populates="user", lazy="selectin")


class TeslaToken(Base):
    """Tesla OAuth tokens."""

    __tablename__ = "tesla_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    access_token = Column(Text, nullable=False)  # Encrypted
    refresh_token = Column(Text, nullable=False)  # Encrypted
    expires_at = Column(DateTime, nullable=False)
    token_type = Column(String(20), default="Bearer")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="tesla_tokens")


class Vehicle(Base):
    """Tesla vehicle linked to user."""

    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(String(64), nullable=False, index=True)  # Tesla vehicle ID
    vin = Column(String(17), nullable=True)
    display_name = Column(String(64), nullable=True)
    model = Column(String(32), nullable=True)  # e.g., "Model Y", "Model 3"
    color = Column(String(32), nullable=True)
    battery_capacity_kwh = Column(Float, nullable=True)
    is_primary = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 2026-05-13: cached vehicle_config (migration 0011). These are
    # factory-set and never change for a given VIN — fetch once,
    # serve from DB forever after. Drives client-side capability
    # picker filtering (hide 天窗 on Model 3/Y, hide 充电口控制 on
    # manual-port trims). All nullable so the first /state call
    # against an unpopulated row degrades to "show every capability".
    car_type = Column(String(32), nullable=True)
    roof_color = Column(String(32), nullable=True)
    motorized_charge_port = Column(Boolean, nullable=True)
    config_fetched_at = Column(DateTime, nullable=True)

    # Relationships
    user = relationship("User", back_populates="vehicles")


class AutomationRule(Base):
    """Declarative automation rule — Phase 10.2 replaces the hardcoded
    Python rule classes. `spec_json` is the rule body (trigger /
    conditions / actions); `preset_id` is non-null for the 4 seeded
    presets (camp / sentry / cabin / charge complete). User-authored
    rules added in Phase 10.3 have `preset_id = NULL`.
    """

    __tablename__ = "automation_rules"

    id = Column(String(36), primary_key=True)  # uuid
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    preset_id = Column(String(64), nullable=True)
    name = Column(String(128), nullable=False)
    enabled = Column(Boolean, default=True, nullable=False)
    spec_json = Column(Text, nullable=False)
    version = Column(Integer, default=1, nullable=False)
    # Phase A.2 — user-overrideable display order. NULL means "use the
    # canonical preset/created-at ordering" (preserves legacy behavior).
    # Set via PUT /automations/order; engine + listing both honor it.
    display_order = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class UserSetting(Base):
    """Phase A.5 — opaque cross-device key/value preference store.

    iOS / Android / Harmony clients all sync UI prefs (charge-limit
    targets, departure window length, hub card visibility, etc.)
    through this table so a setting tweaked on one device shows up on
    the next. Values are JSON-encoded text — we don't enforce schema
    server-side because settings churn fast and per-key columns would
    couple migrations to client UI changes.

    UNIQUE(user_id, key) is what makes upsert work cleanly.
    """

    __tablename__ = "user_setting"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    key = Column(String(80), nullable=False)
    value_json = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ChargingSession(Base):
    """Phase A.4 — one charging session.

    Mirrors iOS Sources/TePlannerKit/Models/ChargingSession.swift
    field-for-field. The iOS ChargingSessionTracker writes one row
    on plug-in (end_at NULL = ongoing) and finalises on the next
    state transition. iOS Phase D will swap the local tracker for
    POST /sessions calls, then for a server-side telemetry consumer.

    ``client_session_id`` lets the same session round-trip cleanly
    from local-only state (UUID generated on iOS) into the backend
    without dup'ing on retries.
    """

    __tablename__ = "charging_session"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=True, index=True)
    client_session_id = Column(String(64), nullable=True, unique=True, index=True)
    started_at = Column(DateTime, nullable=False)
    ended_at = Column(DateTime, nullable=True)
    start_soc = Column(Integer, nullable=True)
    end_soc = Column(Integer, nullable=True)
    start_range_km = Column(Float, nullable=True)
    end_range_km = Column(Float, nullable=True)
    energy_added_kwh = Column(Float, nullable=True)
    location_name = Column(String(128), nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    ended_as_complete = Column(Boolean, nullable=True)
    source = Column(String(20), nullable=False, default="ios")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ScheduledDeparture(Base):
    """Phase A.3 — user's planned next departure.

    Mirrors iOS Sources/TePlannerKit/Models/ScheduledDeparture.swift —
    one active row per user, latest write replaces (UNIQUE user_id).
    iOS targets a specific vehicle via ``vehicle_id``; the cron tick
    consumer reads this row to dispatch the preheat reminder
    ``lead_minutes`` ahead of ``departure_at_utc``.

    Recurring departures (work commute, etc.) aren't modelled here — a
    future ``repeats_dow_bitmask INT`` column would extend it without
    touching the API.
    """

    __tablename__ = "scheduled_departure"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False,
        unique=True, index=True,
    )
    vehicle_id = Column(String(64), nullable=True)
    label = Column(String(64), nullable=True)
    departure_at_utc = Column(DateTime, nullable=False)
    lead_minutes = Column(Integer, nullable=False, default=15)
    target_charge_soc = Column(Integer, nullable=True)
    enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ActiveTrip(Base):
    """Sequential-nav state for a multi-stop charging route (migration
    0012).

    Tesla's Fleet API navigation_request only accepts ONE destination
    and the next call replaces the previous, not append. To make
    TePlanner-planned routes (with non-Tesla charging stops) actually
    drive the user via the car's native nav, we send the stops one at
    a time. On arrival at stop N (detected by cron or confirmed by
    user tap), advance to stop N+1.

    One ``active`` row per user — start_trip on a user with an
    existing active row cancels the old one.

    Columns:
    - stops_json: ordered list of `{lat, lng, address, kind: "charging"|
      "final", soc_target?, station_id?}`. Final element is the
      destination; preceding elements are charging stops.
    - polyline_json: encoded polyline of the original route. Used by
      the off-route detector (lateral distance > threshold → replan).
    - current_segment: 0-based index of the stop currently sent to
      the car. -1 == not yet started.
    - status: "active" | "completed" | "cancelled".
    - replan_count / last_replan_reason: diagnostics. Reason is also
      surfaced in push notifications + (truncated) in the next stop's
      address string so the car screen shows it.
    - last_position_*: cron monitor stash; drives arrival detection.
    """

    __tablename__ = "active_trip"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    stops_json = Column(Text, nullable=False)
    polyline_json = Column(Text, nullable=True)
    current_segment = Column(Integer, nullable=False, default=-1)
    status = Column(String(16), nullable=False, default="active")
    replan_count = Column(Integer, nullable=False, default=0)
    last_replan_reason = Column(String(255), nullable=True)
    last_position_lat = Column(Float, nullable=True)
    last_position_lng = Column(Float, nullable=True)
    last_position_at = Column(DateTime, nullable=True)
    # Phase 3a (migration 0013) — debounce for the "电量不足" push.
    # NULL = never warned; on each tick the monitor checks
    # `now - last_soc_warning_at > WARN_DEBOUNCE` before firing again.
    last_soc_warning_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class AutomationSnooze(Base):
    """Phase A.1 — per-rule snooze ledger.

    Pause a rule from firing for a window. The engine consults this
    table on every tick: a row whose ``snoozed_until_utc`` is in the
    future suppresses evaluation entirely (no alert emitted, no
    side-effects). DELETE clears immediately. UNIQUE on ``rule_id`` —
    re-snoozing the same rule REPLACEs the prior row.
    """

    __tablename__ = "automation_snooze"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    rule_id = Column(String(36), nullable=False, unique=True, index=True)
    snoozed_until_utc = Column(DateTime, nullable=False)
    reason = Column(String(128), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AutomationState(Base):
    """Per-rule scratchpad keyed by (user_id, vehicle_id, key). Used by
    automation rules to remember "first time I observed X on" timestamps
    across polling ticks. Stored as ISO date strings for portability;
    rules treat None as absent. Mirrors iOS InMemoryAutomationStateMemory
    but persisted so engine state survives backend restarts.
    """

    __tablename__ = "automation_state"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    key = Column(String(80), nullable=False)
    value = Column(String(64), nullable=True)  # ISO 8601 datetime string
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PushedAlert(Base):
    """De-duplication ledger: tracks which (user, vehicle, kind) alerts
    have been pushed at critical severity, so the polling tick only
    fires APNs on the not-critical → critical transition (matching the
    iOS LocalNotificationScheduler.applyAlerts behaviour).
    """

    __tablename__ = "pushed_alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    kind = Column(String(40), nullable=False)
    pushed_at = Column(DateTime, default=datetime.utcnow)
    cleared_at = Column(DateTime, nullable=True)


class DeviceToken(Base):
    """APNs device push token registered by an iOS device.

    One user can have multiple devices (iPhone + iPad). On each app
    launch the iOS client posts its current token; we upsert by
    (user_id, token) so reinstalls / token rotations get a fresh row
    while keeping the user's other active devices intact.
    """

    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(200), nullable=False, index=True)
    # Phase E — accepted values: "apns" (iOS APNs), "jpush" (Android
    # via JPush aggregator), "harmony" (HarmonyOS NEXT via Huawei
    # Push Kit). The legacy default "ios" is back-filled to "apns" by
    # migration 0007.
    platform = Column(String(20), default="apns")
    # Phase E — provider-specific identifier when it differs from the
    # raw device token. JPush returns a `registration_id` separate
    # from the OEM push token; Huawei Push Kit returns a token whose
    # format / length doesn't match APNs hex tokens. Stays NULL for
    # APNs, where `token` already is the provider-acceptable identifier.
    provider_token = Column(String(255), nullable=True)
    bundle_id = Column(String(128), nullable=True)
    last_seen_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)


class PendingWait(Base):
    """Phase 11 — state-gated wait actions.

    Rules can chain ``wait_for_state`` action: dispatch a primary
    action, then sit waiting for an entity predicate to match (e.g.
    ``vehicle.inside_temp_c >= 20``). When the next telemetry-driven
    engine eval sees the predicate satisfied, it emits the chained
    ``then`` action (a notify or invoke) and resolves this row.

    Default timeout 15 minutes; ``resolved_at`` stamps on success,
    ``timed_out_at`` on deadline. Cap 1 unresolved row per
    ``(rule_id, user, vehicle)`` — newest wins; any prior unresolved
    row gets timed_out_at when superseded.
    """

    __tablename__ = "pending_wait"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)
    rule_id = Column(String(64), nullable=True, index=True)
    predicate_json = Column(Text, nullable=False)
    then_action_json = Column(Text, nullable=False)
    deadline_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    resolved_at = Column(DateTime, nullable=True)
    timed_out_at = Column(DateTime, nullable=True)


class CommandQueue(Base):
    """Phase 10 — sleep-aware command dispatch.

    When a user invokes a capability and the car is offline (per the
    last-seen ``tel:vehicle.connectivity:value`` row), we don't want
    to bang on a sleeping vehicle. Capabilities tagged with
    ``dispatch_policy: queue`` (the default) park the request here;
    when the next ``CONNECTED`` connectivity event arrives, the
    consumer drains rows oldest-first.

    Rows are pruned by ``dropped_at`` after ``ttl_seconds`` — a 30-min
    cron-tick sweep handles expiry so stale "preheat at 7am" doesn't
    fire at noon when the car finally wakes.
    """

    __tablename__ = "command_queue"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)  # VIN
    capability = Column(String(80), nullable=False)
    params_json = Column(Text, nullable=False)
    dispatch_policy = Column(String(32), nullable=False, default="queue")
    ttl_seconds = Column(Integer, nullable=False, default=1800)  # 30 min
    queued_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    sent_at = Column(DateTime, nullable=True)
    dropped_at = Column(DateTime, nullable=True)
    error = Column(String(256), nullable=True)


class CommandPending(Base):
    """Phase 9 — closed-loop VCP confirmation ledger.

    Every successful capability dispatch with observable telemetry
    writes one row here. The Telemetry-driven pending_resolver checks
    on each engine tick whether the snapshot now matches the
    capability's ``expected_state``; on match it stamps ``confirmed_at``,
    on timeout it stamps ``timed_out_at``. iOS polls
    ``/api/v1/commands/pending`` to flip the action button from
    "执行中…" → "已关闭" / "超时".

    Capabilities without observable telemetry (preheat, navigation,
    charge_limit until we add a tel:* entity for it) skip writing a
    row entirely — the iOS UI confirms on HTTP 2xx alone.
    """

    __tablename__ = "command_pending"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    vehicle_id = Column(String(64), nullable=False, index=True)  # VIN
    capability = Column(String(80), nullable=False)
    # JSON: {"vehicle.climate.keeper_mode": 0}.  pending_resolver loops
    # this dict and matches each entry against the snapshot.
    expected_state_json = Column(Text, nullable=False)
    dispatched_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    confirmed_at = Column(DateTime, nullable=True)
    timed_out_at = Column(DateTime, nullable=True)


class RoutePlan(Base):
    """Saved route plans."""

    __tablename__ = "route_plans"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)

    # Route details
    origin_lat = Column(Float, nullable=False)
    origin_lng = Column(Float, nullable=False)
    origin_address = Column(String(256), nullable=True)
    dest_lat = Column(Float, nullable=False)
    dest_lng = Column(Float, nullable=False)
    dest_address = Column(String(256), nullable=True)

    # Results
    total_distance_km = Column(Float, nullable=True)
    total_duration_minutes = Column(Integer, nullable=True)
    charging_stops_json = Column(Text, nullable=True)  # JSON string
    polyline_json = Column(Text, nullable=True)  # JSON string

    # Status
    status = Column(String(20), default="pending")  # pending, completed, sent_to_car
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class OAuthState(Base):
    """Tesla OAuth pending state. Lives between GET /auth/tesla/authorize
    and the callback redirect. Previously kept in a module-level dict
    `_oauth_states` — that broke as soon as uvicorn forked >1 worker
    (each worker has its own copy, so authorize-on-A + callback-on-B
    failed with "Invalid or expired authorization" 100% of the time
    that fork crossed worker boundaries).

    Now stored in DB so all workers see the same state. The state
    string is the OAuth CSRF token (URL-safe random) — Tesla returns
    it on the callback so we can look up code_verifier + user_id.

    Rows are popped on use (one-shot). A nightly job (TODO) sweeps
    rows older than 10 minutes that were never claimed (Tesla
    abandoned the auth flow).
    """

    __tablename__ = "oauth_state"

    state = Column(String(128), primary_key=True)
    code_verifier = Column(String(128), nullable=False)
    user_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class Share(Base):
    """Cross-platform share code for a single automation rule or hub
    quick action. Owner POSTs a payload + type, server returns a
    6-char base32-friendly code; recipients GET by code to import.

    Codes use the 32-char alphabet ABCDEFGHJKLMNPQRSTUVWXYZ23456789
    (no 0/O/1/I/l). 6 chars = ~1.07B combinations; INSERT retries
    on collision (birthday collision starts at ~32k codes).

    Payload is JSON text — keep schema enforcement on the import-side
    parsers so we can ship payload extensions without backend
    migrations. The payload is stripped before storage: no user_id,
    no vehicle_id, no source action_id (importer mints fresh ids).
    """

    __tablename__ = "shares"

    code = Column(String(16), primary_key=True)
    share_type = Column(String(16), nullable=False)
    payload_json = Column(Text, nullable=False)
    owner_user_id = Column(
        Integer, ForeignKey("users.id"), nullable=True, index=True,
    )
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    revoked_at = Column(DateTime, nullable=True)
    view_count = Column(Integer, default=0, nullable=False)
    min_app_version = Column(String(32), nullable=True)
