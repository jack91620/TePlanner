#!/bin/bash
#
# 模拟运维告警全链路测试: 错误事件 → watchdog 检测 → 修复 → 微信通知
#
# 用法:
#   bash ops/simulate-alert.sh [scenario]
#
# Scenarios:
#   polling_frozen  (default) — 伪造 polling 冻结，触发重启 + 微信告警
#   backend_dead              — 临时停掉 uvicorn 让 watchdog 检测到宕机
#   error_spike               — 往 server.log 注入 ERROR 行触发错误激增告警
#
set -uo pipefail

OPS_HOME="${OPS_HOME:-/home/ubuntu/ops}"
STATE_DIR="$OPS_HOME/state"
SERVER_LOG="/home/ubuntu/TePlanner/backend/server.log"
SCENARIO="${1:-polling_frozen}"
SIM_TAG="[SIMULATE:$SCENARIO]"

log() { echo "$(date '+%H:%M:%S') $*"; }

notify_wechat() {
    openclaw message send \
        --channel openclaw-weixin \
        --account 1d60484c0baa-im-bot \
        --target "o9cq8048r-As7icF_Ty1Q2INOYe0@im.wechat" \
        --message "$1" \
        --json >/dev/null 2>&1 || true
}

cleanup() {
    log "清理模拟环境..."
    if [ -n "${BACKUP_LOG:-}" ] && [ -f "$BACKUP_LOG" ]; then
        mv "$BACKUP_LOG" "$SERVER_LOG"
        log "server.log 已还原"
    fi
    if [ -n "${UVICORN_WAS_KILLED:-}" ]; then
        log "重新启动后端..."
        cd /home/ubuntu/TePlanner/backend && yes y | bash start.sh -d -s >/dev/null 2>&1
        log "后端已恢复"
    fi
}
trap cleanup EXIT

# ── scenario setup ────────────────────────────────────────────────────────────

case "$SCENARIO" in

polling_frozen)
    log "场景: polling_frozen — 伪造 server.log 中最后一次 tick 时间为 20 分钟前"
    BACKUP_LOG="${SERVER_LOG}.sim-backup"
    cp "$SERVER_LOG" "$BACKUP_LOG" 2>/dev/null || true

    # 写一条 20 分钟前的 tick 行（JSON 格式）
    FAKE_TS="$(date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%S.000000Z)"
    FAKE_LINE="{\"event\":\"polling tick complete\",\"timestamp\":\"$FAKE_TS\",\"user_count\":3}"

    # 把现有 log 里所有 tick complete 行替换为旧时间戳，让 watchdog 以为 polling 冻结
    grep -v 'polling tick complete' "$SERVER_LOG" > "${SERVER_LOG}.tmp" 2>/dev/null || true
    echo "$FAKE_LINE" >> "${SERVER_LOG}.tmp"
    mv "${SERVER_LOG}.tmp" "$SERVER_LOG"

    log "注入旧 tick 行完成: $FAKE_TS"
    notify_wechat "🧪 $SIM_TAG 开始: 已将 polling 最后 tick 时间伪造为 20 分钟前，等待 watchdog 运行..."
    ;;

backend_dead)
    log "场景: backend_dead — 暂停 uvicorn 进程"
    UVICORN_PID="$(pgrep -f 'uvicorn app.main' | head -1 || true)"
    if [ -z "$UVICORN_PID" ]; then
        log "警告: uvicorn 本来就没在跑，跳过 kill"
    else
        kill -STOP "$UVICORN_PID"
        UVICORN_WAS_KILLED=1
        log "uvicorn PID=$UVICORN_PID 已暂停 (SIGSTOP)"
    fi
    notify_wechat "🧪 $SIM_TAG 开始: 已暂停 uvicorn 进程，模拟后端宕机，等待 watchdog..."
    ;;

error_spike)
    log "场景: error_spike — 注入 15 条 ERROR 日志行"
    BACKUP_LOG="${SERVER_LOG}.sim-backup"
    cp "$SERVER_LOG" "$BACKUP_LOG" 2>/dev/null || true
    NOW_TS="$(date -u +%Y-%m-%dT%H:%M)"
    for i in $(seq 1 15); do
        echo "{\"level\":\"ERROR\",\"timestamp\":\"${NOW_TS}:$(printf '%02d' $i)Z\",\"event\":\"[SIM] simulated error event #$i\"}" >> "$SERVER_LOG"
    done
    log "注入 15 条 ERROR 行完成"
    notify_wechat "🧪 $SIM_TAG 开始: 已注入 15 条 ERROR 日志行，模拟错误激增，等待 watchdog..."
    ;;

*)
    echo "未知 scenario: $SCENARIO"
    echo "可用: polling_frozen | backend_dead | error_spike"
    exit 1
    ;;
esac

# ── run watchdog ──────────────────────────────────────────────────────────────

log "运行 server-monitor.sh (watchdog)..."
bash /home/ubuntu/ops/server-monitor.sh
EXIT_CODE=$?

log "watchdog 返回码: $EXIT_CODE"

# ── report ────────────────────────────────────────────────────────────────────

log "最近 incidents.log 条目:"
tail -10 "$STATE_DIR/incidents.log" | sed 's/^/  /'

SNAP="$(cat "$STATE_DIR/snapshot.json" 2>/dev/null || echo '{}')"
log "当前快照:"
echo "$SNAP" | python3 -m json.tool 2>/dev/null | grep -E "pollingFresh|pollingAge|healthOk|uvicorn|errors5m" | sed 's/^/  /'

notify_wechat "✅ $SIM_TAG 测试完成 — watchdog 已执行，详情见 incidents.log"

log "模拟测试完成。"
