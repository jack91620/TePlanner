# iOS 上线前测试方案

适用范围：从 TestFlight build 36 升级到下一个对外版本（build 37+）。

目标：在没有真用户损失的前提下走通一次完整的上线流程，让我们在
出问题时**知道是哪一层**，并且**可以在 5 分钟内回滚**。

> 这份文档只覆盖 iOS。Android / HarmonyOS 单独走各自的测试方案。

---

## 一、本次发版的实际变化（影响测试范围）

最近 ~20 个 commit 里改的部分：

| 区域 | 变化 | 风险等级 |
|---|---|---|
| D.3 ScheduledDeparture | 本地 UserDefaults → 后端 API | 高 |
| D.4 ChargingSession | 本地 tracker → 后端 cache | 高 |
| D.5 ChargeLimitSuggestion | 本地算法 → 后端 `/suggest-charge-limit` | 高 |
| E 推送多路 | 后端新增 dispatcher（APNs / JPush / Huawei） | 中（iOS 走 APNs 老路径） |
| Backend 新增 `/automations/capabilities` | 服务于 RuleBuilder | 中 |
| Backend 新增 `/auth/tesla/unbind` | 2026-05-11 才加 | 中 |
| 2026-05-10 P0 telemetry stale ghost push 修复 | `_read_value` + state_writer 重复行 self-heal | 高（已上线） |

D.3/4/5 都是 **iOS 端逻辑下沉到后端**——后端不上线 iOS 就读不到旧
数据；iOS 不上线后端就会被旧客户端冲掉。**两边必须一起发**。

---

## 二、风险盘点（按"上线后影响"倒序）

| # | 风险 | 影响范围 | 当前覆盖 | 杀伤力 |
|---|---|---|---|---|
| 1 | **D.3/4/5 数据迁移** 老用户从 build 36 升级到新版，本地数据不丢 / 不重 | 现有 iOS 用户 | iOS 单测 ✓ TestFlight 实测 0 | 严重：用户的出行 / 充电历史可能"消失" |
| 2 | **TestFlight build 37 archive** 链路：AMap pod 设备-tag 切换、签名、IPA 上传 | 全部 iOS 用户 | iOS 多次上 TestFlight ✓ 当前 branch 0 | 中：上传失败拖 1–2 天 |
| 3 | **APNs 在新 dispatcher 后**还能正常推送 | 全部 iOS 用户 | iOS 历史 ✓ 新代码 0 | 严重：自动化提醒全失效 |
| 4 | **VCP signed command** 真车真贵 | 用户的"一键执行" | iOS 历史 ✓ 当前 branch 0 | 严重：点了无反应 + 银行扣费 |
| 5 | **Tesla Fleet Telemetry consumer**（state stale + duplicate row）2026-05-10 P0 | 任何 telemetry-driven 规则 | 已上线 server 实跑 | 高（已 mitigated） |
| 6 | **Anonymous user leak**（`/auth/tesla/authorize` 不带 user_id） | 任何首次安装 | 2026-05-10 cleaned + log warning | 中（看 log 能感知） |
| 7 | **WGS-84 ↔ GCJ-02** 在生产环境 | 所有 geofence 规则 | iOS 单测 ✓ 真机 0 | 高（silent，500m 偏） |
| 8 | **Cron `Asia/Shanghai`** weekday preheat 跨日 / DST | 用 cron 规则的用户 | 后端单测 ✓ | 中（提前 8h 触发 = 用户怀疑 app） |
| 9 | **充电规划路线** 在沿途充电站稀疏地区 | 长途用户 | iOS Maestro ✓ | 中（路线找不到） |
| 10 | iOS 17 / 18 / 19 兼容（最低 iOS 17） | OS 版本碎片 | 模拟器 17/18 ✓ 真机 0 | 低 |

---

## 三、测试分层（金字塔）

