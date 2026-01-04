# Tesla API 集成指南

## 概述

TePlanner 支持两种 Tesla API 方案:

1. **Tesla Owner API** (非官方) - MVP阶段使用
2. **Tesla Fleet API** (官方) - 生产环境目标

## MVP阶段: Tesla Owner API

### 认证流程

Owner API 使用 OAuth 2.0 + PKCE 流程:

```text
1. 用户点击"绑定Tesla账号"
2. 应用跳转到Tesla授权页面
3. 用户登录Tesla账号并授权
4. Tesla重定向回调并携带授权码
5. 后端用授权码换取访问令牌
6. 访问令牌加密存储，用于后续API调用
```

### 使用的接口

| 接口 | 用途 |
|------|------|
| `GET /api/1/vehicles` | 获取用户车辆列表 |
| `GET /api/1/vehicles/{id}/vehicle_data` | 获取电量、位置等数据 |
| `POST /api/1/vehicles/{id}/wake_up` | 唤醒休眠车辆 |

### Token 管理

- 访问令牌有效期约8小时
- 使用刷新令牌续期
- 令牌使用 Fernet 对称加密存储

### 速率限制

- 遵守 Tesla 的速率限制
- 遇到 429 响应时使用指数退避重试
- 适当缓存车辆数据

## 未来: Tesla Fleet API

### 申请要求

1. 在 Tesla Developer Portal 注册
2. 提交 Fleet API 访问申请
3. 通过安全审核
4. 实现必要的安全措施

### 与 Owner API 的区别

| 方面 | Owner API | Fleet API |
|------|-----------|-----------|
| 官方支持 | 否 | 是 |
| 速率限制 | 非官方 | 有文档说明 |
| 长期稳定性 | 不确定 | 有保障 |
| 认证方式 | OAuth 2.0 | Partner Token + OAuth 2.0 |

### 迁移计划

1. 立即申请 Fleet API 访问权限
2. 构建抽象层便于切换
3. 在测试环境验证 Fleet API
4. 逐步迁移到生产环境

## 安全措施

### Token 存储

```python
# Token 在存入数据库前会被加密
from cryptography.fernet import Fernet

class TokenEncryption:
    def encrypt(self, token: str) -> str:
        return self.fernet.encrypt(token.encode()).decode()

    def decrypt(self, encrypted: str) -> str:
        return self.fernet.decrypt(encrypted.encode()).decode()
```

### 最佳实践

1. 永远不要记录访问令牌
2. 所有 API 调用使用 HTTPS
3. 实现令牌轮换机制
4. 监控异常的 API 使用模式
5. 提供用户数据访问控制

## 错误处理

### 常见错误

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 401 Unauthorized | Token 已过期 | 刷新 Token |
| 408 Timeout | 车辆休眠中 | 先调用 wake_up |
| 429 Too Many Requests | 超过速率限制 | 指数退避重试 |
| 503 Service Unavailable | Tesla API 故障 | 重试并退避 |

### 车辆唤醒流程

```python
async def ensure_vehicle_awake(client, vehicle_id):
    """确保车辆处于唤醒状态后再请求数据"""
    max_attempts = 5
    for attempt in range(max_attempts):
        data = await client.get_vehicle_data(vehicle_id)
        if data.get("state") == "online":
            return data

        await client.wake_up(vehicle_id)
        await asyncio.sleep(2 ** attempt)  # 指数退避

    raise TeslaVehicleOfflineError(vehicle_id)
```

## 数据模型

### 车辆数据结构

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

### 充电状态

```python
class ChargeState(BaseModel):
    battery_level: int  # 0-100
    battery_range: float  # 英里
    charging_state: str  # Charging, Complete, Disconnected
    charge_rate: float  # 英里/小时
    time_to_full_charge: float  # 小时
```

## 测试

### 开发环境 Mock API

开发时使用 Mock 响应，避免调用真实 Tesla API:

```python
# 在 tests/conftest.py 中
@pytest.fixture
def mock_tesla_client():
    with patch('app.integrations.tesla.client.TeslaClient') as mock:
        mock.return_value.get_vehicles.return_value = {
            "response": [{"id": "123", "display_name": "测试车辆"}]
        }
        yield mock
```

## 参考资料

- [Tesla API 非官方文档](https://tesla-api.timdorr.com/)
- [Tesla Developer Platform](https://developer.tesla.com/)
- [OAuth 2.0 PKCE RFC](https://datatracker.ietf.org/doc/html/rfc7636)
