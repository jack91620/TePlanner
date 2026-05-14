"""Active-trip cron monitor — automatic advance.

Phase 1 (active_trip_service) is the bare CRUD: app pushes stops one
at a time, but user has to tap "下一段" themselves. This module
(phase 2) wakes up inside the existing cron tick and auto-advances:

- Charging stop: arrival = ``charging_state == "Charging"``. Strong
  signal — only fires when the car physically plugged in. Distance
  + speed are secondary and only used when telemetry doesn't have
  charging_state for some reason.
- Final stop: arrival = within 200 m AND speed < 5 km/h AND parked.
  No charging_state to rely on; geometry has to do it.

When arrival fires:

- Send the next stop to the car (via active_trip_service)
- Push notification "已到达 A，下一站 B 已发送到车"
- Mutate trip.current_segment / replan_reason etc.

Decisions:

- Doesn't poll Tesla itself — reuses the snapshot the rest of cron
  builds from telemetry rows. No extra Fleet API calls per tick.
- Skips arrival detection when we don't have lat/lng (snapshot
  empty / car asleep) — would otherwise advance prematurely.
- Last-position is recorded on every tick (even non-arrival) so
  the iOS Hub card can show "现在距下一站 8 km, 25 min" in phase 2+.
"""

from __future__ import annotations

import json
import logging
import math
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ActiveTrip, TeslaToken, Vehicle
from app.integrations.tesla import TeslaClient
from app.services import active_trip_service as svc
from app.services.automation.base import VehicleStateSnapshot
from app.services.push import push_dispatcher
from sqlalchemy import select

logger = logging.getLogger(__name__)


# Arrival-detection tunables. Charging-stop detection is bullet-proof
# (relies on the car reporting charging_state); final-stop heuristic
# is fuzzier because we can't know whether the user "arrived" or is
# just stopped at a red light in front of the destination.
_FINAL_STOP_RADIUS_M = 200.0
_FINAL_STOP_MAX_SPEED_KMH = 5.0
_CHARGING_FALLBACK_RADIUS_M = 300.0  # used when charging_state unknown

# Phase 3a — SOC-aware projection. 0.18 kWh/km is a ballpark for
# Model Y in 中国 mixed driving; 75 kWh approximates the long-range
# pack we'd guess when vehicle_config doesn't provide a model lookup.
# Phase 3b refines these with rolling actual-usage telemetry.
_DEFAULT_CONSUMPTION_KWH_PER_KM = 0.18
_DEFAULT_BATTERY_CAPACITY_KWH = 75.0
# Haversine → road distance fudge factor. Avoids a routing call per tick.
_ROAD_FACTOR = 1.15
# Arrival SOC below this triggers the warning push.
_SOC_SAFETY_THRESHOLD_PCT = 5
# Don't push more than once per debounce window even if SOC stays low.
_SOC_WARN_DEBOUNCE = timedelta(minutes=5)

# Phase 4 — off-route detection. We compute the minimum perpendicular
# distance from the car's current position to the trip's polyline.
# When the lateral deviation exceeds the threshold for at least
# `_OFF_ROUTE_SUSTAIN_S` seconds (set off_route_since on first miss,
# fire when sustained), push a warning. Returning within threshold
# clears the timer so a brief detour doesn't lock the user out of
# future warnings.
_OFF_ROUTE_THRESHOLD_M = 2000.0     # 2 km lateral
_OFF_ROUTE_SUSTAIN_S = 90.0          # ≈3 cron ticks
_OFF_ROUTE_WARN_DEBOUNCE = timedelta(minutes=5)


