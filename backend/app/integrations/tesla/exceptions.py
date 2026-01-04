"""Tesla API exceptions."""


class TeslaError(Exception):
    """Base Tesla API error."""

    pass


class TeslaAPIError(TeslaError):
    """Tesla API request error."""

    def __init__(self, message: str, status_code: int = None):
        super().__init__(message)
        self.status_code = status_code


class TeslaAuthError(TeslaError):
    """Tesla authentication error."""

    pass


class TeslaVehicleOfflineError(TeslaAPIError):
    """Vehicle is offline/asleep error."""

    def __init__(self, vehicle_id: str):
        super().__init__(
            f"Vehicle {vehicle_id} is offline. Try waking it up first.",
            status_code=408,
        )
        self.vehicle_id = vehicle_id
