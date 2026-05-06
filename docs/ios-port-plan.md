# iOS 迁移方案 —— 对齐 Android 功能

本文档是把 Android 端功能迁移到 iOS 的总规划。Android 是参考实现，iOS
追平。

## 工程量评估

Android 端体量较大 —— 32 个 Kotlin 文件、6 个屏幕、Tesla OAuth 流程、
高德地图集成、车辆状态轮询（含离线唤醒重试）、贪心算法选取充电站。
iOS 端目前是 stub：仅有一个 `ContentView`、两个硬编码城市，路线规划走
`/routes/plan` 接口。完整对齐预计需要 **2–4 周专注开发**。

## 架构决定

### ① 地图方案：高德 iOS SDK ✅（已定）

Android 使用高德地图（中国市场必需 —— Apple MapKit 在中国区无法拿到
中文 POI、路径规划、充电桩数据）。iOS 端**直接接入高德 iOS SDK**，
与 Android 端使用相同的数据源和地图能力。

涉及的高德模块：

- **AMapFoundation**：基础库，必装
- **AMap3DMap**：3D 地图显示（Android 用的是 `3dmap:9.8.2`）
- **AMapSearch**：POI 搜索、路径规划、地理编码、沿途 POI（充电桩）
- **AMapLocation**：定位（虽然 iOS 自带 CoreLocation，但为了跨平台一致
  性、且高德定位在国内更准，建议使用高德定位）

**接入要点：**

- 需要在 [高德开放平台](https://console.amap.com/) 申请 iOS 平台 Key，
  与 Android Key 是同一个账户下不同平台的 Key，**不能复用 Android 的**。
- Bundle ID 要在高德后台登记，否则 SDK 不工作。
- API Key 通过 `Info.plist` 注入，不能进 git（参考 Android 的
  `local.properties` 模式）。
- SPM 不直接支持高德（高德官方目前只发 CocoaPods 和手动包），需要：
  - 方案 A：在仓库里加 `Podfile`，用 CocoaPods 管理高德 + 依赖；SPM 继续
    管 swift 代码 —— 但混用比较麻烦。
  - 方案 B：用本地 binary target 把高德 framework 包进 SPM —— 推荐。
  - 方案 C：转成传统 `.xcodeproj` —— 工程改动大，**不推荐**。
  - 决策放到 Phase 1 落地时根据高德 SDK 的发布形态再敲定。

### ② 充电桩选择算法：放后端 ✅（已定）

Android 在 `HomeViewModel.calculateChargingStops` 里用 ~100 行贪心：每段
选最远可达充电桩、最小间距 50 km、到达 SOC ≥ 15%、目标离开 SOC 80%。

**算法移到后端统一**：iOS / Android 都调 `POST /routes/charging-plan`，
避免两套实现漂移；后端也能根据用户车型动态调整参数。后续 Android 端
也应当从客户端移除该算法实现，改为调用同一接口。

待办：

- 确认后端 `/routes/charging-plan` 接口的请求/响应已经覆盖 Android 客户
  端算法的所有参数（min_arrival_soc、目标 SOC、最小间距等）。如有缺
  失，后端补齐。
- Android 端后续重构：客户端调用后端，移除本地算法。

## 分阶段计划

### Phase 1 —— 登录 + 能看到自己的车（MVP）

- 扩展 `APIService`，覆盖 Tesla OAuth、车辆相关接口
- 加 Keychain 封装（存 `auth_token`/`refresh_token`/`user_id`）
- `LoginView`：用 WKWebView 跑 Tesla OAuth
- `HomeViewModel`：拉车辆列表 + 轮询状态 + 离线时唤醒重试
- `HomeView`：高德地图，车辆位置标记 + 电量/续航顶栏
- 接入高德 iOS SDK（确定打包方式 + 写入 Key 注入流程）

**完成标准：** 用户能 OAuth 登录，看到地图上自己车的位置和电量。

### Phase 2 —— 搜索 + 路线预览 + 发送导航

- `SearchView`：高德 POI 搜索
- 地图 polyline 渲染（高德 SDK 自带 overlay）
- 抽屉式底部 sheet（自定义或 `presentationDetents`）
- 路线预览 UI：行程列表、可编辑出发 SOC
- "发送到车辆" → `/vehicles/{id}/navigate`
- 沿途充电桩搜索（高德 RoutePOISearch）+ 选取算法

**完成标准：** 用户能搜目的地、看到路线 + 充电站、发送到车机。

### Phase 3 —— 功能补齐

- 附近充电桩 tab + 类型过滤器（超充 / 目的地 / CCS / CHAdeMO / 国标）
- 最近行程 tab
- 设置页（目标到达 SOC、距离单位、超充偏好）
- 解绑 Tesla 账户
- 错误态 / 空态 / 加载态对比 Android 走查

## 需要补的数据模型（Swift）

Android 在 `data/model/` 下，iOS 需要在
`Sources/TePlannerKit/Models/` 下补对应：

- `Vehicle`：id、vin、displayName、model、state、isPrimary 等
- `VehicleState`：batteryLevel、batteryRange、lat、lng、chargingState 等
- `ChargingStation`：当前 `RouteModels` 里有部分；要补全 type 枚举、
  availableStalls、powerKw、operator、distanceKm
- `RoutePlan` / `ChargingStop` / `Location`：当前已有部分，需要和
  Android 调用的后端响应结构对齐

## 后端接口清单（参照 Android `BackendApi.kt`）

**认证：** `/auth/tesla/authorize`、`/auth/tesla/status`、
`/auth/tesla/unbind`、`/auth/validate`、`/auth/refresh`

**车辆：** `GET /vehicles/`、`GET /vehicles/{id}/state`、
`POST /vehicles/{id}/wake`、`POST /vehicles/{id}/navigate`

**路线 / 充电：** `POST /routes/charging-plan`（已部分使用）、
`GET /charging/stations/{id}`、`GET /charging/nearby`

## 现有 iOS 代码取舍

| 现有 | 处理 |
|---|---|
| `RouteModels.swift` | 保留，补 Vehicle / VehicleState / 完整 ChargingStation |
| `APIService` / `APIServiceProtocol` | 保留，大幅扩展接口 |
| `ContentViewModel` | 替换 —— 当前的"出发地/目的地输入框"模型和带地图的主页流程不一致 |
| `ContentView` | 替换为 `LoginView` / `HomeView`，根据 `tesla_linked` 切换 |
| `MapView` | 大改 —— 从 MapKit 切换到高德 SDK，承担车辆标记 + polyline + 充电桩标记 |
| `ItineraryView` | 保留 —— 行程列表 UI 在路线预览里能直接复用 |
| `Tests/.../ContentViewModelTests.swift`、`MockAPIService.swift` | 重写新 ViewModel 的测试，保留 Mock 注入模式 |

## 高德 iOS SDK 接入备忘

正式开始 Phase 1 时需要确认的事项：

1. 在高德开放平台为本工程申请 iOS Key（Bundle ID 现为 `teplanner...`，
   以实际为准）
2. SDK 打包方式：优先用 binary target 走 SPM；不行就 CocoaPods 混合
3. Key 存放：参考 Android 的 `local.properties.template`，提供
   `Config.xcconfig.example`，本机的 `Config.xcconfig` 进 `.gitignore`
4. 隐私合规：高德 SDK 必须在调用前先调 `AMapServices.shared().isAbroad`
   等隐私合规接口（`updatePrivacyShow` / `updatePrivacyAgree`），
   Android 端在 `TePlannerApp.kt` 的 `initAMapSDK()` 里做了，iOS 也要做