def _haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance in metres. Good enough for arrival
    detection at 100 m precision."""
    R = 6371000.0  # earth radius m
    φ1 = math.radians(lat1)
    φ2 = math.radians(lat2)
    Δφ = math.radians(lat2 - lat1)
    Δλ = math.radians(lon2 - lon1)
    a = math.sin(Δφ / 2) ** 2 + math.cos(φ1) * math.cos(φ2) * math.sin(Δλ / 2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


def _has_arrived(
    snap: VehicleStateSnapshot, stop: dict, is_final: bool,
) -> bool:
    """Did the car arrive at `stop`? Returns False on insufficient
    telemetry so we never auto-advance from missing data."""
    if snap.latitude is None or snap.longitude is None:
        return False
    stop_lat = stop.get("latitude")
    stop_lng = stop.get("longitude")
    if stop_lat is None or stop_lng is None:
        return False
    distance = _haversine_m(
        snap.latitude, snap.longitude, float(stop_lat), float(stop_lng),
    )

    if is_final:
        # Final destination: rely entirely on geometry. The car may
        # not be charging here (often isn't); we want "in the
        # neighborhood + stopped" to consider it done.
        speed = snap.speed_kmh or 0.0
        return distance <= _FINAL_STOP_RADIUS_M and speed <= _FINAL_STOP_MAX_SPEED_KMH

    # Charging stop: strong signal first — the car says it's charging.
    # Geometry only kicks in when charging_state is missing (telemetry
    # gap, asleep, etc.) so we still catch arrivals that didn't write
    # a fresh charge_state frame.
    if snap.charging_state == "Charging":
        return distance <= _CHARGING_FALLBACK_RADIUS_M * 5  # generous radius
    if snap.charging_state in {"Stopped", "NoPower", "Disconnected"}:
        return False
    return distance <= _CHARGING_FALLBACK_RADIUS_M


async def monitor_active_trip(
    db: AsyncSession,
    user_id: int,
    snap: VehicleStateSnapshot,
) -> None:
    """One tick's worth of monitoring for a single user's trip. No-op
    when the user has no active trip. Auto-commits its mutations
    so the cron tick's catch-all rollback doesn't undo the advance.
    """
    trip = await svc.get_active_trip(db, user_id)
    if trip is None:
        return

    # Record last position regardless of arrival.
    if snap.latitude is not None and snap.longitude is not None:
        trip.last_position_lat = float(snap.latitude)
        trip.last_position_lng = float(snap.longitude)
        trip.last_position_at = datetime.utcnow()
    # Cache speed + SOC so /trips/active can derive distance / ETA /
    # arrival-SOC without re-reading telemetry on every iOS poll.
    if snap.speed_kmh is not None:
        trip.last_speed_kmh = float(snap.speed_kmh)
    if snap.battery_level is not None:
        trip.last_battery_level_pct = int(snap.battery_level)

    stops = svc.decode_stops(trip)
    cur_idx = trip.current_segment
    if cur_idx < 0 or cur_idx >= len(stops):
        # No stop has been sent yet, OR current_segment is past the
        # end (shouldn't happen — defensive). Nothing to advance from.
        return

    current = stops[cur_idx]
    is_final_current = (cur_idx == len(stops) - 1)

    if not _has_arrived(snap, current, is_final_current):
        # Phase 3a — while the car is still en route, evaluate whether
        # the projected SOC at the next stop is below safety. The
        # warning is debounced so we don't ping every 30s.
        await _check_soc_sufficiency(db, user_id, trip, snap, current)
        # Phase 4 — also check for polyline deviation. Independent
        # from SOC: a car can be on-route + low SOC, or off-route +
        # high SOC. Both can fire on the same tick.
        await _check_off_route(db, user_id, trip, snap)
        return

    logger.info(
        "active_trip_monitor: user=%s trip=%s arrival detected at stop=%s (kind=%s)",
        user_id, trip.id, cur_idx, current.get("kind"),
    )

    # On final-stop arrival: complete the trip + push.
    if is_final_current:
        trip.status = "completed"
        trip.updated_at = datetime.utcnow()
        await _push_completed(db, user_id, current)
        return

    # Mid-trip arrival: advance to next stop.
    nxt_idx = cur_idx + 1
    nxt_stop = stops[nxt_idx]
    token = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )).scalar_one_or_none()
    if token is None:
        logger.warning(
            "active_trip_monitor: user=%s has no TeslaToken — cannot advance",
            user_id,
        )
        return

    try:
        async with TeslaClient(access_token=token.access_token) as client:
            await svc.send_stop_to_vehicle(client, trip, stop_index=nxt_idx)
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "active_trip_monitor: send_stop failed for user=%s trip=%s: %s",
            user_id, trip.id, exc,
        )
        return

    await _push_advanced(db, user_id, arrived=current, next_stop=nxt_stop)


# ---- SOC sufficiency (phase 3a) -----------------------------------


def _project_arrival_soc(
    current_soc_pct: int,
    distance_km: float,
    capacity_kwh: float = _DEFAULT_BATTERY_CAPACITY_KWH,
    consumption_kwh_per_km: float = _DEFAULT_CONSUMPTION_KWH_PER_KM,
) -> float:
    """Linear SOC projection. Pessimistic by design — assumes flat
    consumption with no regen, no terrain factor. Phase 3b can layer
    a rolling-actual-consumption estimator on top."""
    energy_needed = distance_km * consumption_kwh_per_km
    drop_pct = (energy_needed / capacity_kwh) * 100.0
    return current_soc_pct - drop_pct


def _capacity_for_vehicle(vehicle: Optional[Vehicle]) -> float:
    """Pick a sensible pack capacity for the SOC math. Falls back to
    the default when the vehicles row hasn't been populated yet."""
    if vehicle is None or not vehicle.battery_capacity_kwh:
        return _DEFAULT_BATTERY_CAPACITY_KWH
    return float(vehicle.battery_capacity_kwh)


