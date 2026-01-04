"""Energy consumption model for Tesla vehicles."""

import json
from pathlib import Path
from typing import Dict, Optional


class EnergyModel:
    """Calculate energy consumption for route planning."""

    # Default values if vehicle data not available
    DEFAULT_BATTERY_CAPACITY_KWH = 60.0
    DEFAULT_EFFICIENCY_WH_PER_KM = 150.0

    def __init__(self):
        """Initialize energy model with vehicle specs."""
        self.vehicle_specs = self._load_vehicle_specs()

    def _load_vehicle_specs(self) -> Dict:
        """Load vehicle specifications from JSON file."""
        spec_file = Path(__file__).parent.parent.parent / "data" / "vehicle_models.json"
        if spec_file.exists():
            with open(spec_file) as f:
                return json.load(f)
        return {}

    def get_vehicle_specs(self, car_type: str) -> Dict:
        """Get specs for a specific vehicle type."""
        return self.vehicle_specs.get(car_type, {})

    def calculate_consumption(
        self,
        distance_km: float,
        car_type: Optional[str] = None,
        speed_kmh: float = 100.0,
        temperature_c: float = 20.0,
        ac_on: bool = False,
        elevation_gain_m: float = 0.0,
    ) -> Dict:
        """Calculate energy consumption for a trip segment.

        Args:
            distance_km: Distance in kilometers.
            car_type: Tesla model type (model3, modely, etc.).
            speed_kmh: Average speed in km/h.
            temperature_c: Ambient temperature in Celsius.
            ac_on: Whether AC/heating is on.
            elevation_gain_m: Net elevation gain in meters.

        Returns:
            Dict with consumption details.
        """
        # Get base efficiency
        specs = self.get_vehicle_specs(car_type) if car_type else {}
        base_efficiency = specs.get(
            "efficiency_wh_per_km", self.DEFAULT_EFFICIENCY_WH_PER_KM
        )
        battery_capacity = specs.get(
            "battery_capacity_kwh", self.DEFAULT_BATTERY_CAPACITY_KWH
        )

        # Adjust for speed (higher speed = more consumption)
        speed_factor = 1.0
        if speed_kmh > 100:
            speed_factor = 1.0 + (speed_kmh - 100) * 0.005  # +0.5% per km/h over 100

        # Adjust for temperature (extreme temps increase consumption)
        temp_factor = 1.0
        if temperature_c < 10:
            temp_factor = 1.0 + (10 - temperature_c) * 0.02  # +2% per degree below 10
        elif temperature_c > 30:
            temp_factor = 1.0 + (temperature_c - 30) * 0.01  # +1% per degree above 30

        # AC/heating penalty
        hvac_factor = 1.1 if ac_on else 1.0

        # Elevation factor (rough estimate: 10Wh per meter of elevation gain)
        elevation_wh = elevation_gain_m * 10

        # Calculate total consumption
        adjusted_efficiency = (
            base_efficiency * speed_factor * temp_factor * hvac_factor
        )
        base_consumption_wh = distance_km * adjusted_efficiency
        total_consumption_wh = base_consumption_wh + elevation_wh

        # Convert to SOC percentage
        soc_consumed = (total_consumption_wh / 1000) / battery_capacity * 100

        return {
            "distance_km": distance_km,
            "consumption_wh": total_consumption_wh,
            "consumption_kwh": total_consumption_wh / 1000,
            "soc_consumed": round(soc_consumed, 1),
            "efficiency_wh_per_km": round(adjusted_efficiency, 1),
            "factors": {
                "speed": speed_factor,
                "temperature": temp_factor,
                "hvac": hvac_factor,
            },
        }

    def estimate_range(
        self,
        current_soc: int,
        car_type: Optional[str] = None,
        conditions: Optional[Dict] = None,
    ) -> float:
        """Estimate remaining range in km.

        Args:
            current_soc: Current battery SOC (0-100).
            car_type: Tesla model type.
            conditions: Optional driving conditions.

        Returns:
            Estimated range in km.
        """
        specs = self.get_vehicle_specs(car_type) if car_type else {}
        battery_capacity = specs.get(
            "battery_capacity_kwh", self.DEFAULT_BATTERY_CAPACITY_KWH
        )
        efficiency = specs.get(
            "efficiency_wh_per_km", self.DEFAULT_EFFICIENCY_WH_PER_KM
        )

        available_kwh = battery_capacity * (current_soc / 100)
        available_wh = available_kwh * 1000

        # Apply condition factors if provided
        if conditions:
            speed_factor = conditions.get("speed_factor", 1.0)
            temp_factor = conditions.get("temp_factor", 1.0)
            efficiency = efficiency * speed_factor * temp_factor

        range_km = available_wh / efficiency
        return round(range_km, 1)
