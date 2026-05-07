# iOS 迁移方案 —— 对齐 Android 功能

本文最初是把 Android 端功能迁移到 iOS 的总规划。Android 是参考实现，
iOS 追平。**截至 2026-05-07，iOS 已经全面超过 Android**——iOS 现在
有 Phase 5 自动化引擎、hub-and-spoke 主页、VCP 真车命令、电池管理
页、单一 AMap 供应商，这些 Android 都没有。

## 状态总览（2026-05-07）

| Phase | 状态 | Commit / 说明 |
|---|---|---|
| 1 — 登录 + 看到自己的车 | ✅ | Tesla OAuth + 车辆状态 + 唤醒重试 |
| 2 — 搜索 + 路线预览 + 发送导航 | ✅ | AMap POI 搜索 + 路线 polyline + 充电站 + 发送到车机 |
| 3 — 功能补齐 | ✅ | 附近 / 最近 tabs + 解绑 + 充电桩详情 sheet |
| 4 — iOS 独有：位置反向地理编码 | ✅ | Hub 状态卡的"丰台区..." |
| 5.1 — 露营超时提醒 | ✅ | `a6e4409` + 重构成 AutomationEngine `4e7d784` |
| 5.1.1 — 本地通知 | ✅ | `3784b92` UNUserNotificationCenter |
| 5.2 — 哨兵 / 座舱过热 | ✅ | `e9bd4d6` |
| 5.3 — 充电完成 | ✅ | `e0b38c1` 第一条 event-driven 规则 |
| 5.4 — 充电统计 → 电池管理页 | ✅ | `5d73efb` + 重构成电池管理 `9c4d546` |
| 5.5 — 出发前预热 | ✅ | `d595901` |
| 5.6 — 智能充电限额建议 | ✅ | `bf5506a` |
| 6 — Hub 主页（hub-and-spoke）| ✅ | `f8f9e06` Tesla-app-inspired layout |
| 7 — Tesla VCP 真车命令 | ✅ | `fac6a96` + `47fc757` 4 个签名命令全部上线 |
| 8.1 — 单一 AMap 供应商 | ✅ | `444bad1` 后端从腾讯切到 AMap Web Service |
| 8.2 — 沿途搜索移到 iOS SDK | ✅ | `adee6eb..8eb8955` 真高速服务区充电站 |
| 9 — TestFlight | ✅ | `833b935` 首个 build 上传成功 |

底色还在的工作（不在原 plan 范畴）：

- iOS 真车 sentry / camp / preheat 命令验证（只验证了 set_charge_limit，剩下 3 个走相同代码路径但没真发过）
- 节假日提醒（候选，未启动）
- TestFlight 外部测试员 + Beta App Review（等首个 build 处理完）

---

## 架构决定（仍有效）

### ① 地图方案：高德 ✅

iOS SDK + 后端 Web Service 都用高德。Phase 8.1 把后端的 Tencent 全
部替换成 AMap Web Service。Phase 8.2 把沿途充电站搜索移到 iOS SDK
（高德 Web `place/around` 是圆形采样，会拉到不在路上的 POI；SDK 的
`AMapRoutePOISearchRequest` 是真道路走廊算法）。**单一供应商让隐
私协议、配额、bug 排查都简单**。

### ② 充电桩选择算法：放后端 ✅

`POST /routes/charging-plan` 收 polyline + 客户端搜的 POI 列表 +
SOC，跑贪心算法，返回选中的充电站。Android 仍然用客户端贪心，理
想情况下也应该改调后端，但目前 Android 是 read-only 参考实现，不
强求。

### ③ 客户端编排 vs 一站式后端 (Phase 8.2)

后端 `/routes/plan` 一站式 endpoint **已删**。新流程是 iOS 编排：

```
1. POST /routes/route          → polyline + dist + dur
2. AMap iOS SDK alongby        → 沿途充电站 POI
3. POST /routes/charging-plan  → greedy 选站
```

**Why**：`alongby` 是 SDK 独有的真道路走廊算法，Web Service 没有
对应的免费接口。把它放服务端就只能用 `place/around` 采样，质量差。
让客户端编排打破了"算法集中后端"的原则一次，但是为了正确性。

