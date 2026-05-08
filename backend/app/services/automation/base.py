"""Server-side port of iOS Sources/TePlannerKit/Automations/Automation.swift.

The shape mirrors the iOS protocol:
  - VehicleStateSnapshot   ↔ VehicleState
  - AutomationContext      ↔ AutomationContext
  - AlertSeverity / Alert  ↔ VehicleAlert
  - Automation             ↔ Automation (protocol)
  - StateMemory            ↔ AutomationStateMemory

The deliberate parity makes it easy to keep wording / thresholds in
sync between client and server. The polling loop instantiates a memory
backed by the AutomationState SQLite table so reminder timers survive
backend restarts.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Protocol


class AlertKind(str, Enum):
    CAMP_MODE = "campMode"
    SENTRY_MODE = "sentryMode"
    CABIN_OVERHEAT = "cabinOverheat"
    CHARGE_COMPLETE = "chargeComplete"
    # Slice A
    LEFT_UNLOCKED = "leftUnlocked"
    CLOSURE_LEFT_OPEN = "closureLeftOpen"
    # Slice B
    LOW_BATTERY = "lowBattery"
    # Slice C
    WEEKDAY_PREHEAT = "weekdayPreheat"


class AlertSeverity(str, Enum):
    INFO = "info"
    CRITICAL = "critical"


@dataclass
class Alert:
    kind: AlertKind
    title: str
    detail: str
    severity: AlertSeverity
    primary_action_label: Optional[str] = None


@dataclass
class VehicleStateSnapshot:
    """Subset of /vehicles/{id}/state we feed into the engine. Mirrors
    iOS VehicleState fields the rules read; new rules add new fields
    here as needed.
    """

    battery_level: Optional[int] = None
    charging_state: Optional[str] = None     # "Charging" / "Complete" / etc.
    sentry_mode_on: Optional[bool] = None
    cabin_overheat_protection_on: Optional[bool] = None
    climate_keeper_mode: Optional[int] = None  # 0=off, 1=keep, 2=dog, 3=camp

    # Slice A — security + closure state. Tesla returns each as int
    # (0=closed, non-zero=open) or bool (locked). We normalize to bool
    # at snapshot construction so rules don't have to care.
    locked: Optional[bool] = None
    shift_state: Optional[str] = None  # "P" / "R" / "N" / "D" / None when parked-asleep
    door_open: Optional[bool] = None       # any of df/dr/pf/pr open
    window_open: Optional[bool] = None     # any window non-zero
    frunk_open: Optional[bool] = None
    trunk_open: Optional[bool] = None

    @property
    def is_camp_mode_on(self) -> bool:
        return self.climate_keeper_mode == 3

    @property
    def is_parked(self) -> bool:
        # Tesla emits None when the car is asleep; treat as parked
        # since the practical behavior (forgot to lock / window open)
        # only matters when stationary.
        if self.shift_state is None:
            return True
        return self.shift_state == "P"

    @property
    def parked_unlocked(self) -> bool:
        return self.is_parked and (self.locked is False)

    @property
    def parked_with_door_open(self) -> bool:
        return self.is_parked and (self.door_open is True)

    @property
    def parked_with_window_open(self) -> bool:
        return self.is_parked and (self.window_open is True)

    @property
    def parked_with_frunk_open(self) -> bool:
        return self.is_parked and (self.frunk_open is True)

    @property
    def parked_with_trunk_open(self) -> bool:
        return self.is_parked and (self.trunk_open is True)


class StateMemory(Protocol):
    """Per-rule scratchpad. Implementations may persist (SQLite) or
    just hold dict-in-memory for tests. Values are datetimes (UTC)
    because that's what every existing rule needs; if a future rule
    wants e.g. ints we'll widen this then.
    """

    def get(self, key: str) -> Optional[datetime]: ...
    def set(self, key: str, value: Optional[datetime]) -> None: ...


@dataclass
class InMemoryStateMemory:
    """Test/default implementation that just keeps a dict per instance."""

    _store: dict = field(default_factory=dict)

    def get(self, key: str) -> Optional[datetime]:
        return self._store.get(key)

    def set(self, key: str, value: Optional[datetime]) -> None:
        if value is None:
            self._store.pop(key, None)
        else:
            self._store[key] = value


@dataclass
class AutomationSettings:
    """Per-user thresholds. Defaults match iOS SettingsStore so the
    server experience matches the phone's local-only experience until
    a user explicitly overrides anything.
    """

    camp_mode_reminder_minutes: int = 120        # 2h
    sentry_reminder_minutes: int = 1440          # 24h
    cabin_overheat_reminder_minutes: int = 60    # 1h
    charge_complete_reminder_enabled: bool = True


@dataclass
class AutomationContext:
    vehicle_state: Optional[VehicleStateSnapshot]
    vehicle_id: Optional[str]
    now: datetime
    settings: AutomationSettings
    memory: StateMemory


def utc_now() -> datetime:
    return datetime.now(timezone.utc)
