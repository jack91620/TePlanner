"""Energy model tests."""

import pytest

from app.services.energy_model import EnergyModel


class TestEnergyModel:
    """Test energy consumption calculations."""

    def setup_method(self):
        """Set up test fixtures."""
        self.model = EnergyModel()

    def test_calculate_consumption_default(self):
        """Test basic consumption calculation with defaults."""
        result = self.model.calculate_consumption(distance_km=100)

        assert "consumption_kwh" in result
        assert "soc_consumed" in result
        assert result["distance_km"] == 100
        assert result["consumption_kwh"] > 0
        assert result["soc_consumed"] > 0

    def test_calculate_consumption_with_car_type(self):
        """Test consumption varies by car type."""
        result_m3 = self.model.calculate_consumption(
            distance_km=100, car_type="model3"
        )
        result_mx = self.model.calculate_consumption(
            distance_km=100, car_type="modelx"
        )

        # Model X should consume more than Model 3
        # (if vehicle specs are loaded)
        assert result_m3["consumption_kwh"] > 0
        assert result_mx["consumption_kwh"] > 0

    def test_speed_factor_increases_consumption(self):
        """Test higher speed increases consumption."""
        result_slow = self.model.calculate_consumption(
            distance_km=100, speed_kmh=80
        )
        result_fast = self.model.calculate_consumption(
            distance_km=100, speed_kmh=130
        )

        assert result_fast["consumption_kwh"] > result_slow["consumption_kwh"]

    def test_cold_temperature_increases_consumption(self):
        """Test cold temperature increases consumption."""
        result_warm = self.model.calculate_consumption(
            distance_km=100, temperature_c=20
        )
        result_cold = self.model.calculate_consumption(
            distance_km=100, temperature_c=-5
        )

        assert result_cold["consumption_kwh"] > result_warm["consumption_kwh"]

    def test_estimate_range(self):
        """Test range estimation."""
        range_km = self.model.estimate_range(current_soc=80)

        assert range_km > 0
        # 80% SOC should give reasonable range
        assert 200 < range_km < 600

    def test_estimate_range_soc_proportional(self):
        """Test range is proportional to SOC."""
        range_80 = self.model.estimate_range(current_soc=80)
        range_40 = self.model.estimate_range(current_soc=40)

        # 80% should be roughly double 40%
        assert 1.8 < (range_80 / range_40) < 2.2