```
                  ┌──────────────────┐
                  │ Phase 6: TestFlight │  build 37 公开 beta
                  │  10–20 用户 × 48h   │  → 0 critical
                  └─────────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │  Phase 5: 真车 E2E         │  你 + 黑胖子，6 个场景
              │  含 VCP + APNs 真推送       │
              └─────────────┬─────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │  Phase 4: 端到端回归（升级路径 + 全功能）│
        │  build 36 → 37 数据迁移验证           │
        └───────────────────┬───────────────────┘
                            │
   ┌────────────────────────┴────────────────────────┐
   │  Phase 3: TestFlight 内部 build（你+我，<5 人）  │
   │  Phase 2: Maestro 全套 (sim, alphabetical)      │
   │  Phase 1: 后端契约 (Hurl + pytest) + 部署        │
   │  Phase 0: 静态 (单测 + lint + archive 跑通)      │
   └─────────────────────────────────────────────────┘
```

上一层有 critical 就别进下一层。

---

## 四、阶段化执行

### Phase 0 — 静态检查（30 min · 自动化）

| 检查 | 命令 | 通过标准 |
|---|---|---|
| Swift 单测 | `make test` | 156 测试全绿，运行时 < 2s |
| Backend 单测 | `make test-backend` | 全绿 |
| Hurl 契约 | `make e2e-api` | 全绿 |
| iOS sim build | `make build-app` | 编译过，无 warning |
| iOS sim 测试 | `make test-ios` | 全绿 |
| **iOS archive 跑通** | `make archive` | IPA 生成成功（AMap 切换正常） |
| precommit 整体 | `make precommit` | ~5s 全绿 |

**Gate**：全绿才进 Phase 1。任何一个红的，先修。

---

### Phase 1 — 后端部署 + 契约保护（1h）

**目的**：保证后端先稳定，再发 iOS 客户端。后端是 `git pull-only`，
不能让客户端先跑到服务器没准备好的状态。

#### 1.1 部署前 dry-run

```bash
# 本地针对 staging（如有）or 直接对 prod 测试不写入的路径
make e2e-api                 # Hurl 契约
SSHPASS='...' bash ops/install-infra.sh --dry-run   # 看 systemd / nginx 是否需要重启
```

#### 1.2 部署到 server

```bash
ssh ubuntu@82.156.248.135
cd ~/TePlanner && git fetch origin ios-development \
                && git reset --hard origin/ios-development
cd backend && echo y | bash start.sh -d -s
curl -sS https://api.teplanner.cloud/health   # 200
```

#### 1.3 部署后验证

| 测试 | 方法 | 通过标准 |
|---|---|---|
| `/health` | curl | 200 + uptime 重新计时 |
| `/auth/tesla/authorize`(无 user_id) | curl × 1 | 200，**新建 anon user** 并在 server log 看到 warning（确保 log 还在工作） |
| `/auth/tesla/unbind` | curl × 1 | 200（即便 user 不存在也 200 + "Already unbound"） |
| `/automations/capabilities` | curl × 10 并发 | 全 200，content 完全一致（缓存正确） |
| `/automations/` POST 各 trigger | Hurl × 4（state_duration / state_transition / cron / geofence） | 200 + 返回 spec 跟入参 byte-equal |
| `/charging/sessions` GET | curl + 一个有 charging history 的 user_id | 至少 1 行返回 |
| `/vehicles/.../suggest-charge-limit` | curl | 200 + 合理 percent 值 |
| Tesla Fleet Telemetry consumer | `journalctl -u teplanner-backend -f` 看 1 分钟 | 无 `MultipleResultsFound` / `state_writer` 异常 |
| Alembic head | `alembic current` on prod | 无未应用 migration |

**Gate**：上面任意一项失败 → 立即 `git reset --hard <previous>` + 重启回上一版。

---

### Phase 2 — Maestro 全套（30 min · 自动化）

```bash
make e2e-ios   # 10 个 flow，~5 分钟
```

模拟器跑通的 flow（按字母序）：