async def _check_soc_sufficiency(
    db: AsyncSession,
    user_id: int,
    trip: ActiveTrip,
    snap: VehicleStateSnapshot,
    current_stop: dict,
) -> None:
    """If the car's projected SOC at the current target stop is below
    the safety threshold, push a one-shot warning (debounced)."""
    soc = snap.battery_level
    if soc is None:
        # No telemetry → can't project. Tick again later when we have
        # a fresh SOC reading.
        return
    if snap.latitude is None or snap.longitude is None:
        return
    if current_stop.get("latitude") is None or current_stop.get("longitude") is None:
        return

    # Recently pushed? Hold off.
    if trip.last_soc_warning_at:
        if datetime.utcnow() - trip.last_soc_warning_at < _SOC_WARN_DEBOUNCE:
            return

    distance_m = _haversine_m(
        float(snap.latitude), float(snap.longitude),
        float(current_stop["latitude"]), float(current_stop["longitude"]),
    )
    distance_km = (distance_m / 1000.0) * _ROAD_FACTOR

    # Look up pack capacity from the user's vehicles row when we
    # cached it; otherwise default.
    vehicle_row: Optional[Vehicle] = (await db.execute(
        select(Vehicle)
        .where(Vehicle.user_id == user_id)
        .order_by(Vehicle.id.asc())
        .limit(1)
    )).scalar_one_or_none()
    capacity = _capacity_for_vehicle(vehicle_row)

    projected = _project_arrival_soc(soc, distance_km, capacity_kwh=capacity)
    if projected >= _SOC_SAFETY_THRESHOLD_PCT:
        return

    logger.warning(
        "active_trip_monitor: SOC unsafe user=%s trip=%s soc=%s "
        "distance_km=%.1f projected=%.1f%%",
        user_id, trip.id, soc, distance_km, projected,
    )

    # Phase 3b — try to fix it ourselves. Search nearby chargers
    # reachable on remaining SOC, replace the next stop with the
    # best candidate, push notification. If no candidate is reachable
    # we fall through to the phase 3a warning so the user can pull
    # over manually.
    replanned_to = await _try_soc_auto_replan(
        db, user_id, trip, snap, capacity_kwh=capacity,
    )
    trip.last_soc_warning_at = datetime.utcnow()
    if replanned_to is not None:
        await _push_soc_replanned(
            db, user_id,
            from_soc=soc, original_stop=current_stop, new_stop=replanned_to,
        )
        return

    await _push_soc_warning(
        db, user_id,
        next_stop=current_stop,
        current_soc=soc,
        distance_km=distance_km,
        projected_soc=projected,
    )


# ---- SOC auto-replan (phase 3b) -----------------------------------


def _reachable_radius_km(
    current_soc_pct: int,
    capacity_kwh: float,
    safety_reserve_pct: int = _SOC_SAFETY_THRESHOLD_PCT,
    consumption_kwh_per_km: float = _DEFAULT_CONSUMPTION_KWH_PER_KM,
) -> float:
    """How far can the car drive while still arriving with the safety
    reserve in the pack? Same simple model as the projection — no
    terrain / wind / regen accounting (phase 3c can layer it on)."""
    usable_pct = max(current_soc_pct - safety_reserve_pct, 0)
    usable_kwh = (usable_pct / 100.0) * capacity_kwh
    return usable_kwh / consumption_kwh_per_km


