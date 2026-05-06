# 自动化引擎 — 设计与今日计划

**Owner**: jack91620 / Claude
**Status**: 起草中（2026-05-07）
**Driving question**: Tesla 车机有"自动化"功能（位置/时间触发器），但官方 App 没有暴露。我们能不能在 App 端做一套，并且预置类似"露营超时提醒"这样的开箱即用规则？

Phase 5.1（露营超时）已经在 `AlertsViewModel` 里硬编码了一条规则。本文档把它升级成可复用引擎，并在此之上交付 Phase 5.2（哨兵 / 座舱过热）。

---

## 1. 总体策略

走"**预置规则库**"路线，先攒 5–8 条覆盖 80% 用户场景，**不**做可视化规则编辑器。

> **是不是最佳方案？**
>
> 候选方案：
>
> | | A. 预置库（选） | B. JSON/数据驱动规则 | C. App Intents / Shortcuts |
> |---|---|---|---|
> | 用户能否自定义 | 否（勾选 + 调阈值） | 是（如果做 GUI） | 是（在 Shortcuts App 里组合） |
> | 实现成本 | 每条 ~50 行 + 测试 | 解析器 + 类型安全损失 + GUI | Intents 定义，UX 在我们 App 外 |
> | 服务器下发新规则 | 否（要发版） | 是 | 否 |
> | 后台触发能力 | 受限于 polling | 受限于 polling | Shortcuts 不能轮询 Tesla |
>
> 选 A 的理由：
> - 特斯拉车主里愿意配置自动化的极少；"开箱即用的提醒"才是官方 App 的痛点。
> - 引擎协议要设计得让 B 是**非破坏性扩展**——后续真要加 JSON 规则，让 `JSONRuleAutomation` 类型 conform 同一个协议即可。
> - C 适合做"用户驱动的高级用法"（如"到家时给车预热"）作为补充，但替代不了 App 内持续监控。
>
> **风险**：如果用户量上来后预置规则不够用，得做 B 或 C。引擎协议留足扩展点即可。

---

## 2. 架构

### 2.1 组件位置

```
TePlannerKit/
  Models/
    VehicleAlert.swift          # 已有
    AutomationDefinition.swift  # 新：规则元数据（id / 标题 / 阈值字段）
  Automations/                  # 新目录
    Automation.swift            # 协议
    AutomationEngine.swift      # 注册表 + 求值循环
    CampModeAutomation.swift    # Phase 5.1 迁移
    SentryModeAutomation.swift  # Phase 5.2
    CabinOverheatAutomation.swift # Phase 5.2
  ViewModels/
    AlertsViewModel.swift       # 改造为引擎 host

TePlannerApp/
  AlertPillView.swift           # 不变，消费 VehicleAlert
  SettingsView.swift            # 新增"自动化"分组
  AutomationsListView.swift     # 新：规则列表 + 阈值配置
  Notifications/
    LocalNotificationScheduler.swift # Phase 5.1.1
```

> **是不是最佳方案？** Engine 在 Kit 里能跑 macOS 单测，UI 在 App 里。`UNUserNotificationCenter` 是 iOS-only，所以 scheduler 留在 App 侧；引擎只发 `Alert`，scheduler 监听 alert 流。**对 ✓**。

### 2.2 协议草案

```swift
public protocol Automation: Sendable {
    var id: String { get }                 // "camp_mode_timeout"
    var displayName: String { get }        // "露营模式超时"
    var category: AutomationCategory { get } // .reminder / .safety / .convenience

    /// Pull-based evaluation. Engine 每个 polling tick 调一次。
    /// 返回 nil 表示不出 alert；返回 alert 替换之前的同 id alert。
    func evaluate(context: AutomationContext) -> VehicleAlert?

    /// 主操作（"关闭"按钮）。返回 nil 表示无操作（仅信息提醒）。
    func primaryAction(context: AutomationContext) -> AutomationAction?
}

public struct AutomationContext {
    public let vehicleState: VehicleState?
    public let now: Date
    public let settings: SettingsStore
    public let stateMemory: AutomationStateMemory  // per-rule 持久化
}

public enum AutomationAction {
    case setClimateKeeperMode(vehicleId: String, mode: Int)
    case toggleSentry(vehicleId: String, on: Bool)
    case dismiss  // 仅清除 alert
}
```