1. `cross_platform/automations_smoke_ios.yaml`
2. `cross_platform/battery_smoke_ios.yaml`
3. `cross_platform/hub_smoke_ios.yaml`
4. 其他历史 `0*.yaml` 流程

**Gate**：Maestro 全绿 → 进 Phase 3。

> 历史教训：lock screen 后 cliclick 失效，模拟器自动化卡住——
> 重启 Mac。见 `feedback_simulator_lockscreen` 记忆。

---

### Phase 3 — TestFlight 内部 build（2h）

#### 3.1 上传

```bash
make next-build           # bump CURRENT_PROJECT_VERSION
make upload-testflight    # archive → export → altool
```

观察：
- 苹果端处理时间 10–30 分钟
- 处理失败邮件第一时间通知（一般是 Info.plist / Privacy / icon 问题）
- 上线后内部 tester（你 + 1–2 个）应能收到 TestFlight 通知

#### 3.2 内部 tester 手测（critical path · 30 min/人）

按这个顺序：

| # | 路径 | 通过标准 |
|---|---|---|
| 1 | **关闭 build 36 之前的 app**（不卸载）→ 装 build 37 → 启动 | 不闪退；进 Hub 显示老用户名+车辆 |
| 2 | 看「自动化」列表 | 老规则全部还在，启用状态保留 |
| 3 | 看「下次出行」卡片 | 老 schedule（如有）还在 |
| 4 | 看「充电管理」→「充电历史」 | 老 session 数据从后端拉回，展示一致 |
| 5 | 看 Hub 「充电限额建议」卡片（如有触发条件） | 数值合理 |
| 6 | 「自动化」→ 任一规则 → 启用关闭 | 状态保存 |
| 7 | 「自动化」→「+」→ 新建 state_duration 规则 → 保存 | 列表里出现 |
| 8 | 退出登录 → 重新 Tesla OAuth | 重定向 + 回到 Hub |
| 9 | Hub 菜单 → 解绑 Tesla 账户 → 确认 | 跳回登录页 |

**Gate**：critical path 9/9 过 → 进 Phase 4。

---

### Phase 4 — 端到端回归 + 升级路径（2h · 我 + 你）

**升级路径专项**（关键，因为 D.3/4/5 改了数据来源）：

| 测试 | 方法 | 通过标准 |
|---|---|---|
| 老 schedule 数据 | iOS 模拟器装 build 36 → 设一个出行计划 → 升级到 build 37 → 看 Hub | 出行计划数据完整迁移到后端，UI 显示一致 |
| 老 charging session | build 36 跑过几次充电 → 升 build 37 → 「充电历史」 | 列表完整，时间戳一致 |
| 老 charge-limit suggestion | build 36 显示的建议数值 → build 37 显示 | 建议算法一致（后端 port 实现） |
| 老 rule snooze | build 36 给某规则 snooze 1h → 升级 → 列表 | snooze 状态保留 |
| 老 token | build 36 已登录 → 升级 → 启动 | 不需重登（除非 token 过期） |

**全功能回归**：

| 测试 | 通过标准 |
|---|---|
| 推送通知 | 触发任一规则 → 收 APNs 推送 |
| 点推送 action button | 后端 VCP 命令真执行（小心：会扣 Tesla API quota） |
| 充电规划 | 起点北京 → 终点上海 → 沿途充电站合理 |
| 地理围栏 picker | 拖动地图选点 → 半径滑块 → 「使用此位置」回填 |
| 自定义 cron 规则 | 每日 7:30 → 保存 → 第二天 7:30 真触发 |

**Gate**：所有上面 + 没有 critical bug → 进真车 E2E。

---

### Phase 5 — 真车 E2E（2h · 必须你在车边）

**必备**：黑胖子 + iPhone + 4G 网络 + 后端 OK。

