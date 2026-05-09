"""Phase A.4 — port of iOS ChargeLimitSuggester.swift.

Pure value computation: given the current limit, the user's daily /
trip preferences, and any upcoming scheduled departure, recommend a
charge-limit SOC.

Algorithm parity with iOS Sources/TePlannerKit/Services/
ChargeLimitSuggestion.swift is asserted by `test_charge_limit_suggester`
which reuses the same fixtures the iOS unit tests do.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional


DEFAULT_TRIP_WINDOW_HOURS = 12
DEFAULT_DAILY_CHARGE_LIMIT = 80
DEFAULT_TRIP_CHARGE_LIMIT = 100


class SuggestionReason(str, Enum):
    DAILY = "daily"
    UPCOMING_DEPARTURE = "upcoming_departure"


@dataclass(frozen=True)
class ChargeLimitSuggestion:
    recommended_percent: int
    current_percent: Optional[int]
    reason: SuggestionReason
    hours_away: Optional[int] = None

    @property
    def already_matches(self) -> bool:
        return (
            self.current_percent is not None
            and self.current_percent == self.recommended_percent
        )


@dataclass(frozen=True)
class UpcomingDeparture:
    departure_at_utc: datetime

    def is_in_future(self, now: datetime) -> bool:
        return self.departure_at_utc > now


def suggest(
    *,
    current_limit: Optional[int],
    daily_limit_soc: int = DEFAULT_DAILY_CHARGE_LIMIT,
    trip_limit_soc: int = DEFAULT_TRIP_CHARGE_LIMIT,
    upcoming_departure: Optional[UpcomingDeparture] = None,
    now: datetime,
    trip_window_hours: int = DEFAULT_TRIP_WINDOW_HOURS,
) -> ChargeLimitSuggestion:
    """Mirror iOS algorithm exactly:

    - if a future scheduled departure is within ``trip_window_hours``,
      recommend ``trip_limit_soc``;
    - otherwise recommend ``daily_limit_soc``.

    `current_limit` is passed through to the result so callers can ask
    `already_matches` and hide the suggestion card.
    """
    if (
        upcoming_departure is not None
        and upcoming_departure.is_in_future(now)
        and upcoming_departure.departure_at_utc - now
        <= timedelta(hours=trip_window_hours)
    ):
        seconds_away = (upcoming_departure.departure_at_utc - now).total_seconds()
        hours_away = max(0, int(seconds_away // 3600))
        return ChargeLimitSuggestion(
            recommended_percent=trip_limit_soc,
            current_percent=current_limit,
            reason=SuggestionReason.UPCOMING_DEPARTURE,
            hours_away=hours_away,
        )
    return ChargeLimitSuggestion(
        recommended_percent=daily_limit_soc,
        current_percent=current_limit,
        reason=SuggestionReason.DAILY,
    )
