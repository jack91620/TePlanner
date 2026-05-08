"""Tesla Fleet Telemetry payload → our entity name + value.

fleet-telemetry emits each `data` field as a delta. Field names match
``protos/vehicle_data.proto``; values are pre-decoded enum strings
(``ClimateKeeperModeStateParty``) plus primitive types. We translate
these into the dotted entity paths interpreters use
(``vehicle.climate.keeper_mode``) and into the same scalar shape
``VehicleStateSnapshot`` carries (int / bool / str), so the interpreter
treats telemetry-sourced values identically to polling-sourced ones.

V1 covers the seven entities our preset rules read directly. Doors,
windows, frunk, trunk are deferred — they need cross-event aggregation
("any window open"), which is more naturally derived from a polling
fetch than from per-window deltas.
"""

from __future__ import annotations

from typing import Any, Iterator, Optional, Tuple


_KEEPER_MODE = {
    "ClimateKeeperModeStateOff": 0,
    "ClimateKeeperModeStateOn": 1,
    "ClimateKeeperModeStateDog": 2,
    "ClimateKeeperModeStateParty": 3,   # 露营/聚会模式 — 新固件名
    "ClimateKeeperModeStateCamp": 3,    # 老固件 fallback
}


_SENTRY_MODE_ON = {
    "SentryModeStateOff": False,
    "SentryModeStateIdle": True,
    "SentryModeStateArmed": True,
    "SentryModeStateAware": True,
    "SentryModeStatePanic": True,
    "SentryModeStateQuiet": True,
    "SentryModeStateOn": True,
}


_CABIN_OVERHEAT_ON = {
    "CabinOverheatProtectionModeStateOff": False,
    "CabinOverheatProtectionModeStateOn": True,
    "CabinOverheatProtectionModeStateFanOnly": True,
}


_CHARGE_STATE = {
    "Idle": "Disconnected",
    "Disconnected": "Disconnected",
    "Charging": "Charging",
    "Starting": "Starting",
    "Stopped": "Stopped",
    "Complete": "Complete",
    "NoPower": "NoPower",
}


_GEAR = {
    "DriveStateP": "P",
    "DriveStateR": "R",
    "DriveStateN": "N",
    "DriveStateD": "D",
    "<invalid>": None,
}


def _decode_keeper_mode(raw: Any) -> Optional[int]:
    if isinstance(raw, int):
        return raw
    if isinstance(raw, str):
        return _KEEPER_MODE.get(raw)
    return None


def _decode_sentry(raw: Any) -> Optional[bool]:
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, str):
        return _SENTRY_MODE_ON.get(raw)
    return None


def _decode_cabin_overheat(raw: Any) -> Optional[bool]:
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, str):
        return _CABIN_OVERHEAT_ON.get(raw)
    return None


def _decode_charging(raw: Any) -> Optional[str]:
    if isinstance(raw, str):
        return _CHARGE_STATE.get(raw, raw)
    return None


def _decode_gear(raw: Any) -> Optional[str]:
    if isinstance(raw, str):
        return _GEAR.get(raw, raw if len(raw) == 1 else None)
    return None


def _decode_int(raw: Any) -> Optional[int]:
    if isinstance(raw, bool):
        return None
    try:
        return int(raw) if raw is not None else None
    except (TypeError, ValueError):
        return None


def _decode_bool(raw: Any) -> Optional[bool]:
    if isinstance(raw, bool):
        return raw
    return None


def _decode_float(raw: Any) -> Optional[float]:
    if isinstance(raw, bool):
        return None
    try:
        return float(raw) if raw is not None else None
    except (TypeError, ValueError):
        return None


def _decode_string(raw: Any) -> Optional[str]:
    return raw if isinstance(raw, str) and raw else None


def _decode_window(raw: Any) -> Optional[bool]:
    """Tesla emits window state as enum string. ``WindowStateClosed``
    is the only "closed" value; everything else is some open state
    (``WindowStateOpen``, ``WindowStatePartiallyOpen``, vented, etc.)
    so rules treat them all as "open"."""
    if isinstance(raw, str):
        return raw != "WindowStateClosed"
    if isinstance(raw, bool):
        return raw
    if isinstance(raw, (int, float)):
        return raw != 0
    return None


_FIELD_HANDLERS = {
    # Existing scalars (Phase 4).
    "ClimateKeeperMode":            ("vehicle.climate.keeper_mode",         _decode_keeper_mode),
    "SentryMode":                   ("vehicle.sentry_mode_on",              _decode_sentry),
    "CabinOverheatProtectionMode":  ("vehicle.cabin_overheat_protection_on", _decode_cabin_overheat),
    "ChargeState":                  ("vehicle.charging.state",              _decode_charging),
    "BatteryLevel":                 ("vehicle.battery_level",               _decode_int),
    "Locked":                       ("vehicle.locked",                      _decode_bool),
    "Gear":                         ("vehicle.shift_state",                 _decode_gear),
    # Phase 7 — physical-state scalars useful for automation rules.
    # InsideTemp / OutsideTemp drive "preheat-finished" detection
    # ("preheat until cabin >= 20°C"); ChargerPower distinguishes
    # actually-charging from connected-but-paused.
    "InsideTemp":                   ("vehicle.inside_temp_c",               _decode_float),
    "OutsideTemp":                  ("vehicle.outside_temp_c",              _decode_float),
    "VehicleSpeed":                 ("vehicle.speed_kmh",                   _decode_float),
    "ChargerPower":                 ("vehicle.charger_power_kw",            _decode_float),
    "Version":                      ("vehicle.software_version",            _decode_string),
    # Phase 7 — individual windows. Aggregate ``vehicle.window_open``
    # is derived in TelemetryStateWriter (cross-event since each
    # window is a separate delta field).
    "FdWindow":                     ("vehicle.window.fd",                   _decode_window),
    "FpWindow":                     ("vehicle.window.fp",                   _decode_window),
    "RdWindow":                     ("vehicle.window.rd",                   _decode_window),
    "RpWindow":                     ("vehicle.window.rp",                   _decode_window),
}