async def _try_soc_auto_replan(
    db: AsyncSession,
    user_id: int,
    trip: ActiveTrip,
    snap: VehicleStateSnapshot,
    capacity_kwh: float,
) -> Optional[dict]:
    """Find a closer reachable charger via AMap, replace the next stop
    with it, send to Tesla. Returns the new stop dict on success or
    None when no candidate works (caller falls back to a warning).
    """
    if snap.battery_level is None or snap.latitude is None or snap.longitude is None:
        return None
    stops = svc.decode_stops(trip)
    cur_idx = trip.current_segment
    if cur_idx < 0 or cur_idx >= len(stops):
        return None
    original_target = stops[cur_idx]
    if original_target.get("kind") != "charging":
        # Final-stop SOC mismatch — replan doesn't help; user has to
        # pull over manually.
        return None

    reachable_km = _reachable_radius_km(snap.battery_level, capacity_kwh)
    # AMap caps `radius` at 50 km. We use min(reachable, 50) but
    # filter the response by reachability in road-km terms below.
    search_radius_m = int(min(reachable_km, 50.0) * 1000)
    if search_radius_m < 1000:
        # Not enough room to plausibly find a different station; nothing
        # we can usefully suggest.
        logger.info(
            "active_trip_monitor: trip=%s reachable_km too small (%.1f)",
            trip.id, reachable_km,
        )
        return None

    from app.integrations.amap.coord import gcj02_to_wgs84
    from app.integrations.amap.web_client import AmapWebClient

    try:
        async with AmapWebClient() as amap:
            candidates = await amap.search_charging_stations(
                latitude=float(snap.latitude),
                longitude=float(snap.longitude),
                radius=search_radius_m,
            )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "active_trip_monitor: AMap charging search failed user=%s: %s",
            user_id, exc,
        )
        return None

    if not candidates:
        return None

    # Filter to reachable (haversine × road factor ≤ reachable_km) and
    # skip the original target (its station_id, when known) — if it's
    # close enough to count as a candidate, the projection wouldn't
    # have tripped in the first place; skipping is defensive.
    original_id = original_target.get("station_id")
    viable: list[tuple[float, dict]] = []
    for poi in candidates:
        loc = poi.get("location") or {}
        gcj_lat = loc.get("lat")
        gcj_lng = loc.get("lng")
        if gcj_lat is None or gcj_lng is None:
            continue
        wgs_lat, wgs_lng = gcj02_to_wgs84(float(gcj_lat), float(gcj_lng))
        d_m = _haversine_m(
            float(snap.latitude), float(snap.longitude), wgs_lat, wgs_lng,
        )
        d_km = (d_m / 1000.0) * _ROAD_FACTOR
        if d_km > reachable_km:
            continue
        if original_id and poi.get("id") == original_id:
            continue
        viable.append((d_km, {
            "latitude": wgs_lat,
            "longitude": wgs_lng,
            "name": poi.get("title") or "充电站",
            "address": poi.get("address") or None,
            "kind": "charging",
            "station_id": poi.get("id") or None,
            "soc_target": original_target.get("soc_target"),
        }))

    if not viable:
        logger.info(
            "active_trip_monitor: trip=%s no reachable charger found "
            "among %d candidates",
            trip.id, len(candidates),
        )
        return None

    # Pick closest reachable. Phase 3c can prefer "closest to original
    # route" to minimise detour distance.
    viable.sort(key=lambda t: t[0])
    new_stop = viable[0][1]

    # Replace stops[cur_idx..-1] with [new_stop, final_destination].
    # Originally-planned stops AFTER cur_idx are dropped — they're
    # likely on the other side of the unreachable original target,
    # so we'd have to re-plan past the new charger to know whether
    # they're still on the route. Phase 3c can re-run the full
    # RoutePlanner from the new charger; phase 3b is simpler.
    final_stop = stops[-1]
    if final_stop.get("kind") != "final":
        # Defensive: schema invariant from /trips/start guarantees
        # final is last, but log if we ever see a violation.
        logger.warning(
            "active_trip_monitor: trip=%s last stop kind != 'final' "
            "— refusing to replan", trip.id,
        )
        return None
    new_stops = stops[:cur_idx] + [new_stop, final_stop]
    trip.stops_json = svc.encode_stops(new_stops)
    trip.replan_count += 1
    reason = "电耗高于预期"
    trip.last_replan_reason = reason

    # Send the new charger to Tesla. cur_idx now refers to the new
    # charger position in the rewritten stops list.
    token = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )).scalar_one_or_none()
    if token is None:
        logger.warning(
            "active_trip_monitor: trip=%s user=%s no TeslaToken — "
            "stops rewritten but new stop not sent to car",
            trip.id, user_id,
        )
        return new_stop

    try:
        async with TeslaClient(access_token=token.access_token) as client:
            await svc.send_stop_to_vehicle(
                client, trip, stop_index=cur_idx, reason=reason,
            )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "active_trip_monitor: trip=%s send_stop after replan failed: %s",
            trip.id, exc,
        )
        # We've already mutated the row; the iOS Hub card will show
        # the new plan even though the car still has the old nav.
        # Next manual /trips/{id}/advance call will retry.

    return new_stop


