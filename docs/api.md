# TePlanner API Documentation

## Overview

TePlanner provides a RESTful API for route planning with Tesla vehicle integration.

Base URL: `https://api.teplanner.com/api/v1`

## Authentication

All authenticated endpoints require a JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

## Endpoints

### Auth

#### WeChat Login

```
POST /auth/wechat/login
```

Request:
```json
{
  "code": "wechat_login_code"
}
```

Response:
```json
{
  "token": "jwt_token",
  "user": {
    "id": 1,
    "nickname": "User",
    "has_tesla_linked": false
  }
}
```

#### Tesla OAuth Authorization URL

```
GET /auth/tesla/authorize
```

Response:
```json
{
  "url": "https://auth.tesla.com/oauth2/v3/authorize?...",
  "state": "random_state_string"
}
```

#### Tesla OAuth Callback

```
POST /auth/tesla/callback
```

Request:
```json
{
  "code": "oauth_code",
  "state": "state_from_authorize"
}
```

Response:
```json
{
  "vehicle": {
    "id": 1,
    "display_name": "My Tesla",
    "vin": "5YJ3E...",
    "battery_level": 80
  }
}
```

### Vehicles

#### Get Current Vehicle Status

```
GET /vehicles/current/status
```

Response:
```json
{
  "id": 1,
  "display_name": "My Tesla",
  "state": "online",
  "battery_level": 80,
  "battery_range_km": 320,
  "charging_state": "Disconnected",
  "latitude": 31.2304,
  "longitude": 121.4737
}
```

#### List User Vehicles

```
GET /vehicles
```

Response:
```json
{
  "vehicles": [
    {
      "id": 1,
      "tesla_id": "123456",
      "display_name": "My Model 3",
      "vin": "5YJ3E..."
    }
  ]
}
```

### Routes

#### Plan Route

```
POST /routes/plan
```

Request:
```json
{
  "origin": {
    "name": "Shanghai",
    "latitude": 31.2304,
    "longitude": 121.4737
  },
  "destination": {
    "name": "Hangzhou",
    "latitude": 30.2741,
    "longitude": 120.1551
  },
  "initial_soc": 80,
  "target_arrival_soc": 20,
  "vehicle_id": 1
}
```

Response:
```json
{
  "origin": { "name": "Shanghai", "latitude": 31.2304, "longitude": 121.4737 },
  "destination": { "name": "Hangzhou", "latitude": 30.2741, "longitude": 120.1551 },
  "total_distance_km": 175.5,
  "total_duration_minutes": 150,
  "driving_duration_minutes": 130,
  "charging_duration_minutes": 20,
  "charging_stops": [
    {
      "station_id": "sc_001",
      "station_name": "Tesla Supercharger Jiaxing",
      "location": { "name": "Jiaxing Service Area", "latitude": 30.7522, "longitude": 120.7586 },
      "arrival_soc": 25,
      "departure_soc": 60,
      "charging_duration_minutes": 20,
      "charger_type": "supercharger",
      "distance_from_start_km": 85.0
    }
  ],
  "arrival_soc": 35,
  "warnings": []
}
```

### Charging Stations

#### Search Nearby Stations

```
GET /charging/stations/nearby
```

Query Parameters:
- `latitude` (required): Center latitude
- `longitude` (required): Center longitude
- `radius_km` (optional): Search radius, default 50

Response:
```json
{
  "stations": [
    {
      "id": "sc_001",
      "name": "Tesla Supercharger Jiaxing",
      "type": "supercharger",
      "latitude": 30.7522,
      "longitude": 120.7586,
      "available_stalls": 8,
      "total_stalls": 12,
      "power_kw": 250
    }
  ]
}
```

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error message here",
  "code": "ERROR_CODE"
}
```

Common error codes:
- `401`: Unauthorized - Invalid or expired token
- `403`: Forbidden - Insufficient permissions
- `404`: Not Found - Resource not found
- `408`: Request Timeout - Vehicle offline
- `422`: Validation Error - Invalid request data
- `500`: Internal Server Error
