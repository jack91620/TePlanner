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


_FIELD_HANDLERS = {
    "ClimateKeeperMode":            ("vehicle.climate.keeper_mode",         _decode_keeper_mode),
    "SentryMode":                   ("vehicle.sentry_mode_on",              _decode_sentry),
    "CabinOverheatProtectionMode":  ("vehicle.cabin_overheat_protection_on", _decode_cabin_overheat),
    "ChargeState":                  ("vehicle.charging.state",              _decode_charging),
    "BatteryLevel":                 ("vehicle.battery_level",               _decode_int),
    "Locked":                       ("vehicle.locked",                      _decode_bool),
    "Gear":                         ("vehicle.shift_state",                 _decode_gear),
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
        handler = _FIELD_HANDLERS.get(raw_key)
        if handler is None:
            continue
        entity, decoder = handler
        decoded = decoder(raw_value)
        if decoded is None:
            continue
        yield entity, decoded
