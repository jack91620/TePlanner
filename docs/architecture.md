# TePlanner 架构设计

## 系统概览

```text
+-------------------+     +-------------------+     +-------------------+
|   微信小程序       |     |   FastAPI         |     |   外部服务         |
|   (前端)          | --> |   后端            | --> |                   |
|                   |     |   (API服务器)      |     |                   |
+-------------------+     +-------------------+     +-------------------+
                                   |
                                   v
                          +-------------------+
                          |   PostgreSQL      |
                          |   (数据库)        |
                          +-------------------+
```

## 组件详情

### 前端 (微信小程序)

```text
miniprogram/
├── pages/
│   ├── index/          # 路线规划表单
│   ├── route-result/   # 规划结果展示
│   ├── station-detail/ # 充电站详情
│   ├── vehicle-binding/# Tesla OAuth 绑定流程
│   ├── profile/        # 用户设置
│   └── settings/       # 应用设置
├── utils/
│   ├── api.js          # HTTP 客户端
│   └── util.js         # 工具函数
└── config/
    └── index.js        # 环境配置
```

### 后端 (FastAPI)

```text
backend/
├── app/
│   ├── api/v1/         # API 接口
│   │   ├── auth.py     # 认证相关
│   │   ├── vehicles.py # 车辆管理
│   │   ├── routes.py   # 路线规划
│   │   └── charging.py # 充电站
│   ├── core/           # 核心工具
│   │   ├── security.py # JWT、加密
│   │   └── exceptions.py
│   ├── models/         # SQLAlchemy 模型
│   ├── schemas/        # Pydantic 模式
│   ├── services/       # 业务逻辑
│   │   ├── route_planner.py
│   │   └── energy_model.py
│   └── integrations/   # 外部 API
│       ├── tesla/      # Tesla API 客户端
│       └── tencent_map/ # 地图服务
└── tests/
```

## 数据流

### 路线规划请求

```text
1. 用户输入出发地、目的地
2. 小程序发送 POST /routes/plan 请求
3. 后端获取车辆电量（如已绑定）
4. 后端计算能耗
5. 后端调用腾讯地图获取路线
6. 后端确定所需充电站点
7. 返回路线和充电计划
```

### Tesla OAuth 流程

```text
1. 用户点击"绑定Tesla"
2. 小程序向后端请求 OAuth URL
3. 后端生成 state，返回 Tesla 授权链接
4. 用户在 web-view 中打开链接，登录Tesla
5. Tesla 重定向回调并携带授权码
6. 后端用授权码换取令牌
7. 后端获取并存储车辆信息
8. 小程序显示绑定成功及车辆数据
```

## 数据库设计

### 用户表 (users)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| wechat_openid | VARCHAR(64) | 微信标识 |
| tesla_access_token | TEXT | 加密存储 |
| tesla_refresh_token | TEXT | 加密存储 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### 车辆表 (vehicles)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| user_id | INT | 外键 |
| tesla_id | VARCHAR(64) | Tesla 车辆ID |
| vin | VARCHAR(17) | 车架号 |
| display_name | VARCHAR(64) | 用户命名 |
| car_type | VARCHAR(32) | model3, modely 等 |
| battery_capacity_kwh | FLOAT | 电池容量 |

### 行程表 (trips)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| user_id | INT | 外键 |
| origin_name | VARCHAR(128) | 出发地名称 |
| origin_lat/lng | FLOAT | 出发地坐标 |
| destination_name | VARCHAR(128) | 目的地名称 |
| destination_lat/lng | FLOAT | 目的地坐标 |
| initial_soc | INT | 出发电量 % |
| route_data | JSON | 完整路线信息 |
| charging_stops | JSON | 充电计划 |

## 外部服务集成

### Tesla API

- MVP阶段使用 Owner API（非官方）
- 生产环境使用 Fleet API（官方，待审批）
- 功能: 车辆数据、电量状态、唤醒

### 腾讯地图 API

- 地理编码（地址转坐标）
- 逆地理编码（坐标转地址）
- 驾车路线规划
- POI 搜索（充电站）

## 部署架构

### 开发环境

```text
本地机器:
- 后端: uvicorn (localhost:8000)
- 数据库: SQLite 或本地 PostgreSQL
- 小程序: 微信开发者工具
```

### 生产环境 (Serverless)

```text
腾讯云:
- API: SCF (云函数)
- 数据库: TencentDB for PostgreSQL
- 存储: COS (对象存储)
- CDN: 静态资源加速
```

## 安全措施

1. **认证**: JWT Token，短有效期
2. **Token 加密**: Fernet 对称加密存储 Tesla Token
3. **HTTPS**: 所有 API 调用加密传输
4. **输入验证**: Pydantic 模式验证
5. **速率限制**: 防止滥用
6. **CORS**: 限制来源域名

## 可扩展性考虑

1. **无状态后端**: 便于水平扩展
2. **数据库索引**: 在高频查询字段上建立索引
3. **缓存**: Redis 缓存车辆状态和路线计算
4. **异步 I/O**: FastAPI + httpx 非阻塞调用
5. **连接池**: SQLAlchemy 异步会话管理