未来加 Android：要么 Android 也走相同 3-step 编排（用 AMap Android
SDK 的同名接口），要么再搞个后端 wrapper。先不做。

### ④ Fail-fast 原则（项目级）

**不写 cascading fallback**。Phase 8.2.4 删了所有"如果 X 失败试 Y"
的代码路径——legacy `/routes/plan`、`/charging/service-areas`、
后端 sampling fallback、`_find_optimal_charging_stops`。同一个工
作只有一条路径执行。失败要冒到 UI。

详见 memory `feedback_fail_fast.md`。

---

## 顶层定位（2026-05-07 对齐）

不是 Tesla 官方 App 的 iOS 替代品，也不是单一长途路线规划工具。是
**「Tesla 路线规划 + 官方 App 没做好的自动化提醒」**：用户每天打开
都能用，但不与官方 App 在「即时控制 / 状态展示」的强项硬刚。

**IN scope**

- 充电路线规划（Phase 1-3 已交付）
- 实时车辆位置 + 反向地理编码地址（Phase 4）
- 状态遗忘类提醒：露营 / Sentry / Cabin Overheat 长期开启（5.1-5.2 已交付）
- 出发前自动预冷 / 预热（5.5 已交付，目前是引导用户自己点应用）
- 充电完成 / 接近满电提醒（5.3 已交付）
- 充电统计（5.4，已合并入电池管理页）
- 充电限额智能建议（5.6 已交付）
- 真车命令（关露营 / 关哨兵 / preheat / 调充电限额，Phase 7 VCP 通了）

**OUT of scope**（明确不做，Tesla 官方 App 已经做得够好）

- 门锁 / 解锁
- 前 / 后备箱开启
- 窗户 / 天窗控制
- 空调温度日常调节、座椅加热
- Sentry / Pet mode 日常切换
- 鸣笛闪灯（找车）

**EXCEPTION**：上述 OUT 命令只允许出现在**对应提醒的 action 按钮**
里。例如「露营模式已开 2 小时」提醒里有「关闭」按钮，调用
`set_climate_keeper_mode(0)`。不在主界面铺开成 control panel。

---

## Phase 6 — Hub-and-spoke 主页

实现：`f8f9e06` feat(home): hub-and-spoke home page (Tesla-app inspired)

参考 Tesla 官方 App 的入口式布局——顶部车辆状态卡，下方一列功能
入口。**HubView 是 owner 层**：拥有 `HomeViewModel` + `AutomationEngine`
+ `ChargingSessionTracker` + `ScheduledDepartureStore`。子页通过
`@ObservedObject` 接收，避免重复 polling 或下钻丢状态。

Layout：
```
HubView
├─ Status card (battery ring 92pt + range hero 44pt)
├─ AlertPillView                       (条件)
├─ "下次出行" card (Phase 5.5)         (条件)
├─ Charge-limit suggestion (Phase 5.6) (条件)
├─ NavigationLink → MapHomeView (充电规划)
├─ NavigationLink → AutomationsListView (自动化提醒)
└─ NavigationLink → BatteryView (电池管理)
```

子页的菜单只放 contextual 操作（地图页有刷新 / 清除路线 / 路线设置）。
账户级操作（退出登录 / 解绑 / VCP 配对）只在 Hub 菜单。

---

## Phase 7 — Tesla VCP（详见 CLAUDE.md "Tesla VCP" 段）

Tesla 2023-10-09 起所有 vehicle command 必须用新的 Vehicle Command
Protocol（partner key 签名）。基础设施：

- 服务端 ECDH-P256 keypair（`~/teplanner-keys/`）
- nginx 暴露 `/.well-known/appspecific/com.tesla.3p.public-key.pem`
- `tesla-http-proxy` Go 二进制 systemd 跑 `127.0.0.1:4443`
- 后端 `_send_command` 走 proxy + VIN 解析
- iOS HubView 一次性引导 `tesla.com/_ak/api.teplanner.cloud` 完成
  partner key 与车辆的配对