> **是不是最佳方案？**
>
> - **`evaluate(...) -> VehicleAlert?`**：拉模型简单清晰。考虑过事件总线（状态变化时发 event），但 3 条规则用 event bus 是过度抽象——polling tick 调 N 个 evaluate 是 O(N) 且 N 小。**保留拉模型**，将来超过 ~10 条规则再考虑分拆。
> - **`AutomationAction` 用枚举而非闭包**：比直接传 `(APIService) async -> Result` 闭包好，因为 (a) 引擎层无需依赖 APIService，(b) 测试时可断言"产生了 .setClimateKeeperMode(0)"动作而不需要 mock API。**保留枚举 ✓**。
> - **`AutomationStateMemory`**：每条规则需要记自己的"首次满足条件的时间戳"（露营从几点开始）。考虑过：(1) 内存（重启丢，UX bug），(2) UserDefaults（简单但所有规则共享 store），(3) 每规则一个 `key` 的 `KeyValueStore` 注入。选 3，因为干净且可注入 InMemory 做测试。

### 2.3 引擎循环

```swift
@MainActor
public final class AutomationEngine: ObservableObject {
    @Published public private(set) var alerts: [VehicleAlert] = []
    private let registry: [any Automation]
    private let memory: AutomationStateMemory
    private let settings: SettingsStore

    public func observe(_ state: VehicleState?) {
        recompute(state: state)
    }

    public func recompute(state: VehicleState?) {
        let now = Date()
        let ctx = AutomationContext(vehicleState: state, now: now, settings: settings, stateMemory: memory)
        var emitted: [VehicleAlert] = []
        for rule in registry where settings.isAutomationEnabled(rule.id) {
            if let alert = rule.evaluate(context: ctx) {
                emitted.append(alert)
            }
        }
        alerts = emitted.sorted { $0.severity.priority > $1.severity.priority }
    }

    public func performPrimaryAction(of alert: VehicleAlert, api: APIServiceProtocol) async -> Result<Void, APIError> { /* ... */ }
}
```

> **是不是最佳方案？**
>
> - 不持久化 `alerts`：每次重算。规则数量小，便宜。
> - **优先级排序**：critical 在前。Pill 只展示第一个，列表展示全部（未来如果有多 alert 同时活跃）。
> - 没用 Combine pipelines：直接 `recompute()` 显式调用更易调试和测试。**保留 ✓**。

---

## 3. 通知触达

> **核心问题**：露营超时这种"App 关闭后还得提醒"的场景，pill 是不够的。

| 触达方式 | 何时触发 | 何时可用 | 决定 |
|---|---|---|---|
| In-app pill | App 前台 + 定时器跳出 | 现在已经有 | 保留 |
| 本地通知（UNUserNotificationCenter） | App 前台时引擎触发后 schedule | 现在可做（无需付费 dev program） | **今天加（Phase 5.1.1）** |
| APNs 远程推送 | 服务端 cron polling 后 push | 需要付费 dev + 服务端 polling 基建 | **暂缓** |

> **是不是最佳方案？**
>
> 本地通知有个**真实漏洞**：用户开 App → 看到露营开 → 锁屏走开 → 4 小时不再 polling → 不会提醒。这个场景**只能靠 APNs 解**。
>
> 但是：
> - 当前 $99 Apple Developer Program 还没付，APNs 走不通
> - 服务端 polling 还要写每用户的 token 刷新 / 频率控制 / 成本估算
>
> 所以本地通知是**有缺陷但可用**的中间态：覆盖"刚关 App 后 30 分钟内"的场景（iOS 后台 fetch 偶尔会跑），让代码框架先就位。**等付费上线 + 服务端 polling 后切 APNs**，引擎和 alert 模型不需要变。
>
> **暂时方案 ✓**，但是要在 README/Settings 文案明确告知用户"App 长时间关闭可能漏报"。

---

## 4. 今日交付（2026-05-07）

### 已完成
- ✅ 路线预览短距离显示修复（`formatDistance` 三档）

### 主线（按依赖顺序）

#### Slice 1：引擎骨架 + 迁移露营规则（~60 分钟）
- 新建 `TePlannerKit/Sources/Automations/` 目录
- 定义 `Automation`、`AutomationContext`、`AutomationAction`、`AutomationStateMemory`
- 把 `AlertsViewModel` 拆成 `AutomationEngine`（Kit）+ thin VM（App，只是把 vehicleId 注入并执行 action）
- `CampModeAutomation` 实现 + 把现有 8 个测试搬过来（断言改成"engine 出了 .campMode alert"）

> **是不是最佳方案？** 也考虑过"先加 5.2，再回头重构"。否：先重构能让 5.2 是干净的 ~50 行新 struct，否则得在 5.2 时同时改 5.1 的耦合代码。**先重构 ✓**。

#### Slice 2：Phase 5.2 哨兵 / 座舱过热规则（~60 分钟）
- `SentryModeAutomation`：阈值"哨兵开启超过 N 小时"（默认 12h），critical 时给"关闭哨兵"action（POST `/vehicles/{id}/sentry-mode`，后端待加）
- `CabinOverheatAutomation`：座舱过热保护开启时只发 info pill（车辆已自动通风/降温，无需用户动作）
- 后端：加 `POST /vehicles/{id}/sentry-mode` 端点（参考露营 pattern）
- 测试：每条规则 5–6 个用例