| 场景 | 步骤 | 通过标准 |
|---|---|---|
| **VCP 配对**（如未配） | Hub 弹「立即配对」→ 跳 Tesla App → 授权完成 | partner key 写入；回到 Hub 不再弹提示 |
| **关闭露营** | 车开露营模式 → 等到规则的 for_minutes → 收推送 → 点 Hub「露营模式」chip → 关闭 | 30s 内车端真关闭；Hub 卡片显示 ✓ 已确认 |
| **充电完成提醒** | 充电插上 → 等到 100% → 应收推送 | 推送来了，时间准 |
| **进出地理围栏** | 在车上自建「家 200m」geofence → 开车出去 50m → 应推送「离开」| 推送来，coord 不偏（验证 GCJ-02 转换） |
| **下次出行预热** | 设置明早 8 点 + lead 15min → 凌晨 7:45 应触发 | 车端 7:45 开始预热（提前 / 推后 ≤ 1 min） |
| **充电限额智能建议** | 改 daily 限额 50% → Hub 卡片应建议调整 → 应用 → 车端真改 | 数值合理，车端反映 |

**Gate**：6/6 通过 → 上 TestFlight 公开 beta。

---

### Phase 6 — TestFlight 公开 beta（24–48h soak）

| 任务 | 标准 |
|---|---|
| 招 10–20 个 TestFlight tester（家人 + 同事 + 圈友） | 都升级到 build 37 |
| **加 Sentry / Crashlytics** 如果还没装 | 必须能 24h 收到崩溃通知 |
| 监控看板 | 后端 `/health`、`/automations` p95 延迟、APNs 投递率 |
| 真用户用 24h | 收集所有 push、错误、卡顿 |
| Daily review | 每天看 `pushed_alerts` 表 + server logs |

**Gate**：
- 0 critical（崩溃 / 数据丢失 / 推送漏发）
- ≤ 3 medium（功能可用但不对）
- 内测用户人均 ≥ 1 条自动化在工作

通过 → 上线。

---

### Phase 7 — App Store 正式上线（gated rollout）

| 阶段 | 比例 | 时长 |
|---|---|---|
| App Store 灰度 | 1% → 10% → 50% → 100% | 每档观察 24h |
| **Kill switch**：远程 feature flag 关键功能开关 | 必须先备好 | （**今天先做** — 没有就上线很危险） |
| App Store 审核回归 | 一般 24–72h | iOS 审核需要演示账号（不能要真车） |

---

## 五、上线前 checklist

### 必做（缺一不可）

- [ ] `make precommit` 全绿
- [ ] `make e2e-ios` Maestro 全绿
- [ ] **TestFlight build 37 上传成功**
- [ ] **内部 tester 9/9 critical path 跑通**
- [ ] **升级路径**：build 36 → 37 老数据完整迁移
- [ ] **真车 E2E**：6 个场景全过
- [ ] **AMap key 检查**：iOS SDK key + Web Service key 没过期，配额充足
- [ ] **Tesla Fleet API partner key** 未过期（每 90 天）
- [ ] **APNs 证书** 未过期（每 1 年）
- [ ] **服务器监控**：CPU / 内存 / 磁盘有告警通道
- [ ] **DB 备份**：上线前 1h 做一次全量
- [ ] **Rollback 演练**：能在 5 分钟内回滚 backend + 上一个 TestFlight build

### 强烈建议

- [ ] 隐私政策 / 用户协议链接在登录页前展示（App Store 上架要求）
- [ ] 加 Sentry / 类似崩溃收集
- [ ] 埋点：登录成功率 / 规则保存成功率 / 推送投递率
- [ ] kill switch：feature flag 能远程关闭 RuleBuilder / OAuth / VCP 任一模块
- [ ] 客服入口：用户能联系到你（邮箱、群、TestFlight 反馈）
- [ ] App Store 元信息：截图（中文 + 英文）、关键词、描述
- [ ] App Store 演示账号（审核员看不了真车，需要 mock）

### 上线后必盯（第一周）

