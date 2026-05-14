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


def test_charge_limit_soc_decoded_as_int():
    """ChargeLimitSoc drives the SetChargeLimit idempotence guard —
    if this mapping breaks, every set_charge_limit re-fires."""
    assert _decode({"ChargeLimitSoc": 80})["vehicle.charge_limit_pct"] == 80
    assert _decode({"ChargeLimitSoc": 80.4})["vehicle.charge_limit_pct"] == 80
    assert _decode({"ChargeLimitSoc": 100})["vehicle.charge_limit_pct"] == 100


def test_locked_passthrough():
    assert _decode({"Locked": True}) == {"vehicle.locked": True}
    assert _decode({"Locked": False}) == {"vehicle.locked": False}


def test_gear_invalid_returns_no_entry():
    # Tesla emits "<invalid>" while car is asleep / between gears.
    # We must not surface a wrong shift_state.
    assert "vehicle.shift_state" not in _decode({"Gear": "<invalid>"})


def test_unknown_fields_skipped_silently():
    """Truly unmapped fields (Vin / CreatedAt / IsResend / something
    unknown) must not appear in the output. FdWindow + DoorState ARE
    mapped now (Phase 7) so they belong here."""
    payload = {
        "Vin": "LRWY...",
        "CreatedAt": "2026-05-08T07:37:05Z",
        "IsResend": False,
        "TotallyMadeUpField": "x",
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
        # Phase 7 — 4 windows decode (the production payload didn't
        # include DoorState in this particular V record).
        "vehicle.window.fd": False,
        "vehicle.window.fp": False,
        "vehicle.window.rd": False,
        "vehicle.window.rp": False,
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


# ---------- protojson list form (transmit_decoded_records=true) ----------

def test_normalize_protojson_datum_list():
    """When fleet-telemetry's transmit_decoded_records is enabled, the
    ZMQ payload uses protojson encoding: data is a list of Datum
    objects with key/value-oneof shape, not a flat dict.
    """
    proto_data = [
        {"key": "ClimateKeeperMode",
         "value": {"stringValue": "ClimateKeeperModeStateParty"}},
        {"key": "BatteryLevel",
         "value": {"floatValue": 52.5}},
        {"key": "Locked",
         "value": {"booleanValue": True}},
        {"key": "SentryMode",
         "value": {"stringValue": "SentryModeStateOff"}},
    ]
    out = _decode(proto_data)
    assert out == {
        "vehicle.climate.keeper_mode": 3,
        "vehicle.battery_level": 52,
        "vehicle.locked": True,
        "vehicle.sentry_mode_on": False,
    }


def test_protojson_skips_unknown_oneof_variant():
    # If a datum has a value oneof variant we don't model AND a key
    # we don't model, normalize_datum_list passes the raw nested dict
    # through and mapping silently skips it.
    proto_data = [
        {"key": "TotallyUnknownField",
         "value": {"unknownVariantValue": {"foo": "bar"}}},
        {"key": "BatteryLevel",
         "value": {"floatValue": 52}},
    ]
    out = _decode(proto_data)
    assert out == {"vehicle.battery_level": 52}


def test_protojson_camp_mode_transition_payload():
    proto_data = [
        {"key": "ClimateKeeperMode",
         "value": {"stringValue": "ClimateKeeperModeStateOff"}},
    ]
    assert _decode(proto_data) == {"vehicle.climate.keeper_mode": 0}


# ---------- Phase 7 entity expansion ----------

def test_door_state_composite_yields_individuals_plus_aggregates():
    # All four doors closed, frunk and trunk closed.
    out = _decode({"DoorState": {
        "DriverFront": False, "DriverRear": False,
        "PassengerFront": False, "PassengerRear": False,
        "TrunkFront": False, "TrunkRear": False,
    }})
    assert out["vehicle.door_open"] is False
    assert out["vehicle.frunk_open"] is False
    assert out["vehicle.trunk_open"] is False
    assert out["vehicle.door.df"] is False
    assert out["vehicle.door.dr"] is False
    assert out["vehicle.door.pf"] is False
    assert out["vehicle.door.pr"] is False


def test_door_state_one_open_flips_aggregate_only():
    out = _decode({"DoorState": {
        "DriverFront": True, "DriverRear": False,
        "PassengerFront": False, "PassengerRear": False,
        "TrunkFront": False, "TrunkRear": False,
    }})
    assert out["vehicle.door_open"] is True
    assert out["vehicle.door.df"] is True
    assert out["vehicle.door.dr"] is False
    assert out["vehicle.frunk_open"] is False
    assert out["vehicle.trunk_open"] is False


def test_door_state_with_only_trunk_open():
    out = _decode({"DoorState": {
        "DriverFront": False, "DriverRear": False,
        "PassengerFront": False, "PassengerRear": False,
        "TrunkFront": False, "TrunkRear": True,
    }})
    assert out["vehicle.door_open"] is False  # trunk doesn't count as door
    assert out["vehicle.trunk_open"] is True
    assert out["vehicle.frunk_open"] is False


def test_window_string_enum_decoded_as_bool():
    # Each window arrives as its own delta field. Every value other
    # than "WindowStateClosed" counts as open (vented, partially-open,
    # fully-open all want the same automation alert).
    assert _decode({"FdWindow": "WindowStateClosed"}) == {
        "vehicle.window.fd": False,
    }
    assert _decode({"FpWindow": "WindowStateOpen"}) == {
        "vehicle.window.fp": True,
    }
    assert _decode({"RdWindow": "WindowStateVented"}) == {
        "vehicle.window.rd": True,
    }


def test_location_composite():
    out = _decode({"Location": {"latitude": 39.9, "longitude": 116.4}})
    assert out == {
        "vehicle.location.latitude": 39.9,
        "vehicle.location.longitude": 116.4,
    }


def test_location_uppercase_keys_also_supported():
    # Defensive: protojson may serialize as "Latitude" / "Longitude"
    # depending on the proto's json_name annotation.
    out = _decode({"Location": {"Latitude": 39.9, "Longitude": 116.4}})
    assert out == {
        "vehicle.location.latitude": 39.9,
        "vehicle.location.longitude": 116.4,
    }


def test_temps_speed_charger_power_decoded_as_floats():
    assert _decode({"InsideTemp": 22.5})["vehicle.inside_temp_c"] == 22.5
    assert _decode({"OutsideTemp": -3.0})["vehicle.outside_temp_c"] == -3.0
    assert _decode({"VehicleSpeed": 80.5})["vehicle.speed_kmh"] == 80.5
    assert _decode({"ChargerPower": 11.0})["vehicle.charger_power_kw"] == 11.0


def test_software_version_decoded_as_string():
    assert _decode({"Version": "2024.44.25.5"})["vehicle.software_version"] == "2024.44.25.5"


def test_protojson_doors_composite_via_oneof():
    # The protojson form: {"key":"DoorState","value":{"doorValue":{...}}}.
    # normalize_datum_list unwraps unknown oneof variants by returning
    # the inner dict; mapping then sees a dict and the composite
    # handler does the rest.
    proto_data = [
        {"key": "DoorState",
         "value": {"doorValue": {
             "DriverFront": True, "DriverRear": False,
             "PassengerFront": False, "PassengerRear": False,
             "TrunkFront": False, "TrunkRear": False,
         }}}
    ]
    out = _decode(proto_data)
    assert out["vehicle.door_open"] is True
    assert out["vehicle.door.df"] is True


def test_protojson_location_composite():
    proto_data = [
        {"key": "Location",
         "value": {"locationValue": {"latitude": 39.9, "longitude": 116.4}}},
    ]
    out = _decode(proto_data)
    assert out == {
        "vehicle.location.latitude": 39.9,
        "vehicle.location.longitude": 116.4,
    }
