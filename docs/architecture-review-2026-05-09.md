# Architecture Review + Fallback Audit — 2026-05-09

Two parts:

1. **架构审视** — 全局结构、耦合点、tech debt、最优方案提议
2. **Fallback 清单** — 所有 silent fallthrough / 兜底路径，标注「保留」/「该删」/「需要你拍板」

---

## Part 1 — 架构审视

### 当前结构（已经清完 android/miniprogram 后）

```
TePlanner/
├── Sources/TePlannerKit/        16 K LOC Swift, 跨平台逻辑（macOS 可 build）
│   ├── Models/                  纯数据
│   ├── Services/                APIService / AuthSession / SettingsStore / ...
│   ├── Capabilities/            VCP capability registry (iOS 镜像 backend)
│   ├── Automations/             rule interpreter + engine + presets
│   └── ViewModels/              @MainActor ObservableObject
├── TePlannerApp/                AMap-backed views, App entry
│   ├── HubView (1035 LOC) ⚠️ god view, owns ENGINE+STORE+TRACKER+STATS
│   ├── RuleBuilderView (1484 LOC) ⚠️ 拆分候选
│   └── (其余 28 个 .swift)
├── Tests/TePlannerTests/        156 unit tests
├── backend/                     11 K LOC Python, FastAPI
│   ├── api/v1/                  3.1 K LOC route handlers ⚠️ 业务逻辑混在 handler 里
│   ├── services/                领域服务（automation, capabilities, telemetry, ...）
│   ├── integrations/            tesla / amap / apns
│   └── db/                      models + session
├── ops/                         watchdog + reports
├── e2e/                         hurl (API 契约) + maestro (iOS UI)
└── docs/                        架构文档 + 部署文档
```

**好的部分**:
- iOS 是清晰的「Kit (logic) + App (UI/SDK)」分层。Kit 在 macOS 上能 build，单元测试能覆盖大部分核心。
- 后端的 `services/` + `capabilities/` registry 是干净的领域分层（capabilities 是亮点，每个能力有 `expected_state` 给 Phase 9 闭环用）。
- ops/ + 后端的 ensure_presets_seeded 幂等 backfill 是好习惯。

**架构 smell**（按严重程度排序）:

#### 1. ⚠️ HIGH — 业务逻辑在 FastAPI route handlers 里

`backend/app/api/v1/auth.py` 859 LOC，`vehicles.py` 850 LOC，`routes.py` 663 LOC。这些 handler 既做 HTTP I/O，也做：token 加密 / Tesla SDK 调用 / 数据库写 / 业务规则。

**最优方案**：
- 把 handler 里的业务逻辑提到 `services/` 下的领域服务。Handler 只做：parse request → call service → return response。
- `auth.py` → `services/auth/{oauth,session,encryption}.py`，handler 缩到 ~150 LOC。
- `vehicles.py` → handler 改用 `capabilities/` registry 派发，自己只剩 「寻找 VIN + 调用 capability」 的薄壳。
- 收益：测试可以直接 import service 跑（不用启 TestClient），重构时不用改 HTTP 接口。

#### 2. ⚠️ HIGH — `HubView.swift` god object (1035 LOC)

它同时持有：
- `viewModel: HomeViewModel`（车辆状态）
- `automationEngine: AutomationEngine`（规则评估）
- `rulesStore: AutomationRulesStore`（规则数据）
- `statsViewModel: ChargingStatsViewModel`（充电统计）
- `apiService: APIServiceProtocol`
- 通知调度 / VCP pairing prompt / charge limit 建议 / 命令状态轮询 / 出发计划 / ...

**最优方案**：
- 抽 `AutomationCoordinator` 一个 ObservableObject，把 engine + rulesStore + 通知 wiring + cold-launch buffer 全放进去。HubView 只 observe `automationCoordinator.alerts` 就够了。
- 抽 `VCPPairingCoordinator` 处理那一坨 prompt + pairing URL 逻辑。
- 抽 `ChargeLimitSuggestionCard` / `DepartureCard` 等子视图（每个 ~80 LOC，独立可测）。

预期 HubView 减到 ~400 LOC，5+ 个独立可测组件。

