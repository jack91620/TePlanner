"""WGS-84 ↔ GCJ-02 conversion (China "Mars coordinates" offset).

**Coordinate system convention for TePlanner:**

- Backend stores everything WGS-84 (Tesla telemetry's native format).
  No conversions on storage / retrieval paths.
- AMap Web Service REST API expects GCJ-02 inputs for all
  coordinate-bearing endpoints (geocode, regeo, place/around,
  direction/driving, ...).
- The boundary conversion lives HERE — applied at every AmapWebClient
  method that accepts lat/lng arguments, immediately before talking
  to AMap. Callers pass WGS-84 in; this module converts to GCJ-02
  on the wire; AMap returns GCJ-02 lat/lngs; backend treats the
  response as-is for transient pass-through to iOS (which has its
  own GCJ-02 ↔ WGS-84 boundary at the AMap render layer).

This is the symmetric counterpart to iOS's
`apps/ios/Sources/TePlannerKit/Utilities/CoordConverter.swift`.
Both use the same standard public-domain formula so encode/decode
agree to < 1 m. Off-mainland inputs pass through unchanged.
"""

from __future__ import annotations

import math
from typing import Tuple


_A = 6_378_245.0            # semi-major axis
_EE = 0.006_693_421_622_965_943_23  # eccentricity²


def wgs84_to_gcj02(lat: float, lng: float) -> Tuple[float, float]:
    """Convert WGS-84 (raw GPS) → GCJ-02 (高德 / AMap). Returns (lat, lng)."""
    if not _in_china(lat, lng):
        return lat, lng
    d_lat = _transform_lat(lng - 105.0, lat - 35.0)
    d_lng = _transform_lng(lng - 105.0, lat - 35.0)
    rad_lat = lat / 180.0 * math.pi
    magic = math.sin(rad_lat)
    magic = 1 - _EE * magic * magic
    sqrt_magic = math.sqrt(magic)
    d_lat_final = (d_lat * 180.0) / ((_A * (1 - _EE)) / (magic * sqrt_magic) * math.pi)
    d_lng_final = (d_lng * 180.0) / (_A / sqrt_magic * math.cos(rad_lat) * math.pi)
    return lat + d_lat_final, lng + d_lng_final


def _in_china(lat: float, lng: float) -> bool:
    """Loose mainland bbox; same as iOS CoordConverter.isInChina."""
    return 72.004 <= lng <= 137.8347 and 0.8293 <= lat <= 55.8271


def _transform_lat(x: float, y: float) -> float:
    ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(abs(x))
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0
    ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320.0 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0
    return ret


def _transform_lng(x: float, y: float) -> float:
    ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(abs(x))
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0
    ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0
    ret += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0
    return ret