async def _push_soc_replanned(
    db: AsyncSession, user_id: int,
    from_soc: int, original_stop: dict, new_stop: dict,
) -> None:
    orig_name = original_stop.get("name") or "原桩"
    new_name = new_stop.get("name") or "新桩"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title="已自动切换充电站",
            body=(
                f"电耗高于预期（当前 {from_soc}%），按原计划无法到达"
                f"「{orig_name}」。已切换到更近的「{new_name}」并发到车机。"
            ),
            category="active_trip_soc_replanned",
            thread_id="active_trip",
            custom_data={"event": "soc_replanned"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: SOC replan push failed user=%s", user_id)


# ---- off-route detection (phase 4) --------------------------------


def _point_to_segment_m(
    plat: float, plng: float,
    a_lat: float, a_lng: float,
    b_lat: float, b_lng: float,
) -> float:
    """Perpendicular distance in metres from point P to the segment AB.
    For small distances (< 50 km between A and B) we approximate by
    projecting onto a local flat coordinate system — earth curvature
    error is negligible at this scale and the math is 10× cheaper than
    great-circle. Falls back to endpoint distance when A == B.
    """
    if a_lat == b_lat and a_lng == b_lng:
        return _haversine_m(plat, plng, a_lat, a_lng)

    # Local equirectangular projection — good enough for the scale we
    # care about (polyline points are usually 100m–1km apart).
    lat0 = math.radians((a_lat + b_lat) / 2)
    mx = math.cos(lat0) * 111_320  # m per degree longitude at this lat
    my = 111_320                     # m per degree latitude

    ax, ay = a_lng * mx, a_lat * my
    bx, by = b_lng * mx, b_lat * my
    px, py = plng * mx, plat * my

    dx, dy = bx - ax, by - ay
    seg_len2 = dx * dx + dy * dy
    if seg_len2 <= 0:
        return _haversine_m(plat, plng, a_lat, a_lng)
    t = ((px - ax) * dx + (py - ay) * dy) / seg_len2
    t = max(0.0, min(1.0, t))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px - qx, py - qy)


def _min_distance_to_polyline_m(
    plat: float, plng: float, polyline: list[list[float]],
) -> float:
    """Closest perpendicular distance from (plat, plng) to any segment
    of the polyline. Returns +inf if polyline is empty / has <2 points
    (caller should skip off-route detection in that case)."""
    if not polyline or len(polyline) < 2:
        return float("inf")
    best = float("inf")
    for i in range(len(polyline) - 1):
        a = polyline[i]
        b = polyline[i + 1]
        if len(a) < 2 or len(b) < 2:
            continue
        d = _point_to_segment_m(plat, plng, a[0], a[1], b[0], b[1])
        if d < best:
            best = d
    return best


async def _check_off_route(
    db: AsyncSession,
    user_id: int,
    trip: ActiveTrip,
    snap: VehicleStateSnapshot,
) -> None:
    """Maintain off_route_since state machine + fire a debounced push
    once the car has been off-route for `_OFF_ROUTE_SUSTAIN_S` seconds."""
    if not trip.polyline_json:
        return  # Old trips without polyline saved; skip detection.
    if snap.latitude is None or snap.longitude is None:
        return

    try:
        polyline: list[list[float]] = json.loads(trip.polyline_json)
    except (json.JSONDecodeError, TypeError):
        return

    distance_m = _min_distance_to_polyline_m(
        float(snap.latitude), float(snap.longitude), polyline,
    )
    now = datetime.utcnow()

    if distance_m <= _OFF_ROUTE_THRESHOLD_M:
        # Back on track — reset the sustain timer so a future deviation
        # has to accumulate again before warning.
        if trip.off_route_since is not None:
            logger.info(
                "active_trip_monitor: trip=%s back on route (dist=%.0f m)",
                trip.id, distance_m,
            )
        trip.off_route_since = None
        return

    if trip.off_route_since is None:
        trip.off_route_since = now
        return

    # Off-route for how long?
    sustained = (now - trip.off_route_since).total_seconds()
    if sustained < _OFF_ROUTE_SUSTAIN_S:
        return

    # Debounce: don't re-push within the warning window.
    if trip.last_off_route_warning_at:
        if now - trip.last_off_route_warning_at < _OFF_ROUTE_WARN_DEBOUNCE:
            return

    logger.warning(
        "active_trip_monitor: trip=%s off-route user=%s dist=%.0f m sustained=%.0f s",
        trip.id, user_id, distance_m, sustained,
    )
    trip.last_off_route_warning_at = now

    # Phase 4b — auto re-send the current next stop to Tesla so the
    # car's nav recomputes a route from the new position. Tesla
    # handles the actual route geometry; we just nudge it. If the
    # detour put the planned stop out of SOC range, phase 3b will
    # take over on the next tick.
    resent = await _try_off_route_resend(db, user_id, trip)
    await _push_off_route(
        db, user_id, distance_m=distance_m, resent=resent,
    )


