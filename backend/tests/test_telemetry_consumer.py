"""End-to-end test of consumer.py's V-record processing path, minus
the actual ZMQ socket. Feeds raw fleet-telemetry JSON payloads into
``_process_v_record`` and asserts the right AutomationState rows
land in the DB.

This is the closest we can get to a faithful Phase-4 integration
test without a running fleet-telemetry binary; it pins the seam
between mapping → state_writer + the VIN→user resolution.
"""

from datetime import datetime, timezone

import pytest
from sqlalchemy import select

from app.db.models import AutomationState, User, Vehicle
from app.services.telemetry.consumer import _process_v_record
from app.services.telemetry.state_writer import (
    TelemetryStateWriter,
    telemetry_since_key,
    telemetry_value_key,
)


VIN = "LRWYGCFS0NC517553"


@pytest.fixture
async def seeded(db_session):
    user = User(email="t@t.com", password_hash="x", is_active=True)
    db_session.add(user)
    await db_session.flush()
    db_session.add(Vehicle(
        user_id=user.id,
        vehicle_id="42",
        vin=VIN,
        display_name="Test",
    ))
    await db_session.commit()
    return user


# Real production payload from 2026-05-08 — pinned for regression.
INITIAL_V = {
    "data": {
        "BatteryLevel": 52.988748241912795,
        "CabinOverheatProtectionMode": "CabinOverheatProtectionModeStateFanOnly",
        "ChargeState": "Idle",
        "ClimateKeeperMode": "ClimateKeeperModeStateOff",
        "DoorState": {"DriverFront": False},
        "FdWindow": "WindowStateClosed",
        "Gear": "<invalid>",
        "Locked": True,
        "SentryMode": "SentryModeStateOff",
        "Soc": 52.91842475386779,
        "Vin": VIN,
        "CreatedAt": "2026-05-08T07:37:05Z",
    },
    "metadata": {"txtype": "V", "vin": VIN},
    "vin": VIN,
    "time": "2026-05-08T15:37:05+08:00",
}

CAMP_MODE_TRANSITION_V = {
    "data": {
        "ClimateKeeperMode": "ClimateKeeperModeStateParty",
        "Vin": VIN,
        "CreatedAt": "2026-05-08T07:37:34Z",
        "IsResend": False,
    },
    "metadata": {"txtype": "V", "vin": VIN},
    "vin": VIN,
    "time": "2026-05-08T15:37:34+08:00",
}


async def _query(db, user_id: int, key: str):
    stmt = select(AutomationState).where(
        AutomationState.user_id == user_id,
        AutomationState.key == key,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    return row.value if row else None


async def test_initial_record_writes_all_known_entities(seeded, db_session, monkeypatch):
    # Hijack the consumer's async_session() so it uses the test session
    # instead of opening a fresh one against the production DB.
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    writer = TelemetryStateWriter()
    await _process_v_record(writer, INITIAL_V)  # engine omitted: write-only path

    # Six known entities populated (DoorState/FdWindow/Gear-invalid are skipped).
    expected = {
        "vehicle.climate.keeper_mode": "0",
        "vehicle.sentry_mode_on": "false",
        "vehicle.cabin_overheat_protection_on": "true",
        "vehicle.charging.state": "\"Disconnected\"",
        "vehicle.battery_level": "52",
        "vehicle.locked": "true",
    }
    for entity, expected_value in expected.items():
        actual = await _query(db_session, seeded.id, telemetry_value_key(entity))
        assert actual == expected_value, f"{entity}: {actual!r}"


async def test_camp_mode_transition_only_changes_keeper(seeded, db_session, monkeypatch):
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())
    writer = TelemetryStateWriter()

    await _process_v_record(writer, INITIAL_V)
    sentry_since_first = await _query(
        db_session, seeded.id, telemetry_since_key("vehicle.sentry_mode_on")
    )

    await _process_v_record(writer, CAMP_MODE_TRANSITION_V)

    # Sentry's `since` did NOT advance — the transition payload had no
    # SentryMode field, so we never re-stamped it.
    sentry_since_after = await _query(
        db_session, seeded.id, telemetry_since_key("vehicle.sentry_mode_on")
    )
    assert sentry_since_first == sentry_since_after

    # Keeper's `since` advanced to the second payload's CreatedAt.
    keeper_since = await _query(
        db_session, seeded.id, telemetry_since_key("vehicle.climate.keeper_mode")
    )
    expected = datetime(2026, 5, 8, 7, 37, 34, tzinfo=timezone.utc).isoformat()
    assert keeper_since == expected
    keeper_value = await _query(
        db_session, seeded.id, telemetry_value_key("vehicle.climate.keeper_mode")
    )
    assert keeper_value == "3"


