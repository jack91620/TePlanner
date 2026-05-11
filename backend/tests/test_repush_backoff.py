"""A1 — escalating REPUSH_GUARD backoff.

The pure-function math is testable without a DB; integration with
the engine's _resolve_transition is exercised via existing
test_automation_rules.py.
"""

from datetime import timedelta

import pytest

from app.services.automation.engine import _escalating_repush_gap


@pytest.mark.parametrize(
    "cycle_count, expected_minutes",
    [
        (0, 15),    # cold start / fresh cycle
        (1, 15),    # exactly one prior push → still 15
        (2, 30),    # 2nd repush → double
        (3, 60),
        (4, 120),
        (5, 240),   # cap kicks in
        (6, 240),
        (10, 240),
        (100, 240), # cap holds even on absurd input
    ],
)
def test_backoff_table(cycle_count, expected_minutes):
    assert _escalating_repush_gap(cycle_count) == timedelta(minutes=expected_minutes)


def test_negative_cycle_count_treated_as_zero():
    """Defensive — db count() shouldn't ever return negative, but
    even if some upstream bug feeds us garbage, return the floor."""
    assert _escalating_repush_gap(-1) == timedelta(minutes=15)
