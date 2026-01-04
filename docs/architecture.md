# TePlanner Architecture

## System Overview

```
+-------------------+     +-------------------+     +-------------------+
|   WeChat Mini     |     |   FastAPI         |     |   External        |
|   Program         | --> |   Backend         | --> |   Services        |
|   (Frontend)      |     |   (API Server)    |     |                   |
+-------------------+     +-------------------+     +-------------------+
                                   |
                                   v
                          +-------------------+
                          |   PostgreSQL      |
                          |   (Database)      |
                          +-------------------+
```

## Component Details

### Frontend (WeChat Mini Program)

```
miniprogram/
├── pages/
│   ├── index/          # Route planning form
│   ├── route-result/   # Planning results
│   ├── station-detail/ # Charging station info
│   ├── vehicle-binding/# Tesla OAuth flow
│   ├── profile/        # User settings
│   └── settings/       # App preferences
├── utils/
│   ├── api.js          # HTTP client
│   └── util.js         # Helper functions
└── config/
    └── index.js        # Environment config
```

### Backend (FastAPI)

```
backend/
├── app/
│   ├── api/v1/         # API endpoints
│   │   ├── auth.py     # Authentication
│   │   ├── vehicles.py # Vehicle management
│   │   ├── routes.py   # Route planning
│   │   └── charging.py # Charging stations
│   ├── core/           # Core utilities
│   │   ├── security.py # JWT, encryption
│   │   └── exceptions.py
│   ├── models/         # SQLAlchemy models
│   ├── schemas/        # Pydantic schemas
│   ├── services/       # Business logic
│   │   ├── route_planner.py
│   │   └── energy_model.py
│   └── integrations/   # External APIs
│       ├── tesla/      # Tesla API client
│       └── tencent_map/ # Map services
└── tests/
```

## Data Flow

### Route Planning Request

```
1. User inputs origin, destination
2. Mini program sends POST /routes/plan
3. Backend fetches vehicle battery level (if linked)
4. Backend calculates energy consumption
5. Backend queries Tencent Map for route
6. Backend determines charging stops needed
7. Response returned with route + charging plan
```

### Tesla OAuth Flow

```
1. User taps "Connect Tesla"
2. Mini program requests OAuth URL from backend
3. Backend generates state, returns Tesla auth URL
4. User opens URL in web-view, logs into Tesla
5. Tesla redirects to callback with code
6. Backend exchanges code for tokens
7. Backend fetches and stores vehicle info
8. Mini program shows success, vehicle data
```

## Database Schema

### Users Table

| Column | Type | Description |
|--------|------|-------------|
| id | INT | Primary key |
| wechat_openid | VARCHAR(64) | WeChat identifier |
| tesla_access_token | TEXT | Encrypted |
| tesla_refresh_token | TEXT | Encrypted |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

### Vehicles Table

| Column | Type | Description |
|--------|------|-------------|
| id | INT | Primary key |
| user_id | INT | Foreign key |
| tesla_id | VARCHAR(64) | Tesla's ID |
| vin | VARCHAR(17) | Vehicle VIN |
| display_name | VARCHAR(64) | User's name for car |
| car_type | VARCHAR(32) | model3, modely, etc. |
| battery_capacity_kwh | FLOAT | Battery size |

### Trips Table

| Column | Type | Description |
|--------|------|-------------|
| id | INT | Primary key |
| user_id | INT | Foreign key |
| origin_name | VARCHAR(128) | |
| origin_lat/lng | FLOAT | |
| destination_name | VARCHAR(128) | |
| destination_lat/lng | FLOAT | |
| initial_soc | INT | Starting battery % |
| route_data | JSON | Full route info |
| charging_stops | JSON | Charging plan |

## External Service Integration

### Tesla API

- Owner API for MVP (unofficial)
- Fleet API for production (official, pending approval)
- Handles: Vehicle data, battery status, wake-up

### Tencent Map API

- Geocoding (address to coordinates)
- Reverse geocoding (coordinates to address)
- Driving route calculation
- POI search (charging stations)

## Deployment Architecture

### Development

```
Local machine:
- Backend: uvicorn (localhost:8000)
- Database: SQLite or local PostgreSQL
- Mini program: WeChat DevTools
```

### Production (Serverless)

```
Tencent Cloud:
- API: SCF (Serverless Cloud Function)
- Database: TencentDB for PostgreSQL
- Storage: COS (Cloud Object Storage)
- CDN: For static assets
```

## Security Measures

1. **Authentication**: JWT tokens with short expiry
2. **Token Encryption**: Fernet symmetric encryption for Tesla tokens
3. **HTTPS**: All API calls encrypted
4. **Input Validation**: Pydantic schema validation
5. **Rate Limiting**: Protect against abuse
6. **CORS**: Restrict origins

## Scalability Considerations

1. **Stateless Backend**: Easy horizontal scaling
2. **Database Indexing**: On frequently queried columns
3. **Caching**: Redis for vehicle status, route calculations
4. **Async I/O**: FastAPI + httpx for non-blocking calls
5. **Connection Pooling**: SQLAlchemy async sessions