async def test_transition_invokes_engine_run_for_vehicle(seeded, db_session, monkeypatch):
    """Phase 6: every successful transition write must drive the engine
    so APNs pushes fire within seconds of state change. Pin this on a
    Camp Mode flip — the engine should be called once with the new
    snapshot reconstructed from the just-written tel:* rows.
    """
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    calls: list[dict] = []

    class _FakeEngine:
        async def run_for_vehicle(self, db, *, user_id, vehicle_id, state, settings):
            calls.append({
                "user_id": user_id, "vehicle_id": vehicle_id,
                "keeper_mode": state.climate_keeper_mode,
            })
            from app.services.automation.engine import TickResult
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    writer = TelemetryStateWriter()
    # Separate debounce dicts so we don't coalesce — we want to see
    # both transitions individually drive the engine.
    await _process_v_record(
        writer, INITIAL_V, engine=_FakeEngine(), debounce_until={},
    )
    await _process_v_record(
        writer, CAMP_MODE_TRANSITION_V, engine=_FakeEngine(), debounce_until={},
    )

    # Both V records had transitions → engine called twice.
    assert len(calls) == 2, calls
    assert calls[0]["vehicle_id"] == VIN
    # Second invocation sees keeper_mode=3 from the just-written tel row.
    assert calls[-1]["keeper_mode"] == 3


async def test_debounce_coalesces_burst_transitions(seeded, db_session, monkeypatch):
    """Within the 500 ms window, two adjacent transitions for the same
    (user, vehicle) collapse into one engine call. Real-world traffic
    is bursty (Tesla can ship 5+ field deltas in the same second), and
    we don't want APN spam."""
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    calls: list = []

    class _FakeEngine:
        async def run_for_vehicle(self, *a, **kw):
            calls.append(1)
            from app.services.automation.engine import TickResult
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    writer = TelemetryStateWriter()
    debounce: dict = {}
    await _process_v_record(
        writer, INITIAL_V, engine=_FakeEngine(), debounce_until=debounce,
    )
    await _process_v_record(
        writer, CAMP_MODE_TRANSITION_V,
        engine=_FakeEngine(), debounce_until=debounce,
    )

    # Same debounce dict + back-to-back calls → only first one drives
    # the engine; second is squashed.
    assert len(calls) == 1


async def test_no_transition_skips_engine(seeded, db_session, monkeypatch):
    """A duplicate value-no-change V record must NOT drive the engine.
    Avoids unnecessary DB churn + push spam on battery-level heartbeats.
    """
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    calls: list[dict] = []

    class _FakeEngine:
        async def run_for_vehicle(self, db, *, user_id, vehicle_id, state, settings):
            calls.append({"user_id": user_id})
            from app.services.automation.engine import TickResult
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    writer = TelemetryStateWriter()
    debounce: dict = {}
    # First record establishes baseline (transitions=7) → engine called.
    await _process_v_record(writer, INITIAL_V, engine=_FakeEngine(), debounce_until=debounce)
    assert len(calls) == 1
    # Replay the SAME payload — values match cache, transitions=0,
    # engine must NOT be called again.
    await _process_v_record(writer, INITIAL_V, engine=_FakeEngine(), debounce_until=debounce)
    assert len(calls) == 1


async def test_unmapped_vin_silently_skipped(db_session, monkeypatch):
    """Telemetry events for VINs not in the Vehicle table must not
    crash the consumer or pollute another user's state."""
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    writer = TelemetryStateWriter()
    payload = dict(INITIAL_V)
    payload["data"] = dict(payload["data"], Vin="LRWYGCFS0NC999999")
    payload["metadata"] = {"txtype": "V", "vin": "LRWYGCFS0NC999999"}
    payload["vin"] = "LRWYGCFS0NC999999"

    # Should not raise.
    await _process_v_record(writer, payload)

    rows = (await db_session.execute(select(AutomationState))).scalars().all()
    assert rows == []