#### 3. MEDIUM — `RuleBuilderView.swift` 1484 LOC

里面已经有 `TriggerType` / `VehicleEntity` / `GeofenceEvent` / `ActionType` 等 enum，加上 4 种 trigger 的 editor + 32 个 capability 的 default param table + 每个 capability 的 inline UI。

**最优方案**：
- 抽 `TriggerEditor`（branch on triggerType → 4 个 sub-editor）
- 抽 `CapabilityParamEditor`（switch on capabilityId → 10+ 个 small view）
- 把 `defaultParams` / `defaultButtonLabel` table 移到 `Sources/TePlannerKit/Capabilities/CapabilityDefaults.swift`，和 capability 定义同源。
- 预期 RuleBuilderView 主文件减到 ~500 LOC。

#### 4. MEDIUM — iOS interpreter 是 backend interpreter 的镜像复制

`Sources/TePlannerKit/Automations/Interpreters/Interpreter.swift` 跟 `backend/app/services/automation/interpreters.py` 实现了相同的语义（state_duration / state_transition / cron / geofence）。两边手动同步，已经出现过 backend 加了 enabled 字段 iOS 没读、iOS 算 cron 跟 backend 算法略不同的小漂移。

**最优方案**（重）：
- 选项 A：把 interpreter 抽成 backend 的唯一权威，iOS 端只做「拉规则 → push 到 backend `/api/v1/automations/{id}/dry-run` → 渲染结果」。代价：iOS 离线时不能即时评估（实测 alert pill 会延迟到下次 polling tick）。
- 选项 B：保持双实现，但加端到端 contract 测试（同一组 spec + state，对比两边 output 必须一致）。代价：维护契约测试。

我倾向 B — iOS 离线即时评估对 UX 价值大，且 backend 的 push 兜底已存在。

#### 5. LOW — `ScheduledDepartureStore` / `SettingsStore` 都用 UserDefaults，命名空间混合

15+ key 都堆在一个 UserDefaults 里。`SettingsKey.*` 常量集中是好的，但 `ScheduledDepartureStore` 用自己的 key（不在那个 enum 里）。

**最优方案**：
- 把所有 key 集中到 `SettingsKey` enum，互相不冲突。
- 没 schema migration — 真要换存储引擎（CoreData / SQLite）以后再考虑。

### 测试覆盖空白（按风险排序）

| 区域 | 现状 | 风险 |
|---|---|---|
| `cron_tick` lifecycle | 0 测试 | 刚出 session-poison bug，没测试拦截 |
| `ensure_presets_seeded` backfill | 0 测试 | 刚加，可能漏人 |
| `LocalNotificationScheduler` cold-launch buffer | 0 测试 | 真机还没验证 |
| AMap SDK 调用（route preview / map picker） | 0 单元测试 | 靠 Maestro 兜底 |
| Tesla VCP 端到端 | 0 单元测试 | 靠真机 + tesla-http-proxy |

`cron_tick` 和 `ensure_presets_seeded` 应该立即补单元测试。

---

## Part 2 — Fallback 清单（你拍板）

按「危险性」从高到低排，每条标注 **建议**（删 / 保留 / 改）。

### 🔴 危险 — 默认建议「删」（违反 fail-fast）

| # | 位置 | 行为 | 影响 | 建议 |
|---|---|---|---|---|
| F1 | `backend/app/api/v1/auth.py:494` | `encryption.encrypt(token)` 失败 → **存明文 token** | 安全洞 — token 泄露 | **删**：encrypt 失败应 raise 500，让 deploy 配置错误暴露出来 |
| F2 | `backend/app/api/v1/auth.py:579` | 同上（refresh token 路径） | 同上 | 删 |
| F3 | `backend/app/api/v1/auth.py:654` | `decryption` 失败 → **直接用密文当明文** | 同上 + 数据损坏可能没人发现 | 删 |
| F4 | `backend/app/core/deps.py:159` | Tesla token 解密失败 → 当明文用（注释「legacy 兼容」） | 历史包袱，未加密用户的兼容路径 | **改**：检测 `auth.py` 数据是否已全部加密；是则删；否则加 migration |
| F5 | `backend/app/services/command_queue.py:120/139` | refresh_token 解密失败 → 当明文 | 同 F4 | 同 F4 |

