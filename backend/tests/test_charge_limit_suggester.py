"""Phase A.4 — pure-function parity test for charge-limit suggester.

Asserts the same behavior the iOS unit tests assert on
`ChargeLimitSuggester` (Sources/TePlannerKit/Services/
ChargeLimitSuggestion.swift). The two tables of cases below mirror the
iOS XCTest cases line-for-line so a Phase D port-out can replace the
Swift logic with calls to this module without changing observable
behavior.
"""

from datetime import datetime, timedelta

import pytest

from app.services.charge_analysis.suggester import (
    DEFAULT_TRIP_WINDOW_HOURS,
    SuggestionReason,
    UpcomingDeparture,
    suggest,
)


NOW = datetime(2026, 5, 9, 12, 0, 0)


def test_no_departure_recommends_daily_limit():
    s = suggest(
        current_limit=85,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=None,
        now=NOW,
    )
    assert s.recommended_percent == 80
    assert s.reason is SuggestionReason.DAILY
    assert s.current_percent == 85
    assert not s.already_matches


def test_already_matches_hides_card():
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=None,
        now=NOW,
    )
    assert s.already_matches is True


def test_past_departure_falls_back_to_daily():
    past = UpcomingDeparture(departure_at_utc=NOW - timedelta(hours=1))
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=past,
        now=NOW,
    )
    assert s.reason is SuggestionReason.DAILY


def test_departure_just_inside_trip_window_recommends_trip():
    upcoming = UpcomingDeparture(
        departure_at_utc=NOW + timedelta(hours=DEFAULT_TRIP_WINDOW_HOURS - 1)
    )
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
    )
    assert s.reason is SuggestionReason.UPCOMING_DEPARTURE
    assert s.recommended_percent == 100
    assert s.hours_away == DEFAULT_TRIP_WINDOW_HOURS - 1


def test_departure_exactly_at_window_edge_still_trip():
    """iOS uses `<=` comparison (`timeIntervalSince(now) <= secondsInWindow`),
    so a departure at exactly the window edge is INSIDE the window."""
    upcoming = UpcomingDeparture(
        departure_at_utc=NOW + timedelta(hours=DEFAULT_TRIP_WINDOW_HOURS)
    )
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
    )
    assert s.reason is SuggestionReason.UPCOMING_DEPARTURE


def test_departure_just_outside_window_falls_back_to_daily():
    upcoming = UpcomingDeparture(
        departure_at_utc=NOW + timedelta(hours=DEFAULT_TRIP_WINDOW_HOURS + 1)
    )
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
    )
    assert s.reason is SuggestionReason.DAILY


def test_hours_away_floors_to_int():
    """iOS: `Int(timeInterval / 3600)` → integer floor."""
    upcoming = UpcomingDeparture(
        departure_at_utc=NOW + timedelta(hours=2, minutes=59)
    )
    s = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
    )
    assert s.hours_away == 2


def test_current_limit_none_passes_through():
    s = suggest(
        current_limit=None,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=None,
        now=NOW,
    )
    assert s.current_percent is None
    assert s.already_matches is False  # iOS: nil current → never matches


def test_custom_trip_window_overrides_default():
    upcoming = UpcomingDeparture(departure_at_utc=NOW + timedelta(hours=20))
    daily = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
        trip_window_hours=DEFAULT_TRIP_WINDOW_HOURS,
    )
    assert daily.reason is SuggestionReason.DAILY  # 20h > 12h default
    extended = suggest(
        current_limit=80,
        daily_limit_soc=80,
        trip_limit_soc=100,
        upcoming_departure=upcoming,
        now=NOW,
        trip_window_hours=24,
    )
    assert extended.reason is SuggestionReason.UPCOMING_DEPARTURE
