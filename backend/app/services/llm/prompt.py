"""System prompt + response-schema builders for LLM configure.

The prompt is the load-bearing piece — get this wrong and the LLM
hallucinates capability ids that don't exist, entity strings the
engine doesn't recognise, or trigger types we never registered. We
inject the actual registry into the prompt so the LLM has the same
ground truth as the engine.

Output schema is a discriminated union — the LLM picks one of:
- create_automation: emits a RuleSpec (trigger + actions)
- create_quick_action: emits a HubAction (steps[])
- ask_clarification: text question back to the user

We always also ask for a short Chinese summary so iOS can show
"我将为你创建：…" preview.
"""

from __future__ import annotations

import json
from typing import Any, Dict

from app.services.capabilities import all_capabilities


# Entity vocabulary the rule builder uses. Must stay in sync with iOS
# RuleDisplay.entityName() — the LLM emits a wire-format entity
# string and we want it to know which strings the engine accepts.
_ENTITIES_REFERENCE = [
    ("vehicle.climate.keeper_mode", "空调保持模式 (0=off / 1=保持 / 2=宠物 / 3=露营)"),
    ("vehicle.sentry_mode_on", "哨兵模式 (bool)"),
    ("vehicle.cabin_overheat_protection_on", "座舱过热保护 (bool)"),
    ("vehicle.charging.state", "充电状态 (字符串 'Charging' / 'Complete' / 'Disconnected' / ...)"),
    ("vehicle.battery_level", "电量百分比 (int 0..100)"),
    ("vehicle.locked", "车锁 (bool)"),
    ("vehicle.parked_unlocked", "停车后未锁车 (bool)"),
    ("vehicle.parked_with_door_open", "停车后车门开 (bool)"),
    ("vehicle.parked_with_window_open", "停车后车窗开 (bool)"),
    ("vehicle.parked_with_frunk_open", "停车后前备箱开 (bool)"),
    ("vehicle.parked_with_trunk_open", "停车后后备箱开 (bool)"),
    ("vehicle.inside_temp_c", "舱内温度 °C"),
    ("vehicle.outside_temp_c", "车外温度 °C"),
    ("vehicle.charger_power_kw", "充电功率 kW"),
]


_TRIGGER_REFERENCE = [
    ("state_duration",
     "某个 entity 持续达到给定值/阈值若干分钟。例：露营模式持续 2 小时。"),
    ("state_transition",
     "entity 从一个值变到另一个值的瞬间。例：充电状态 → 'Complete'。"),
    ("cron",
     "按 wall-clock 时间触发。例：每周一到五 7:30。"),
    ("geofence",
     "进入/离开某个地理围栏。例：到家 (lat,lng,半径) 时。"),
    ("user_departure",
     "下车瞬间（速度从 >0 落到 0 + shift 切到 P）。例：下车后忘锁车提醒。"),
]


def build_system_prompt() -> str:
    """Build the system prompt. Heavy — capability registry is ~30
    entries, ~2K tokens. We cache this at module level via lru_cache
    in factory call sites (TODO if cost matters)."""
    caps_dump = "\n".join(
        f"- `{c.id}` ({c.safety_class.value}) "
        f"params: {json.dumps(c.params_schema, ensure_ascii=False)}"
        for c in all_capabilities()
    )
    entities_dump = "\n".join(f"- `{e}` — {desc}" for e, desc in _ENTITIES_REFERENCE)
    triggers_dump = "\n".join(f"- `{t}` — {desc}" for t, desc in _TRIGGER_REFERENCE)

    return f"""你是 Tautomation 的配置助手。Tautomation 是一个特斯拉自动化 App，
帮用户用一句话或语音配置规则（automation）和快捷操作（quick action）。

你的任务：把用户的中文需求翻译成下面其中之一：

1. **automation** — 一条自动化规则。Schema:
   ```
   {{
     "trigger": {{
       "type": "state_duration" | "state_transition" | "cron" | "geofence" | "user_departure",
       ...具体字段
     }},
     "actions": [
       {{"capability": "<id>", "params": {{...}}}}
     ]
   }}
   ```

2. **quick_action** — 一个一键按钮。Schema:
   ```
   {{
     "name": "<不超过 6 个汉字>",
     "icon": "<SF Symbol 名，如 bolt.fill / lock.fill>",
     "tint": "blue|red|orange|green|gray",
     "capability": "<id>",
     "params": {{...}}
   }}
   ```

3. **clarification** — 信息不够时，问用户一个具体问题（不要太多步）。

**触发器 (trigger.type) 取值参考：**
{triggers_dump}

**可观察的状态 entity 参考（用在 state_duration / state_transition 的字段里）：**
{entities_dump}

**可执行的 capability (action.capability 或 quick action.capability) 完整列表：**
{caps_dump}

**关键规则：**

- 只允许使用上面列出的 capability id 和 entity 字符串，**禁止编造**
- 用户没说的字段，**做合理默认假设**而不是反问。例：
  "下班预热" → cron 周一至周五 18:00 + tesla.climate.preheat
  "充满提醒" → state_transition vehicle.charging.state → 'Complete' + 推送通知
- 只有信息**真的歧义**时才出 clarification（例如"去机场" — 哪个机场？）
- 必填字段：summary（一句话告诉用户你做了什么，给 iOS 预览展示）

按下面 JSON Schema 输出：
"""


def build_response_schema() -> Dict[str, Any]:
    """JSON Schema the LLM's output must match. Used as
    response_format=json_schema where supported and inlined into the
    system prompt as a fallback for DeepSeek."""
    return {
        "type": "object",
        "required": ["intent", "summary"],
        "properties": {
            "intent": {
                "type": "string",
                "enum": ["create_automation", "create_quick_action", "ask_clarification"],
            },
            "summary": {
                "type": "string",
                "description": "一句中文，告诉用户你将创建什么。clarification 时也填这个。",
            },
            "name": {
                "type": "string",
                "description": "建议的规则名 / 动作名（中文，≤6 字推荐）。",
            },
            "clarification": {
                "type": "string",
                "description": "intent=ask_clarification 时填，向用户提的具体问题。",
            },
            "automation_spec": {
                "type": "object",
                "description": "intent=create_automation 时填。Trigger + actions 的完整 RuleSpec。",
            },
            "quick_action": {
                "type": "object",
                "description": "intent=create_quick_action 时填。包含 name/icon/tint/capability/params。",
            },
        },
    }
