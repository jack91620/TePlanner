"""Pure unit tests for the Tesla Fleet Telemetry → entity mapping.

Locks the field-name + enum-string contracts for the seven entities
preset rules read directly. Real V records intentionally include
extras (CreatedAt, IsResend, Vin, fields we don't yet handle) — the
mapper must skip those silently without throwing.
"""

from app.services.telemetry.mapping import map_v_payload


def _decode(payload: dict) -> dict:
    return dict(map_v_payload(payload))


def test_climate_keeper_camp_party_alias():
    # New firmware ships "Party"; older firmware shipped "Camp".
    # Both must decode to the same int (3) so existing rules fire.
    assert _decode({"ClimateKeeperMode": "ClimateKeeperModeStateParty"}) == {
        "vehicle.climate.keeper_mode": 3
    }
    assert _decode({"ClimateKeeperMode": "ClimateKeeperModeStateCamp"}) == {
        "vehicle.climate.keeper_mode": 3
    }


def test_climate_keeper_off_dog_keep():
    assert _decode({"ClimateKeeperMode": "ClimateKeeperModeStateOff"})[
        "vehicle.climate.keeper_mode"
    ] == 0
    assert _decode({"ClimateKeeperMode": "ClimateKeeperModeStateOn"})[
        "vehicle.climate.keeper_mode"
    ] == 1
    assert _decode({"ClimateKeeperMode": "ClimateKeeperModeStateDog"})[
        "vehicle.climate.keeper_mode"
    ] == 2


def test_sentry_off_vs_active_states():
    assert _decode({"SentryMode": "SentryModeStateOff"}) == {
        "vehicle.sentry_mode_on": False
    }
    # Idle/Armed/Aware/Panic/Quiet all count as "on" for the rule.
    for raw in [
        "SentryModeStateIdle",
        "SentryModeStateArmed",
        "SentryModeStateAware",
    ]:
        assert _decode({"SentryMode": raw})["vehicle.sentry_mode_on"] is True


def test_cabin_overheat_on_off_fan_only():
    assert _decode({"CabinOverheatProtectionMode": "CabinOverheatProtectionModeStateOff"})[
        "vehicle.cabin_overheat_protection_on"
    ] is False
    assert _decode({"CabinOverheatProtectionMode": "CabinOverheatProtectionModeStateOn"})[
        "vehicle.cabin_overheat_protection_on"
    ] is True
    # Fan-only counts as on — same protection signal for rules.
    assert _decode({"CabinOverheatProtectionMode": "CabinOverheatProtectionModeStateFanOnly"})[
        "vehicle.cabin_overheat_protection_on"
    ] is True


def test_charging_state_idle_normalized_to_disconnected():
    # ChargeComplete preset listens for "Complete"; map keeps the
    # other states verbatim so rules can match them too.
    assert _decode({"ChargeState": "Idle"})["vehicle.charging.state"] == "Disconnected"
    assert _decode({"ChargeState": "Complete"})["vehicle.charging.state"] == "Complete"
    assert _decode({"ChargeState": "Charging"})["vehicle.charging.state"] == "Charging"


def test_battery_level_decoded_as_int():
    assert _decode({"BatteryLevel": 52.988})["vehicle.battery_level"] == 52
    assert _decode({"BatteryLevel": 100})["vehicle.battery_level"] == 100


def test_locked_passthrough():
    assert _decode({"Locked": True}) == {"vehicle.locked": True}
    assert _decode({"Locked": False}) == {"vehicle.locked": False}


def test_gear_invalid_returns_no_entry():
    # Tesla emits "<invalid>" while car is asleep / between gears.
    # We must not surface a wrong shift_state.
    assert "vehicle.shift_state" not in _decode({"Gear": "<invalid>"})


def test_unknown_fields_skipped_silently():
    payload = {
        "Vin": "LRWY...",
        "CreatedAt": "2026-05-08T07:37:05Z",
        "IsResend": False,
        "FdWindow": "WindowStateClosed",  # not yet mapped
        "DoorState": {"DriverFront": False},  # not yet mapped
        "Locked": True,
    }
    out = _decode(payload)
    assert out == {"vehicle.locked": True}


def test_real_camp_mode_payload_from_production():
    # Verbatim from server log on 2026-05-08 — first real telemetry
    # we received. Pin it as a regression: if Tesla renames a field
    # this test fails before users notice.
    payload = {
        "BatteryLevel": 52.988748241912795,
        "CabinOverheatProtectionMode": "CabinOverheatProtectionModeStateFanOnly",
        "ChargeState": "Idle",
        "ClimateKeeperMode": "ClimateKeeperModeStateOff",
        "FdWindow": "WindowStateClosed",
        "FpWindow": "WindowStateClosed",
        "Gear": "<invalid>",
        "IsResend": False,
        "Locked": True,
        "RdWindow": "WindowStateClosed",
        "RpWindow": "WindowStateClosed",
        "SentryMode": "SentryModeStateOff",
        "Soc": 52.91842475386779,
        "Vin": "LRWYGCFS0NC517553",
        "CreatedAt": "2026-05-08T07:37:05Z",
    }
    out = _decode(payload)
    assert out == {
        "vehicle.climate.keeper_mode": 0,
        "vehicle.sentry_mode_on": False,
        "vehicle.cabin_overheat_protection_on": True,  # FanOnly → True
        "vehicle.charging.state": "Disconnected",
        "vehicle.battery_level": 52,
        "vehicle.locked": True,
    }


def test_camp_mode_transition_payload():
    # The second event from the same session — only ClimateKeeperMode
    # differs (delta-only payload). Mapper yields exactly one entry.
    out = _decode({
        "ClimateKeeperMode": "ClimateKeeperModeStateParty",
        "Vin": "LRWYGCFS0NC517553",
        "CreatedAt": "2026-05-08T07:37:34Z",
        "IsResend": False,
    })
    assert out == {"vehicle.climate.keeper_mode": 3}


def test_empty_payload_yields_nothing():
    assert _decode({}) == {}
    assert _decode({"Vin": "..."}) == {}
