"""Fleet Telemetry ingestion (Phase 4).

Subscribes to fleet-telemetry's ZMQ output, decodes Tesla's enum
strings into our snapshot value types, and writes per-entity `since`
timestamps into AutomationState. Interpreters then prefer those true
"started at" times over polling-observation times so push notifications
say "已开启 1 小时 30 分钟" instead of "已开启 0 分钟".
"""
