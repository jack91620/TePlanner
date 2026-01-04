# Tesla API Integration Guide

## Overview

TePlanner supports two Tesla API approaches:

1. **Tesla Owner API** (Non-official) - Used in MVP phase
2. **Tesla Fleet API** (Official) - Target for production

## MVP: Tesla Owner API

### Authentication Flow

The Owner API uses OAuth 2.0 with PKCE:

```
1. User clicks "Connect Tesla Account"
2. App redirects to Tesla auth URL
3. User logs in to Tesla account
4. Tesla redirects back with authorization code
5. Backend exchanges code for access token
6. Access token stored (encrypted) for API calls
```

### Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `GET /api/1/vehicles` | List user's vehicles |
| `GET /api/1/vehicles/{id}/vehicle_data` | Get battery, location, etc. |
| `POST /api/1/vehicles/{id}/wake_up` | Wake sleeping vehicle |

### Token Management

- Access tokens expire in 8 hours
- Refresh tokens used for renewal
- Tokens encrypted at rest using Fernet symmetric encryption

### Rate Limiting

- Respect Tesla's rate limits
- Implement exponential backoff on 429 responses
- Cache vehicle data where appropriate

## Future: Tesla Fleet API

### Requirements

1. Register with Tesla Developer Portal
2. Submit application for Fleet API access
3. Complete security review
4. Implement required security measures

### Differences from Owner API

| Aspect | Owner API | Fleet API |
|--------|-----------|-----------|
| Official Support | No | Yes |
| Rate Limits | Unofficial | Documented |
| Long-term Stability | Unknown | Guaranteed |
| Required Auth | OAuth 2.0 | Partner Token + OAuth 2.0 |

### Migration Plan

1. Apply for Fleet API access immediately
2. Build abstraction layer for easy switching
3. Test Fleet API in staging environment
4. Gradual rollout to production

## Security Considerations

### Token Storage

```python
# Tokens are encrypted before database storage
from cryptography.fernet import Fernet

class TokenEncryption:
    def encrypt(self, token: str) -> str:
        return self.fernet.encrypt(token.encode()).decode()

    def decrypt(self, encrypted: str) -> str:
        return self.fernet.decrypt(encrypted.encode()).decode()
```

### Best Practices

1. Never log access tokens
2. Use HTTPS for all API calls
3. Implement token rotation
4. Monitor for unusual API usage patterns
5. Provide user controls for data access

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Token expired | Refresh token |
| 408 Timeout | Vehicle asleep | Call wake_up first |
| 429 Too Many Requests | Rate limited | Exponential backoff |
| 503 Service Unavailable | Tesla API down | Retry with backoff |

### Vehicle Wake-up Flow

```python
async def ensure_vehicle_awake(client, vehicle_id):
    """Ensure vehicle is awake before data requests."""
    max_attempts = 5
    for attempt in range(max_attempts):
        data = await client.get_vehicle_data(vehicle_id)
        if data.get("state") == "online":
            return data

        await client.wake_up(vehicle_id)
        await asyncio.sleep(2 ** attempt)  # Exponential backoff

    raise TeslaVehicleOfflineError(vehicle_id)
```

## Data Models

### Vehicle Data Structure

```python
class VehicleData(BaseModel):
    id: str
    vehicle_id: int
    vin: str
    display_name: str
    state: str  # online, asleep, offline
    charge_state: Optional[ChargeState]
    drive_state: Optional[DriveState]
    vehicle_config: Optional[VehicleConfig]
```

### Charge State

```python
class ChargeState(BaseModel):
    battery_level: int  # 0-100
    battery_range: float  # miles
    charging_state: str  # Charging, Complete, Disconnected
    charge_rate: float  # miles/hour
    time_to_full_charge: float  # hours
```

## Testing

### Mock API for Development

Use mock responses during development to avoid hitting real Tesla API:

```python
# In tests/conftest.py
@pytest.fixture
def mock_tesla_client():
    with patch('app.integrations.tesla.client.TeslaClient') as mock:
        mock.return_value.get_vehicles.return_value = {
            "response": [{"id": "123", "display_name": "Test Tesla"}]
        }
        yield mock
```

## References

- [Tesla API Unofficial Documentation](https://tesla-api.timdorr.com/)
- [Tesla Developer Platform](https://developer.tesla.com/)
- [OAuth 2.0 PKCE RFC](https://datatracker.ietf.org/doc/html/rfc7636)
