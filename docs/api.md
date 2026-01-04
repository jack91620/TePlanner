# TePlanner API 文档

## 概述

TePlanner 提供 RESTful API，用于 Tesla 车辆集成的路线规划。

基础 URL: `https://api.teplanner.com/api/v1`

## 认证

所有需要认证的接口都需要在请求头中携带 JWT Token:

```text
Authorization: Bearer <token>
```

## 接口列表

### 认证相关

#### 微信登录

```text
POST /auth/wechat/login
```

请求体:

```json
{
  "code": "微信登录code"
}
```

响应:

```json
{
  "token": "jwt_token",
  "user": {
    "id": 1,
    "nickname": "用户昵称",
    "has_tesla_linked": false
  }
}
```

#### 获取 Tesla OAuth 授权链接

```text
GET /auth/tesla/authorize
```

响应:

```json
{
  "url": "https://auth.tesla.com/oauth2/v3/authorize?...",
  "state": "随机状态字符串"
}
```

#### Tesla OAuth 回调

```text
POST /auth/tesla/callback
```

请求体:

```json
{
  "code": "oauth授权码",
  "state": "授权时返回的state"
}
```

响应:

```json
{
  "vehicle": {
    "id": 1,
    "display_name": "我的特斯拉",
    "vin": "5YJ3E...",
    "battery_level": 80
  }
}
```

### 车辆相关

#### 获取当前车辆状态

```text
GET /vehicles/current/status
```

响应:

```json
{
  "id": 1,
  "display_name": "我的特斯拉",
  "state": "online",
  "battery_level": 80,
  "battery_range_km": 320,
  "charging_state": "Disconnected",
  "latitude": 31.2304,
  "longitude": 121.4737
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int | 车辆ID |
| display_name | string | 车辆名称 |
| state | string | 状态: online/asleep/offline |
| battery_level | int | 电量百分比 (0-100) |
| battery_range_km | float | 续航里程 (公里) |
| charging_state | string | 充电状态 |
| latitude | float | 纬度 |
| longitude | float | 经度 |

#### 获取用户车辆列表

```text
GET /vehicles
```

响应:

```json
{
  "vehicles": [
    {
      "id": 1,
      "tesla_id": "123456",
      "display_name": "我的 Model 3",
      "vin": "5YJ3E..."
    }
  ]
}
```

### 路线规划

#### 规划路线

```text
POST /routes/plan
```

请求体:

```json
{
  "origin": {
    "name": "上海",
    "latitude": 31.2304,
    "longitude": 121.4737
  },
  "destination": {
    "name": "杭州",
    "latitude": 30.2741,
    "longitude": 120.1551
  },
  "initial_soc": 80,
  "target_arrival_soc": 20,
  "vehicle_id": 1
}
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| origin | object | 是 | 出发地 |
| destination | object | 是 | 目的地 |
| initial_soc | int | 是 | 当前电量百分比 |
| target_arrival_soc | int | 否 | 到达时最低电量，默认20 |
| vehicle_id | int | 否 | 车辆ID |

响应:

```json
{
  "origin": { "name": "上海", "latitude": 31.2304, "longitude": 121.4737 },
  "destination": { "name": "杭州", "latitude": 30.2741, "longitude": 120.1551 },
  "total_distance_km": 175.5,
  "total_duration_minutes": 150,
  "driving_duration_minutes": 130,
  "charging_duration_minutes": 20,
  "charging_stops": [
    {
      "station_id": "sc_001",
      "station_name": "特斯拉超级充电站 嘉兴",
      "location": { "name": "嘉兴服务区", "latitude": 30.7522, "longitude": 120.7586 },
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

### 充电站

#### 搜索附近充电站

```text
GET /charging/stations/nearby
```

查询参数:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| latitude | float | 是 | 中心点纬度 |
| longitude | float | 是 | 中心点经度 |
| radius_km | int | 否 | 搜索半径(公里)，默认50 |

响应:

```json
{
  "stations": [
    {
      "id": "sc_001",
      "name": "特斯拉超级充电站 嘉兴",
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

## 错误响应

所有错误响应格式如下:

```json
{
  "detail": "错误信息",
  "code": "ERROR_CODE"
}
```

常见错误码:

| 状态码 | 说明 |
|--------|------|
| 401 | 未授权 - Token无效或已过期 |
| 403 | 禁止访问 - 权限不足 |
| 404 | 未找到 - 资源不存在 |
| 408 | 请求超时 - 车辆离线 |
| 422 | 验证错误 - 请求数据无效 |
| 500 | 服务器内部错误 |