- 崩溃率（按 iOS 版本 / 设备型号）
- 推送投递率
- `/auth/tesla/authorize` 调用频次（突增 = anon user 漏修）
- `/automations` POST 失败率
- VCP 命令成功率（pending → confirmed 转化）
- DB 增长曲线（catch leak）
- App Store 评论 / TestFlight 反馈

---

## 六、Rollback 计划（必须演练一次）

### Backend rollback（5 分钟）

```bash
ssh ubuntu@82.156.248.135
cd ~/TePlanner

# 记录当前 commit，回上一个稳定版本
git log --oneline -5   # 找到上一个稳定 commit
git reset --hard <stable-sha>

cd backend && echo y | bash start.sh -d -s
curl -sS https://api.teplanner.cloud/health
```

### iOS rollback

App Store 不能"下线"已发布版本。可选：

1. **TestFlight phase**：直接 expire build 37，让 tester 退回 36
2. **App Store phase**：紧急提交一个回滚 build，标记 "Critical bug fix"，
   苹果通常 < 24h 加急审核
3. **Kill switch**（推荐先做）：通过 server-controlled feature flag 关闭
   导致 bug 的功能（如 RuleBuilder），iOS 端检测到 flag 后隐藏入口

### DB rollback

> 风险高，谨慎使用。

```bash
# 必须有上线前的备份
sudo systemctl stop teplanner-backend
psql -d teplanner < /path/to/pre-launch-backup.sql
sudo systemctl start teplanner-backend
```

---

## 七、坦白接受的风险（不阻止上线）

| 风险 | 为什么先不修 |
|---|---|
| HarmonyOS / Android 还没上线 | 单独发版 |
| 离线场景体验 | App 设计上就要求联网 |
| 充电规划在偏远地区 POI 稀疏 | AMap 数据问题 |
| 多语言（只支持简中） | 海外市场 v2 |
| Apple Watch / iPad 适配 | v2 |
| 极端 cron（如 `*/15 * * * *`） | 当前 builder 只支持 `M H * * W` |

---

## 八、建议的执行节奏

| 时间 | 内容 | 关键产出 |
|---|---|---|
| Day 1 上午 | Phase 0 + Phase 1 | 静态 + backend 稳定 |
| Day 1 下午 | Phase 2 + Phase 3 | Maestro 绿 + TestFlight build 37 上传 |
| Day 2 | Phase 4 升级路径 + 全功能回归 | 老数据迁移确认 |
| Day 3 上午 | Phase 5 真车 E2E | 6/6 场景过 |
| Day 3 下午 | 发起 Phase 6 公开 beta | 招 tester |
| Day 4–5 | 内测 soak + bug 修 | 0 critical |
| Day 6 | 上 App Store 灰度 1% | 24h 观察 |
| Day 7+ | 灰度 10% → 50% → 100% | 每档 24h |

**约 1 周，5 个 gate**，每个 gate 不过就停在那等修。

---

## 九、Maestro selector 速查（运行时调试用）

| 元素 | accessibilityIdentifier |
|---|---|
| 登录按钮 | `login_button` |
| Hub 状态卡 | `hub_status_card` |
| Hub 菜单 | `hub_menu_button` |
| Hub 入口卡 | `hub_entry_planning` / `hub_entry_automations` / `hub_entry_battery` |
| Hub 出行卡 | `hub_departure_card` |
| Hub 限额卡 | `hub_charge_limit_card` |
| 搜索 | `home_search_button` / `search_field` / `search_result_<n>` |
| 自动化 | `automations_save_button` / `automation_toggle_<kind>` / `automation_slider_<kind>` |
| 电池管理 | `battery_view` / `charging_stats_view` / `manual_charge_limit_slider` |
| 充电规划 | `map_menu_button` / `recenter_button` / `nearby_filter_<type>` / `nearby_charger_<n>` |
| 站点详情 | `station_plan_route_button` / `station_open_in_amap_button` |

完整列表见 `CLAUDE.md` 「Stable Maestro selectors」一节。