> **是不是最佳方案？** 哨兵的"关闭"动作有副作用（关了停车安全降低）。考虑过只发提醒不给关闭按钮。决定：**仍提供关闭按钮但加确认对话框**——主动关闭是用户已知并接受的选择。

#### Slice 3：Settings UI（~30 分钟）
- 新建 `AutomationsListView`：列出所有注册的规则，每条一个 `Toggle` + 一个阈值控件（`Slider` / `Stepper`）
- `SettingsView` 加一个跳转入口"自动化提醒"
- 旧的"露营模式超时提醒" section 删掉，迁移到新页

> **是不是最佳方案？** 也可以把所有规则平铺在 Settings 主页。否：3 条还行，到 8 条就太挤；一开始就拆出独立页便于扩展。**拆 ✓**。

#### Slice 4：Phase 5.1.1 本地通知（~45 分钟）
- `LocalNotificationScheduler`（App 侧）订阅 engine 的 `alerts`
- 当某个 alert 从无→critical / info→critical **状态翻转**时 schedule 一条本地通知
- 应用启动时请求 `UNAuthorizationOptions = [.alert, .sound]` 权限
- 同一 alert 不重复推（用 `notificationIdentifier == alert.kind.rawValue`）
- App 前台时静音（避免 pill + banner 重叠）

> **是不是最佳方案？**
> - 状态翻转触发 vs. 每次 evaluate 都 schedule：选**翻转**，否则会刷屏。
> - 通知的 dismiss action：iOS 14+ 通知里可以加 action button（"关闭露营模式"）。考虑过加，否：通知里跑 API call 需要 Notification Service Extension，复杂；先在 App 内点 pill 操作就行。**先不做 ✓**。

#### Slice 5：测试 + Maestro（~30 分钟）
- 引擎单测：注册 3 条规则，分别构造车辆状态，断言 alerts 列表正确
- Maestro：08_automation_settings.yaml — 进设置 → 自动化页 → 切换开关 → 调阈值 → 验证保存

### 暂缓 / 阻塞
- ❌ **后端 git-pull 切换**：等用户回办公室处理 SSH 权限规则
- ❌ **APNs 远程推送**：等付费 Apple Developer Program 通过
- ❌ Phase 5.3 充电完成提醒：作为下一条 Automation，引擎稳定后再加（事件触发——状态从 Charging → Complete）
- ❌ Phase 5.4 充电统计 / 5.5 行前预热 / 5.6 智能充电限制

---

## 5. Open questions（需要确认）

1. **哨兵阈值默认值**：定 12h 还是 6h？哨兵每小时耗 1% 电左右；用户离车一般不会想让它哨兵几天耗光电池。**倾向 12h**，但欢迎反馈。
2. **座舱过热提醒到底有没有用？** 车自己已经会自动通风。如果只是状态展示，可能更适合放在 HomeView 状态栏而不是 alert pill。**待用户决定**——可能 5.2 只交付哨兵，过热作为 status badge。
3. **本地通知文案**：露营严重提醒文案"露营模式已开启 X 小时，电量 Y%"——是否够 actionable？还是要更紧迫"⚠️ 离车 X 小时仍开露营"？
4. **AutomationStateMemory 实现选 UserDefaults 还是 Keychain？** UserDefaults：简单、不敏感数据；Keychain：跨重装保留，但配置开销。**倾向 UserDefaults**——状态丢了最多漏一次提醒，不是凭据。

我会按 Slice 1→5 顺序推进，遇到上述问题中的关键节点会停下来问。

---

## 6. 演进路线（不在今日范围）

```
今日:  AutomationEngine + 露营/哨兵/过热 + 本地通知
       ↓
+1 周: Phase 5.3 充电完成（事件型规则示例）
       ↓
+2 周: Phase 5.5 行前预热（时间触发器示例 — 接 calendar/scheduled_departure）
       ↓
+1 月: 付费 Apple Developer 上线 → 服务端 polling + APNs（覆盖 App 关闭场景）
       ↓
+ 远: 评估用户量是否足够支撑 B（JSON 规则）或 C（Shortcuts）
```

---

## 7. 决策日志（保留以便后人理解为什么这样选）

- **2026-05-07**: 选预置库路线（A）而非数据驱动（B）或 Shortcuts（C）；引擎协议预留扩展点。
- **2026-05-07**: 拉模型（每 polling tick 全量 evaluate）而非事件总线——3 条规则成本低。
- **2026-05-07**: `AutomationAction` 用枚举而非闭包，引擎不依赖 APIService，便于测试。
- **2026-05-07**: 本地通知作为 APNs 上线前的中间方案；engine/alert 模型不变以便切换。