`set_charge_limit` 已端到端验证（车辆充电限额从 100% → 70% 真生效）。
其余 3 个命令走相同代码路径，未单独验证。

---

## Phase 8 — 单一供应商 + 沿途搜索质量

### 8.1 后端从 Tencent 切 AMap Web Service

`backend/app/integrations/amap/web_client.py` 是 drop-in 替换，
mimics Tencent client 的方法签名 + 返回 dict 形状（`title` /
`_distance` / `location: {lat, lng}` 等翻译自 AMap 原生 shape），
所以 `charging.py` / `routes.py` / `route_planner.py` 只改了
import 一行。腾讯 client 整个删了。

### 8.2 沿途充电站搜索移到 iOS SDK

详见上方"架构决定 ③"。删了大约 750 行后端 fallback 代码。真路线
测试（北京→苏州 1130 km）出来的是「廊沧高速木门店服务区」「钢城区
颜庄街道有序专用充电站」「淮安涟水保滩养护工区充电站」——全是高速
沿线的真服务区。

---

## Phase 9 — TestFlight

`833b935` build(archive): swap AMap pods to device slices, then back to sim

关键障碍：AMap 用 vtool retag 把 arm64 slice 标成了 simulator
（platform=7），device archive 链接器拒绝。`scripts/restore-amap-device.sh`
从 `.orig` 备份还原 device slice，archive 完再跑一次 sim retag——
开发环境保持 sim 状态。

ASC 配置：
- Team ID 在 Config.xcconfig（gitignored）
- ASC API Key `~/.appstoreconnect/private_keys/AuthKey_*.p8`
- `Info.plist` 加了 `ITSAppUsesNonExemptEncryption=NO`（我们只用
  系统 TLS / Keychain，符合 EAR §740.17(b)(1) 例外）

首个 build v1.0.0 (2) 已 upload，处理中。

---

## 后续候选（按价值）

1. **节假日前一天充电提醒** —— 通过 EventKit 读 iOS 自带的"中国节假日"
   订阅日历，在节前一天做一次 charge-limit-suggester 评估。复用 Phase
   5.6 的 Hub 卡片 UI，几乎零新增前端工作。
2. **真车命令端到端验证** —— sentry / camp / preheat 三条同路径未真
   发过。下次 jack91620 用这些功能时观察。
3. **Beta App Review + 外部测试员** —— 等首个 TestFlight build 处理
   完。
4. **APNs 远程推送** —— 解决"App 关闭时露营模式提醒不到"。需要服务
   端 polling 基建（cron + 用户 token + Tesla API 频率控制）。延期。

---

## 历史：原始迁移阶段计划（仅作参考）

下面是项目最初定的迁移计划，所有阶段都已交付。保留作历史背景。

### Phase 1 — 登录 + 看到自己的车（MVP）

扩展 `APIService`，覆盖 Tesla OAuth、车辆相关接口；加 Keychain 封
装；`LoginView` WKWebView OAuth；`HomeViewModel` 拉车辆 + 轮询 +
唤醒重试；`HomeView` AMap 地图 + 顶栏；接入 AMap iOS SDK。

### Phase 2 — 搜索 + 路线预览 + 发送导航

`SearchView` POI 搜索；地图 polyline；抽屉式 bottom sheet；路线预览
UI；"发送到车辆" → `/vehicles/{id}/navigate`；沿途充电桩搜索（最初
用后端 alongby，Phase 8.2 移到 iOS SDK）。

### Phase 3 — 功能补齐

附近充电桩 tab + 类型筛选；最近行程 tab；设置页；解绑 Tesla 账户；
错误态 / 空态 / 加载态走查。

### Phase 4 — iOS 独有的微小提升

车辆当前位置反向地理编码（"丰台区耀阁酒店"），后台轮询 polling
跟随 `Environment(\.scenePhase)`。

### Phase 5 — 自动化提醒（顺序）

5.1 → 5.6 全部交付。详见上方状态表。架构上经过一次重构：
`AlertsViewModel` 一次性硬编码 → `AutomationEngine` 协议化。
