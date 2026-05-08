"""Phase 8 — connectivity channel ingest.

fleet-telemetry's connectivity stream emits CONNECTED / DISCONNECTED
records when the car opens or closes its mTLS WebSocket. We surface
these as the `vehicle.connectivity` entity so users can write rules
of the form "when vehicle goes online → re-send queued navigation"
using the existing `state_transition` trigger type.
"""

import pytest
from sqlalchemy import select

from app.db.models import AutomationState, User, Vehicle
from app.services.telemetry.consumer import _process_connectivity_record
from app.services.telemetry.mapping import map_connectivity_payload
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
        user_id=user.id, vehicle_id="42", vin=VIN, display_name="Test",
    ))
    await db_session.commit()
    return user


CONNECTED_PAYLOAD = {
    "data": {
        "ConnectionID": "abc",
        "CreatedAt": 1778226940,
        "NetworkInterface": "cellular",
        "Status": "CONNECTED",
        "Vin": VIN,
    },
    "metadata": {"txtype": "connectivity", "vin": VIN},
    "vin": VIN,
    "time": "2026-05-08T15:55:40+08:00",
}

DISCONNECTED_PAYLOAD = {
    **CONNECTED_PAYLOAD,
    "data": {**CONNECTED_PAYLOAD["data"], "Status": "DISCONNECTED"},
    "time": "2026-05-08T16:02:24+08:00",
}


def test_map_connectivity_yields_status_string():
    out = list(map_connectivity_payload(CONNECTED_PAYLOAD))
    assert out == [("vehicle.connectivity", "CONNECTED")]


def test_map_connectivity_disconnected():
    out = list(map_connectivity_payload(DISCONNECTED_PAYLOAD))
    assert out == [("vehicle.connectivity", "DISCONNECTED")]


def test_map_connectivity_skips_payload_without_status():
    assert list(map_connectivity_payload({"data": {}})) == []
    assert list(map_connectivity_payload({})) == []


async def _value(db, user_id, key):
    stmt = select(AutomationState).where(
        AutomationState.user_id == user_id, AutomationState.key == key,
    )
    row = (await db.execute(stmt)).scalar_one_or_none()
    return row.value if row else None


async def test_connectivity_record_writes_state(seeded, db_session, monkeypatch):
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    writer = TelemetryStateWriter()
    await _process_connectivity_record(writer, CONNECTED_PAYLOAD)

    assert await _value(
        db_session, seeded.id,
        telemetry_value_key("vehicle.connectivity"),
    ) == '"CONNECTED"'
    since = await _value(
        db_session, seeded.id,
        telemetry_since_key("vehicle.connectivity"),
    )
    assert since.startswith("2026-05-08T15:55:40")


async def test_connectivity_transition_advances_since(seeded, db_session, monkeypatch):
    from app.services.telemetry import consumer

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())
    writer = TelemetryStateWriter()

    await _process_connectivity_record(writer, CONNECTED_PAYLOAD)
    first_since = await _value(
        db_session, seeded.id,
        telemetry_since_key("vehicle.connectivity"),
    )
    await _process_connectivity_record(writer, DISCONNECTED_PAYLOAD)
    second_since = await _value(
        db_session, seeded.id,
        telemetry_since_key("vehicle.connectivity"),
    )
    assert second_since != first_since
    assert await _value(
        db_session, seeded.id,
        telemetry_value_key("vehicle.connectivity"),
    ) == '"DISCONNECTED"'


async def test_connectivity_engine_invoked_on_transition(seeded, db_session, monkeypatch):
    from app.services.telemetry import consumer
    from app.services.automation.engine import TickResult

    class _SessionCM:
        async def __aenter__(self):
            return db_session
        async def __aexit__(self, *a):
            pass

    monkeypatch.setattr(consumer, "async_session", lambda: _SessionCM())

    calls: list = []

    class _Engine:
        async def run_for_vehicle(self, db, *, user_id, vehicle_id, state, settings):
            calls.append({"connectivity": state.connectivity})
            return TickResult(alerts=[], pushed_count=0, cleared_count=0)

    writer = TelemetryStateWriter()
    await _process_connectivity_record(
        writer, CONNECTED_PAYLOAD, engine=_Engine(),
    )
    assert len(calls) == 1
    assert calls[0]["connectivity"] == "CONNECTED"