**这 5 条是同一个底层问题**：早期 Tesla token 加密未启用，之后加了 `Fernet` 但保留了「未加密兼容」路径。建议你回答一个问题：现在 DB 里 `tesla_tokens.access_token / refresh_token` 是否 100% 加密了？是 → 5 条全删；否 → 一次性 migrate 后再删。

### 🟡 可疑 — 默认建议「改」

| # | 位置 | 行为 | 影响 | 建议 |
|---|---|---|---|---|
| F6 | `backend/app/services/route_planner.py:153/158` | reverse_geocode 失败 → 起点/终点名 = `""` | 路线规划仍返回，但前端显示「目的地」是空字符串 | **改**：把 `origin_name=""` 改成 `origin_name=None`，让前端展示「未知地点」而不是空字符串 |
| F7 | `Sources/TePlannerKit/Services/ChargingSessionStore.swift:69` | UserDefaults JSON 解码失败 → `return []` 然后丢掉所有历史 session | 用户的充电历史无声丢失 | **改**：把损坏的 blob backup 到另一个 key (`charging_sessions.broken`)，再返回 []。下次启动时给用户一个提示 |
| F8 | `Sources/TePlannerKit/Automations/AutomationEngine.swift` | snooze 中的规则不在 alerts 里 | 用户期望，OK | **保留** |
| F9 | `TePlannerApp/AutomationsHomeView.swift:455` | `position[id] ?? (fallback + offset)` — 没保存顺序的规则按原顺序追加 | 合理 | **保留** |

### 🟢 合理 — 默认建议「保留」

| # | 位置 | 行为 | 理由 |
|---|---|---|---|
| F10 | `cron_tick.py:108` | 单用户失败 → rollback session + log + continue | 失败隔离正是我们刚修的 fail-fast 模式 |
| F11 | `telemetry/consumer.py:134/178` | telemetry 写失败 / engine tick 失败 → log + return（不影响其他车） | 同 F10 |
| F12 | `automation/interpreters.py:241` | 时区字符串无效 → fall back UTC | 配置错误，不应该崩；UTC 是合理 default |
| F13 | `automation/interpreters.py:258` | croniter 解析失败 → return None（这条规则不触发，其他正常） | 单规则隔离 |
| F14 | `integrations/amap/web_client.py:144/246` | AMap 返回缺 lat/lng → (0, 0) | AMap 数据真的脏，硬 fail 整路线规划损失大 |
| F15 | `Services/APIService.swift` 所有 `} catch {`  | 网络/解码失败 → return `Result.failure` | iOS 网络错误就是该 propagate，不算 fallback |
| F16 | `AlongRoutePOIService.swift:69` | 单 chunk 沿途搜索失败 → throw（让 group 整体失败） | 正确传播 |

### 🔵 文档型 fallback（注释里的措辞）— 默认「保留」

`Sources/TePlannerKit/ViewModels/HomeViewModel.swift:9` 注释提到「fallback to .offline」、`Interpreter.swift:114` 注释提到「fallback to equals for compat」— 都是 enum 状态/字段兼容。OK。

---

## 行动清单（按你拍板的顺序）

请回三个问题：

**Q1**：F1–F5（Tesla token 加密兼容路径）— `tesla_tokens` 表里现在是否 100% 加密？
- 答「是」→ 我直接删 5 处 silent fallback，让 encryption 异常 raise
- 答「否」→ 我先写 migration 脚本把存量加密，再删

**Q2**：架构 4 个重构里你想先做哪个？
- A. 把 backend 业务逻辑从 handler 提到 service（最值钱，最独立）
- B. 拆 HubView god object（5 个 coordinator/subview）
- C. 拆 RuleBuilderView（4 个 trigger editor 子文件）
- D. 加 cron_tick + ensure_presets_seeded 单元测试（小，安全）

**Q3**：F6 / F7 这两个「改」的提议要不要做？
- F6 改 origin_name 类型 nullable（破坏 API 契约小，要 iOS 配合）
- F7 损坏 session blob 备份后再清空（纯 iOS-side，无破坏性）
