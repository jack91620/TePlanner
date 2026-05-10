#!/bin/bash
# TePlanner 每日运维巡检 — 纯脚本，无 LLM 依赖。
# 由 system cron 每天 8:03 (Asia/Shanghai) 触发。
#
# 流程（顺序执行，任何一步失败都会被 set -uo pipefail 暴露）：
#   1. 采集指标 → 内存变量
#   2. 写报告到 /home/ubuntu/TePlanner/ops/reports/<date>.md
#   3. 更新 HEARTBEAT.md：把待办项幂等追加（已存在标题不重复）
#   4. 发微信摘要（沿用 server-monitor.sh 同款 webhook）
#
# 故障模式：任何步骤失败都仍然会尝试发微信告警，不静默退出。

set -uo pipefail

OPS_HOME="${OPS_HOME:-/home/ubuntu/ops}"
ALERT_ENV_FILE="${ALERT_ENV_FILE:-$OPS_HOME/alert.env}"
[ -f "$ALERT_ENV_FILE" ] && . "$ALERT_ENV_FILE"

DATE="$(TZ='Asia/Shanghai' date +%Y-%m-%d)"
TS_ISO="$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S %Z')"
REPORT_DIR="/home/ubuntu/TePlanner/ops/reports"
REPORT="$REPORT_DIR/$DATE.md"
HEARTBEAT="/home/ubuntu/.openclaw/workspace/HEARTBEAT.md"
SNAPSHOT="$OPS_HOME/state/snapshot.json"
INCIDENTS="$OPS_HOME/state/incidents.log"
SERVER_LOG="/home/ubuntu/TePlanner/backend/server.log"
DB_FILE="/home/ubuntu/TePlanner/backend/teplanner.db"
HEALTH_URL="https://api.teplanner.cloud/health"

mkdir -p "$REPORT_DIR"

# Send WeChat message via OpenClaw webhook (same path as server-monitor.sh).
send_wechat() {
    local text="$1"
    [ -z "${OPENCLAW_HOOK_URL:-}" ] && return 0
    [ -z "${OPENCLAW_HOOK_TOKEN:-}" ] && return 0
    local payload
    payload="$(jq -n --arg m "$text" \
        '{message:$m, name:"teplanner-daily", deliver:true, channel:"openclaw-weixin", to:"o9cq8048r-As7icF_Ty1Q2INOYe0@im.wechat"}')"
    curl -sS -m 8 -o /dev/null \
        -X POST "$OPENCLAW_HOOK_URL/agent" \
        -H "Authorization: Bearer $OPENCLAW_HOOK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" || true
}

# ───────── 1. 采集指标 ─────────

# 健康
HEALTH_HTTP="$(curl -sS -o /dev/null -m 5 -w '%{http_code}' "$HEALTH_URL" 2>/dev/null || echo "000")"

# 快照（最近一次 watchdog 写入；可能不存在）
if [ -f "$SNAPSHOT" ]; then
    SNAP_AGE_S=$(( $(date +%s) - $(stat -c %Y "$SNAPSHOT") ))
    POLLING_FRESH=$(jq -r '.pollingFresh // "unknown"' "$SNAPSHOT")
    POLLING_AGE_S=$(jq -r '.pollingAgeS // "?"' "$SNAPSHOT")
    ERRORS_5M=$(jq -r '.errors5m // 0' "$SNAPSHOT")
    DISK_PCT=$(jq -r '.diskPct // 0' "$SNAPSHOT")
    UVICORN_ALIVE=$(jq -r '.uvicornAlive // false' "$SNAPSHOT")
else
    SNAP_AGE_S=99999
    POLLING_FRESH="unknown"
    POLLING_AGE_S="?"
    ERRORS_5M=0
    DISK_PCT=0
    UVICORN_ALIVE="false"
fi

# 内存
MEM_USED=$(free -m | awk 'NR==2 {print $3}')
MEM_TOTAL=$(free -m | awk 'NR==2 {print $2}')