async def _try_off_route_resend(
    db: AsyncSession, user_id: int, trip: ActiveTrip,
) -> bool:
    """Re-push the current next stop to Tesla so its nav recomputes
    from current position. Returns True on success, False otherwise
    (missing token, send failure, no current segment)."""
    stops = svc.decode_stops(trip)
    cur_idx = trip.current_segment
    if cur_idx < 0 or cur_idx >= len(stops):
        return False
    token = (await db.execute(
        select(TeslaToken).where(TeslaToken.user_id == user_id)
    )).scalar_one_or_none()
    if token is None:
        logger.info(
            "active_trip_monitor: trip=%s off-route resend skipped — "
            "no TeslaToken", trip.id,
        )
        return False
    try:
        async with TeslaClient(access_token=token.access_token) as client:
            await svc.send_stop_to_vehicle(
                client, trip, stop_index=cur_idx, reason="偏离原线路",
            )
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "active_trip_monitor: trip=%s off-route resend failed: %s",
            trip.id, exc,
        )
        return False


async def _push_off_route(
    db: AsyncSession, user_id: int, distance_m: float, resent: bool,
) -> None:
    km = distance_m / 1000.0
    if resent:
        body = (
            f"距规划路线 {km:.1f} km。已重新把下一站发到车机，"
            f"Tesla 将从当前位置重新规划路线。"
        )
    else:
        body = (
            f"距规划路线 {km:.1f} km。如需切换路线，在 App 的"
            f"进行中行程卡片点「重新规划」。"
        )
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title="已偏离原线路",
            body=body,
            category="active_trip_off_route",
            thread_id="active_trip",
            custom_data={"event": "off_route", "auto_resent": resent},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: off-route push failed user=%s", user_id)


async def _push_soc_warning(
    db: AsyncSession, user_id: int,
    next_stop: dict, current_soc: int, distance_km: float,
    projected_soc: float,
) -> None:
    name = next_stop.get("name") or next_stop.get("address") or "下一站"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title="电量预警",
            body=(
                f"距「{name}」约 {distance_km:.0f} km，"
                f"当前 {current_soc}% 估计到达 {projected_soc:.0f}%。"
                f"建议立即就近补电。"
            ),
            category="active_trip_soc_warning",
            thread_id="active_trip",
            custom_data={"event": "soc_warning"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: SOC push failed user=%s", user_id)


# ---- push helpers -------------------------------------------------


async def _push_advanced(
    db: AsyncSession, user_id: int,
    arrived: dict, next_stop: dict,
) -> None:
    arrived_name = arrived.get("name") or arrived.get("address") or "充电站"
    next_name = next_stop.get("name") or next_stop.get("address") or "下一站"
    next_kind = "终点" if next_stop.get("kind") == "final" else "下一充电站"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title=f"到达 {arrived_name}",
            body=f"已自动把{next_kind}「{next_name}」发到车机",
            category="active_trip_advanced",
            thread_id="active_trip",
            custom_data={"event": "advance"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: push (advanced) failed user=%s", user_id)


async def _push_completed(db: AsyncSession, user_id: int, last_stop: dict) -> None:
    name = last_stop.get("name") or last_stop.get("address") or "目的地"
    try:
        await push_dispatcher.send(
            db=db, user_id=user_id,
            title="行程完成",
            body=f"已到达「{name}」",
            category="active_trip_completed",
            thread_id="active_trip",
            custom_data={"event": "completed"},
        )
    except Exception:  # noqa: BLE001
        logger.exception("active_trip_monitor: push (completed) failed user=%s", user_id)