def _decode_doors(raw: Any) -> list:
    """DoorState is a composite with all four doors + frunk + trunk in
    one struct. Tesla emits the full struct on every change, so we
    can derive aggregates inside this single handler — no cross-event
    bookkeeping needed (unlike windows). Yield 7 entries:

      * vehicle.door_open       — any of df/dr/pf/pr open
      * vehicle.frunk_open      — front trunk
      * vehicle.trunk_open      — rear trunk
      * vehicle.door.df/dr/pf/pr — individual doors for finer-grained
                                   rules (e.g. "driver door open while
                                   parked + sentry on" alarm)
    """
    if not isinstance(raw, dict):
        return []
    df = bool(raw.get("DriverFront"))
    dr = bool(raw.get("DriverRear"))
    pf = bool(raw.get("PassengerFront"))
    pr = bool(raw.get("PassengerRear"))
    tf = bool(raw.get("TrunkFront"))
    tr = bool(raw.get("TrunkRear"))
    return [
        ("vehicle.door_open",   df or dr or pf or pr),
        ("vehicle.frunk_open",  tf),
        ("vehicle.trunk_open",  tr),
        ("vehicle.door.df",     df),
        ("vehicle.door.dr",     dr),
        ("vehicle.door.pf",     pf),
        ("vehicle.door.pr",     pr),
    ]


def _decode_location(raw: Any) -> list:
    """Tesla's Location is a {latitude, longitude} composite. Split
    into two scalar entities so the geofence trigger (Phase 8) can
    read each independently — and so a rule's ``state`` condition can
    match on either coordinate alone if needed.
    """
    if not isinstance(raw, dict):
        return []
    lat = raw.get("latitude") if "latitude" in raw else raw.get("Latitude")
    lng = raw.get("longitude") if "longitude" in raw else raw.get("Longitude")
    out = []
    if isinstance(lat, (int, float)):
        out.append(("vehicle.location.latitude", float(lat)))
    if isinstance(lng, (int, float)):
        out.append(("vehicle.location.longitude", float(lng)))
    return out


_COMPOSITE_HANDLERS = {
    "DoorState": _decode_doors,
    "Location": _decode_location,
}


def normalize_datum_list(data: list) -> dict:
    """Convert protojson-shaped ``data: repeated Datum`` to the flat
    dict shape map_v_payload expects.

    With ``transmit_decoded_records: true`` in fleet-telemetry config,
    the ZMQ payload uses protojson encoding of the proto's
    ``vehicle_data.Payload``. ``data`` is a JSON array of
    ``{"key": "<FieldName>", "value": {<oneof>}}`` items. The logger
    output, by contrast, is the legacy flat ``{key: value}`` dict.
    Normalize to the dict shape so the same mapping works for both.

    Each ``value`` is a oneof: ``stringValue`` / ``intValue`` /
    ``floatValue`` / ``doubleValue`` / ``booleanValue`` / etc.
    Pick whichever variant is present.
    """
    flat: dict = {}
    if not isinstance(data, list):
        return flat
    for datum in data:
        if not isinstance(datum, dict):
            continue
        key = datum.get("key")
        if not isinstance(key, str):
            continue
        value = datum.get("value")
        if not isinstance(value, dict):
            continue
        # protojson serializes oneof as a single key. Extract whichever
        # one was set; if multiple, prefer scalar over composite.
        unwrapped: Any = None
        for variant in (
            "stringValue", "boolValue", "booleanValue",
            "intValue", "longValue", "floatValue", "doubleValue",
        ):
            if variant in value:
                unwrapped = value[variant]
                break
        if unwrapped is None:
            # Composite type (location, etc.) — pass through.
            unwrapped = next(iter(value.values()), None)
        if unwrapped is not None:
            flat[key] = unwrapped
    return flat


def map_v_payload(data) -> Iterator[Tuple[str, Any]]:
    """Yield (entity, decoded_value) pairs from a fleet-telemetry V
    record's ``data`` field. Accepts either:

      * ``dict`` (legacy / logger output): ``{"BatteryLevel": 52, ...}``
      * ``list`` (protojson output with ``transmit_decoded_records``):
        ``[{"key": "BatteryLevel", "value": {"floatValue": 52}}, ...]``

    Skips unrecognized fields and entries that decode to None (Tesla
    sometimes ships ``"<invalid>"`` for transient values).
    """
    if isinstance(data, list):
        data = normalize_datum_list(data)
    if not isinstance(data, dict):
        return
    for raw_key, raw_value in data.items():
        composite = _COMPOSITE_HANDLERS.get(raw_key)
        if composite is not None:
            for entity, value in composite(raw_value):
                if value is not None:
                    yield entity, value
            continue
        handler = _FIELD_HANDLERS.get(raw_key)
        if handler is None:
            continue
        entity, decoder = handler
        decoded = decoder(raw_value)
        if decoded is None:
            continue
        yield entity, decoded
