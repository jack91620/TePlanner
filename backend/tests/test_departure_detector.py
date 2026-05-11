"""DepartureDetector — emit user_departure event on the door close
edge while parked. Mirrors how Tesla's own app fires "you left X"
alerts: at the moment the user gets out, not after some duration.
"""

from datetime import datetime

import pytest
from sqlalchemy import select

from app.db.models import AutomationState, User
from app.services.telemetry.departure_detector import (
    DEPARTURE_EVENT_KEY,
    DepartureDetector,
)

VIN = "LRWYGCFS0NC517553"


async def _user(db_session, email):
    u = User(email=email, password_hash="x", is_active=True)
    db_session.add(u)
    await db_session.commit()
    return u


def _frame(door_open=None, shift=None) -> dict:
    """Build a frame_entities dict like map_v_payload returns."""
    out: dict = {}
    if door_open is not None:
        out["vehicle.door_open"] = door_open
    if shift is not None:
        out["vehicle.shift_state"] = shift
    return out


async def test_emits_on_close_after_park(db_session):
    user = await _user(db_session, "dep-1@t.com")
    detector = DepartureDetector()

    # Frame 1: door opened (P + door_open=true)
    fired = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 0),
    )
    assert not fired

    # Frame 2: door closed (P + door_open=false) → DEPARTURE
    fired = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 30),
    )
    assert fired

    await db_session.commit()
    row = (await db_session.execute(
        select(AutomationState).where(
            AutomationState.user_id == user.id,
            AutomationState.key == DEPARTURE_EVENT_KEY,
        )
    )).scalar_one()
    assert "2026-05-11T18:00:30" in row.value


async def test_no_emit_when_driving(db_session):
    """Door close while shift_state == D (e.g. closing a door at a
    light) should NOT count as departure."""
    user = await _user(db_session, "dep-2@t.com")
    detector = DepartureDetector()

    await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="D"),
        observed_at=datetime(2026, 5, 11, 18, 0, 0),
    )
    fired = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="D"),
        observed_at=datetime(2026, 5, 11, 18, 0, 30),
    )
    assert not fired


async def test_no_emit_on_open(db_session):
    """Opening the door is not a departure — only the close edge."""
    user = await _user(db_session, "dep-3@t.com")
    detector = DepartureDetector()
    fired = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 0),
    )
    assert not fired


async def test_idempotent_repeated_close_frames(db_session):
    """Two consecutive False-False frames shouldn't double-fire — only
    the True→False edge counts."""
    user = await _user(db_session, "dep-4@t.com")
    detector = DepartureDetector()

    await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 0),
    )
    fired1 = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 30),
    )
    fired2 = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 1, 0),
    )
    assert fired1
    assert not fired2  # no edge, no fire


async def test_overwrites_event_on_subsequent_departure(db_session):
    """If user comes back, drives off, parks again — second departure
    should overwrite the first. Rules see the latest timestamp."""
    user = await _user(db_session, "dep-5@t.com")
    detector = DepartureDetector()

    # First departure
    await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 0),
    )
    await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="P"),
        observed_at=datetime(2026, 5, 11, 18, 0, 30),
    )
    await db_session.commit()

    # User returns + drives + parks again
    await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=True, shift="P"),
        observed_at=datetime(2026, 5, 11, 19, 0, 0),
    )
    fired = await detector.observe(
        db_session, user_id=user.id, vehicle_id=VIN,
        frame_entities=_frame(door_open=False, shift="P"),
        observed_at=datetime(2026, 5, 11, 19, 0, 30),
    )
    assert fired
    await db_session.commit()

    row = (await db_session.execute(
        select(AutomationState).where(
            AutomationState.user_id == user.id,
            AutomationState.key == DEPARTURE_EVENT_KEY,
        )
    )).scalar_one()
    assert "2026-05-11T19:00:30" in row.value