# 24h 事件统计（incidents.log，按 kind 计数）
if [ -f "$INCIDENTS" ]; then
    CUTOFF_S=$(date -u -d '24 hours ago' +%s)
    ALERT_COUNT=$(awk -v c="$CUTOFF_S" '
        { ts=$1; gsub("T"," ",ts); gsub("Z","",ts);
          cmd="date -u -d \"" ts "\" +%s 2>/dev/null"; cmd | getline e; close(cmd);
          if (e+0 >= c+0 && $2=="ALERT") n++ }
        END { print n+0 }' "$INCIDENTS")
    ACTION_COUNT=$(awk -v c="$CUTOFF_S" '
        { ts=$1; gsub("T"," ",ts); gsub("Z","",ts);
          cmd="date -u -d \"" ts "\" +%s 2>/dev/null"; cmd | getline e; close(cmd);
          if (e+0 >= c+0 && $2=="ACTION") n++ }
        END { print n+0 }' "$INCIDENTS")
    LAST_INCIDENT=$(tail -1 "$INCIDENTS" 2>/dev/null | cut -c1-120)
else
    ALERT_COUNT=0
    ACTION_COUNT=0
    LAST_INCIDENT="(无 incidents.log)"
fi

# server.log 24h ERROR 计数（粗略：按行）
if [ -f "$SERVER_LOG" ]; then
    SINCE_LOCAL="$(date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S')"
    SERVER_ERR_24H=$(strings "$SERVER_LOG" 2>/dev/null | awk -v s="$SINCE_LOCAL" '
        /ERROR/ { ts=substr($0,1,19); if (ts >= s) n++ }
        END { print n+0 }')
    SERVER_LOG_SIZE=$(du -h "$SERVER_LOG" | awk '{print $1}')
else
    SERVER_ERR_24H=0
    SERVER_LOG_SIZE="0"
fi

# DB 大小
if [ -f "$DB_FILE" ]; then
    DB_SIZE_BYTES=$(stat -c %s "$DB_FILE")
    DB_SIZE_HUMAN=$(du -h "$DB_FILE" | awk '{print $1}')
else
    DB_SIZE_BYTES=0
    DB_SIZE_HUMAN="?"
fi

# TLS 剩余天数
TLS_END=$(echo | timeout 6 openssl s_client -connect api.teplanner.cloud:443 -servername api.teplanner.cloud 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$TLS_END" ]; then
    TLS_END_S=$(date -d "$TLS_END" +%s 2>/dev/null || echo 0)
    TLS_DAYS=$(( (TLS_END_S - $(date +%s)) / 86400 ))
else
    TLS_DAYS=-1
fi

# 系统包可升级数
APT_UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -v "^Listing" | wc -l)

# pip outdated（仅计数，不展开列表，避免慢）
PIP_OUTDATED=$(timeout 30 bash -c 'cd /home/ubuntu/TePlanner/backend && /home/ubuntu/miniconda3/envs/teplanner/bin/pip list --outdated 2>/dev/null' | tail -n +3 | wc -l)

# 进程异常（dev-mode reload uvicorn）
RELOAD_UVICORN_PIDS=$(pgrep -af 'uvicorn.*--reload' 2>/dev/null | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
UVICORN_INSTANCES=$(pgrep -f 'uvicorn app.main' 2>/dev/null | wc -l)

# journal 体积
JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | awk -F': ' '{print $2}' | head -1)

# ───────── 2. 决策状态 ─────────

STATUS="green"
STATUS_REASON=""

if [ "$HEALTH_HTTP" != "200" ]; then
    STATUS="red"; STATUS_REASON="health=$HEALTH_HTTP"
elif [ "$UVICORN_ALIVE" != "true" ]; then
    STATUS="red"; STATUS_REASON="uvicorn dead"
elif [ "$ACTION_COUNT" -gt 5 ] 2>/dev/null; then
    STATUS="yellow"; STATUS_REASON="24h watchdog 重启 $ACTION_COUNT 次"
elif [ "$SERVER_ERR_24H" -gt 50 ] 2>/dev/null; then
    STATUS="yellow"; STATUS_REASON="24h ERROR 日志 $SERVER_ERR_24H 行"
elif [ "$DISK_PCT" -gt 80 ] 2>/dev/null; then
    STATUS="yellow"; STATUS_REASON="disk ${DISK_PCT}%"
elif [ "$TLS_DAYS" -lt 14 ] 2>/dev/null && [ "$TLS_DAYS" -ge 0 ]; then
    STATUS="yellow"; STATUS_REASON="TLS 剩余 ${TLS_DAYS} 天"
elif [ -n "$RELOAD_UVICORN_PIDS" ]; then
    STATUS="yellow"; STATUS_REASON="dev-mode --reload uvicorn 仍在跑 (PID $RELOAD_UVICORN_PIDS)"
fi

# ───────── 3. 收集"需关注"和"可优化"项 ─────────

NEEDS_ATTN=()
OPTIMIZE=()

[ "$HEALTH_HTTP" != "200" ] && NEEDS_ATTN+=("后端 /health 返回 $HEALTH_HTTP（应 200）")
[ "$UVICORN_ALIVE" != "true" ] && NEEDS_ATTN+=("uvicorn 进程未存活")
[ "$ACTION_COUNT" -gt 5 ] 2>/dev/null && NEEDS_ATTN+=("24h watchdog 自动重启 $ACTION_COUNT 次—检查根因")
[ "$SERVER_ERR_24H" -gt 50 ] 2>/dev/null && NEEDS_ATTN+=("24h server.log ERROR $SERVER_ERR_24H 行—聚类分析")
[ "$DISK_PCT" -gt 80 ] 2>/dev/null && NEEDS_ATTN+=("磁盘使用 ${DISK_PCT}% 已超 80%")
[ -n "$RELOAD_UVICORN_PIDS" ] && NEEDS_ATTN+=("dev-mode --reload uvicorn 进程残留 PID=$RELOAD_UVICORN_PIDS（应 kill）")
[ "$UVICORN_INSTANCES" -gt 1 ] 2>/dev/null && NEEDS_ATTN+=("uvicorn 实例数=$UVICORN_INSTANCES（多实例可能导致 SQLite 写锁竞争）")

[ "$TLS_DAYS" -lt 30 ] 2>/dev/null && [ "$TLS_DAYS" -ge 14 ] && OPTIMIZE+=("TLS 证书剩余 ${TLS_DAYS} 天—确认 acme.sh 自动续约")
[ "$DB_SIZE_BYTES" -gt 524288000 ] 2>/dev/null && OPTIMIZE+=("SQLite 已 ${DB_SIZE_HUMAN}（>500MB），评估迁 Postgres")
[ "$APT_UPGRADABLE" -gt 20 ] 2>/dev/null && OPTIMIZE+=("系统包可升级 $APT_UPGRADABLE 个，建议 unattended-upgrades")
[ "$PIP_OUTDATED" -gt 10 ] 2>/dev/null && OPTIMIZE+=("Python 依赖过期 $PIP_OUTDATED 个，pip list --outdated 看详情")

# ───────── 4. 写报告 ─────────

{
echo "# TePlanner 每日运维巡检 — $DATE"
echo
echo "巡检时间：$TS_ISO"
echo "状态：$STATUS${STATUS_REASON:+ — $STATUS_REASON}"
echo
echo "## 实时快照"
echo
echo "| 指标 | 值 |"
echo "|---|---|"
echo "| /health | $HEALTH_HTTP |"
echo "| uvicorn alive | $UVICORN_ALIVE |"
echo "| uvicorn 实例数 | $UVICORN_INSTANCES |"
echo "| polling fresh | $POLLING_FRESH (age ${POLLING_AGE_S}s) |"
echo "| 5min ERROR | $ERRORS_5M |"
echo "| 24h ERROR | $SERVER_ERR_24H |"
echo "| disk % | $DISK_PCT |"
echo "| RAM 已用 | ${MEM_USED}M / ${MEM_TOTAL}M |"
echo "| server.log 大小 | $SERVER_LOG_SIZE |"
echo "| journal 占用 | ${JOURNAL_SIZE:-?} |"
echo "| DB 大小 | $DB_SIZE_HUMAN |"
echo "| TLS 剩余天数 | $TLS_DAYS |"
echo "| 系统包可升级 | $APT_UPGRADABLE |"
echo "| pip 过期 | $PIP_OUTDATED |"
echo
echo "快照新鲜度：${SNAP_AGE_S}s 前（watchdog 每 5min 刷新一次，<310s 算新鲜）"
echo
echo "## 24h 事件"
echo
echo "- ALERT: $ALERT_COUNT 条"
echo "- ACTION（自动修复动作）: $ACTION_COUNT 次"
echo "- 最后一条：\`$LAST_INCIDENT\`"
echo
echo "## 需 Jack 关注"
echo
if [ ${#NEEDS_ATTN[@]} -eq 0 ]; then
    echo "无。"
else
    for item in "${NEEDS_ATTN[@]}"; do echo "- $item"; done
fi
echo
echo "## 可优化升级"
echo
if [ ${#OPTIMIZE[@]} -eq 0 ]; then
    echo "无。"
else
    for item in "${OPTIMIZE[@]}"; do echo "- $item"; done
fi
echo
echo "## 数据来源"
echo
echo "- snapshot: \`$SNAPSHOT\` (mtime ${SNAP_AGE_S}s ago)"
echo "- incidents: \`$INCIDENTS\` (24h)"
echo "- server.log: \`$SERVER_LOG\` (24h ERROR grep)"
echo "- 巡检脚本: \`/home/ubuntu/ops/daily-inspection.sh\`"
} > "$REPORT"

# ───────── 5. 更新 HEARTBEAT.md（幂等追加） ─────────

if [ ! -s "$HEARTBEAT" ]; then
    cat > "$HEARTBEAT" <<EOF
# Keep this file empty (or with only comments) to skip heartbeat API calls.
# Tasks added by /home/ubuntu/ops/daily-inspection.sh — Jack handles & deletes.

## 待办

EOF
fi

# 确保有 ## 待办 段
if ! grep -q "^## 待办" "$HEARTBEAT"; then
    printf '\n## 待办\n\n' >> "$HEARTBEAT"
fi

append_heartbeat_task() {
    local title="$1"
    local source="$2"
    # 标题前 30 字符做去重 key
    local key="${title:0:30}"
    if ! grep -qF "$key" "$HEARTBEAT"; then
        echo "- [ ] $title (源: $source)" >> "$HEARTBEAT"
    fi
}

for item in "${NEEDS_ATTN[@]}"; do
    append_heartbeat_task "$item" "ops/reports/$DATE.md"
done
for item in "${OPTIMIZE[@]}"; do
    append_heartbeat_task "[优化] $item" "ops/reports/$DATE.md"
done

# ───────── 6. 发微信摘要 ─────────

NEEDS_LINE="无"
if [ ${#NEEDS_ATTN[@]} -gt 0 ]; then
    NEEDS_LINE=$(printf "%s；" "${NEEDS_ATTN[@]}" | sed 's/；$//')
fi
OPT_LINE=""
if [ ${#OPTIMIZE[@]} -gt 0 ]; then
    OPT_LINE=$(printf "\n可优化：%s" "$(printf "%s；" "${OPTIMIZE[@]}" | sed 's/；$//')")
fi

WECHAT_BODY="【TePlanner 每日巡检】$DATE
状态：$STATUS${STATUS_REASON:+（$STATUS_REASON）}
24h：$ALERT_COUNT 告警 / $ACTION_COUNT 自动修复 / $SERVER_ERR_24H ERROR
需关注：$NEEDS_LINE${OPT_LINE}
报告：ops/reports/$DATE.md"

send_wechat "$WECHAT_BODY"

echo "[$TS_ISO] inspection done: status=$STATUS report=$REPORT" >&2
exit 0
