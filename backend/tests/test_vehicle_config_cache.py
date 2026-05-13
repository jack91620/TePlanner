"""Phase 11.x — vehicle_config DB cache merge helper.

Pins the merge semantics for `_build_vehicle_config` so the cached
roof_color / car_type / motorized_charge_port aren't accidentally
wiped by a partial Tesla response (asleep car / hiccup).
"""

from datetime import datetime
from types import SimpleNamespace

from app.api.v1.vehicles import _build_vehicle_config


def _cached(**kwargs):
    """Build a Vehicle-row-shaped object with just the fields the
    helper reads."""
    return SimpleNamespace(
        car_type=kwargs.get("car_type"),
        roof_color=kwargs.get("roof_color"),
        motorized_charge_port=kwargs.get("motorized_charge_port"),
        config_fetched_at=kwargs.get("config_fetched_at"),
    )


def test_returns_none_when_both_empty():
    """Fresh user, never fetched, Tesla returned nothing — the
    response's `vehicle_config` field should be null so clients
    fall back to showing every capability."""
    assert _build_vehicle_config({}, None) is None


def test_returns_fresh_when_no_cache():
    """First-time fetch: surface what Tesla returned."""
    raw = {"car_type": "modely", "roof_color": "Glass",
           "motorized_charge_port": True}
    config = _build_vehicle_config(raw, None)
    assert config is not None
    assert config.car_type == "modely"
    assert config.roof_color == "Glass"
    assert config.motorized_charge_port is True


def test_returns_cached_when_tesla_empty():
    """Asleep car or partial response: serve from DB cache rather
    than dropping fields. Matches the user-visible promise that
    vehicle_config is 'fetched once, served forever'."""
    cached = _cached(
        car_type="model3", roof_color="Glass", motorized_charge_port=True,
    )
    config = _build_vehicle_config({}, cached)
    assert config.car_type == "model3"
    assert config.roof_color == "Glass"
    assert config.motorized_charge_port is True


def test_fresh_beats_cache_when_present():
    """If Tesla returns a value for a field we already have, prefer
    the fresh one — covers an edge case where the user upgrades
    their roof / aftermarket-mods the charge port."""
    cached = _cached(car_type="modely", roof_color="Glass")
    raw = {"car_type": "modelx", "roof_color": "Sunroof"}
    config = _build_vehicle_config(raw, cached)
    assert config.car_type == "modelx"
    assert config.roof_color == "Sunroof"


def test_merges_partial_fresh_with_cached():
    """Tesla sometimes returns only some sub-fields (rare but seen
    on asleep / partial vehicle_data). Merge field-by-field — the
    one Tesla actually returned wins, the rest fall back."""
    cached = _cached(
        car_type="modely", roof_color="Glass", motorized_charge_port=True,
    )
    raw = {"roof_color": "Sunroof"}  # only roof present
    config = _build_vehicle_config(raw, cached)
    assert config.car_type == "modely"          # from cache
    assert config.roof_color == "Sunroof"        # from fresh
    assert config.motorized_charge_port is True  # from cache


def test_motorized_port_false_is_kept():
    """`motorized_charge_port: False` is a legitimate value (older
    trim with manual port) and must not be confused with absent."""
    raw = {"motorized_charge_port": False}
    config = _build_vehicle_config(raw, None)
    assert config is not None
    assert config.motorized_charge_port is False
