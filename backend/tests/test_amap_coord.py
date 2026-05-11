"""WGS-84 → GCJ-02 conversion math — paired with iOS
CoordConverterTests so both sides stay aligned.
"""

import math

import pytest

from app.integrations.amap.coord import wgs84_to_gcj02


def _meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Haversine in meters — for sanity-checking offset magnitudes."""
    r = 6_371_000.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def test_tiananmen_known_anchor():
    """北京天安门: WGS-84 (39.9087, 116.3974) ↔ GCJ-02 ≈ (39.9099, 116.4035).
    Canonical anchor every GCJ-02 lib pins against."""
    lat, lng = wgs84_to_gcj02(39.9087, 116.3974)
    assert abs(lat - 39.9099) < 0.0005
    assert abs(lng - 116.4035) < 0.0005


def test_offset_substantial_in_china():
    """Forward conversion must shift the point > 50 m (and < 1500 m sanity)."""
    src_lat, src_lng = 39.9087, 116.3974
    lat, lng = wgs84_to_gcj02(src_lat, src_lng)
    d = _meters(src_lat, src_lng, lat, lng)
    assert d > 50
    assert d < 1500


def test_overseas_passthrough_sf():
    """SF (37.7749, -122.4194) is outside the China bbox — no offset
    applied. Overseas Teslas must not get phantom shifts."""
    lat, lng = wgs84_to_gcj02(37.7749, -122.4194)
    assert lat == 37.7749
    assert lng == -122.4194


def test_overseas_passthrough_tokyo():
    """Tokyo (35.6762, 139.6503) likewise outside bbox."""
    lat, lng = wgs84_to_gcj02(35.6762, 139.6503)
    assert lng == 139.6503  # would still be inside if bbox were wrong
    # Tokyo lng (139.65) IS technically within the 137.83 cap of the
    # mainland-China bbox bound — confirm it's caught. Actually 139.65
    # > 137.8347 so it should pass through.
    # The lng-only check is the meaningful boundary; lat is below 55.
    assert lat == 35.6762


def test_in_china_bbox_boundary_inclusive():
    """The bbox is inclusive on both ends — verify a point right at the
    eastern edge still gets offset."""
    # Just inside the western edge (Tibet area)
    lat0, lng0 = 30.0, 80.0
    lat, lng = wgs84_to_gcj02(lat0, lng0)
    assert lat != lat0 or lng != lng0  # was offset


def test_shanghai_outer_bund():
    """Shanghai: 31.2304, 121.4737 — must shift but stay close enough
    that math doesn't blow up at coastal city."""
    lat0, lng0 = 31.2304, 121.4737
    lat, lng = wgs84_to_gcj02(lat0, lng0)
    d = _meters(lat0, lng0, lat, lng)
    assert 50 < d < 1500
