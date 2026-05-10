#!/bin/bash
#
# Always-on watchdog for the TePlanner backend on the Tencent VM.
# Cron-fires every 5 minutes. Pure bash + jq; no LLM.
#
# What it checks each tick:
#   1. https://api.teplanner.cloud/health → 200
#   2. uvicorn process alive (pgrep)
#   3. polling loop ticked recently (server.log)
#   4. disk usage
#   5. ERROR-level log line count over the last 5 min
#
# What it auto-fixes:
#   - Backend dead → start.sh -d -s. Tracked rate-limit: max 3/hour.
#   - Polling frozen > 15 min → restart backend. Max 1/hour.
#   - Disk > 90% → vacuum journal + gzip old server.log. Once per day.
#
# Outputs:
#   ~/ops/state/snapshot.json         most recent snapshot
#   ~/ops/state/snapshots/<ts>.json   historical (7 days kept)
#   ~/ops/state/incidents.log         append-only event log
#   ~/ops/state/restart-counter       hourly restart count

set -uo pipefail

OPS_HOME="${OPS_HOME:-/home/ubuntu/ops}"
STATE_DIR="$OPS_HOME/state"
SNAP_DIR="$STATE_DIR/snapshots"
INC_LOG="$STATE_DIR/incidents.log"
RESTART_COUNTER="$STATE_DIR/restart-counter"
ALERT_DEDUP_FILE="$STATE_DIR/alert-dedup.tsv"
SERVER_LOG="/home/ubuntu/TePlanner/backend/server.log"
HEALTH_URL="https://api.teplanner.cloud/health"

# Load webhook credentials from alert.env (missing file = local log only)
ALERT_ENV_FILE="${ALERT_ENV_FILE:-/home/ubuntu/ops/alert.env}"
if [ -f "$ALERT_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ALERT_ENV_FILE"
fi
OPENCLAW_HOOK_URL="${OPENCLAW_HOOK_URL:-}"
OPENCLAW_HOOK_TOKEN="${OPENCLAW_HOOK_TOKEN:-}"
ALERT_DEDUP_WINDOW_S="${ALERT_DEDUP_WINDOW_S:-3600}"

mkdir -p "$SNAP_DIR"
TS_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_FILE="$(date -u +%Y%m%dT%H%M%SZ)"

# Send alert to OpenClaw /hooks/agent → WeChat direct delivery.
# Per-signature 1h dedup prevents flooding. Best-effort: silently skipped
# when webhook env is unset or gateway is unreachable.
notify_alert() {
    local signature="$1"; shift
    local text="$*"
    [ -z "$OPENCLAW_HOOK_URL" ] && return 0
    [ -z "$OPENCLAW_HOOK_TOKEN" ] && return 0

    local now cutoff last
    now="$(date -u +%s)"
    cutoff=$((now - ALERT_DEDUP_WINDOW_S))
    if [ -f "$ALERT_DEDUP_FILE" ]; then
        last="$(awk -F'\t' -v sig="$signature" '$1==sig {print $2}' "$ALERT_DEDUP_FILE" | tail -1)"
        if [ -n "$last" ] && [ "$last" -ge "$cutoff" ]; then
            return 0
        fi
    fi

    # Update dedup file atomically
    {
        if [ -f "$ALERT_DEDUP_FILE" ]; then
            awk -F'\t' -v cutoff="$cutoff" -v sig="$signature" \
                '$1!=sig && $2>=cutoff' "$ALERT_DEDUP_FILE"
        fi
        printf '%s\t%s\n' "$signature" "$now"
    } > "$ALERT_DEDUP_FILE.tmp" && mv "$ALERT_DEDUP_FILE.tmp" "$ALERT_DEDUP_FILE"

    local payload
    payload="$(jq -n \
        --arg m "[teplanner-monitor] $text" \
        '{message:$m, name:"teplanner-alert", deliver:true, channel:"openclaw-weixin", to:"o9cq8048r-As7icF_Ty1Q2INOYe0@im.wechat"}')"
    curl -s -m 4 -o /dev/null \
        -X POST "$OPENCLAW_HOOK_URL/agent" \
        -H "Authorization: Bearer $OPENCLAW_HOOK_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" || true
}

log_event() {
    local kind="$1"; shift
    local body="$*"
    echo "$TS_ISO $kind $body" >> "$INC_LOG"
    if [ "$kind" = "ALERT" ]; then
        # Normalize numbers in signature to avoid "99999s" vs "100000s" mismatches
        local sig
        sig="$(echo "$body" | sed -E 's/[0-9]+/N/g' | cut -c1-60)"
        notify_alert "$sig" "$body"
    fi
}

# --- 1. health probe ----------------------------------------------------------
HEALTH_HTTP="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$HEALTH_URL" || echo "000")"
HEALTH_OK="false"
[ "$HEALTH_HTTP" = "200" ] && HEALTH_OK="true"

# --- 2. uvicorn alive ---------------------------------------------------------
UVICORN_PID="$(pgrep -f 'uvicorn app.main' | head -1 || true)"
UVICORN_ALIVE="false"
[ -n "$UVICORN_PID" ] && UVICORN_ALIVE="true"

# --- 3. polling / cron tick recency ------------------------------------------
# Backend runs under systemd (StandardOutput=journal) so server.log is no
# longer being written. Source of truth is now journald. Match both old
# `polling tick complete` and new `cron tick complete` event names so this
# works across rolled-forward and rolled-back deploys.
# History: pre-systemd this read server.log; that path produced ~17 false
# `polling frozen` restarts in 24h on 2026-05-10 because server.log mtime
# froze at backend startup. See ops/reports/2026-05-10.md.
POLLING_FRESH="unknown"
LAST_TICK_LINE="$(journalctl -u teplanner-backend --since '20 min ago' --no-pager -o short-iso 2>/dev/null \
    | grep -aE 'cron tick complete|polling tick complete' | tail -1 || true)"
if [ -n "$LAST_TICK_LINE" ]; then
    # short-iso format: 2026-05-10T08:58:22+0800 host service[pid]: ...
    LAST_TICK_TS="$(echo "$LAST_TICK_LINE" | awk '{print $1}')"
    LAST_TICK_EPOCH="$(date -d "$LAST_TICK_TS" +%s 2>/dev/null || echo 0)"
    NOW_EPOCH="$(date +%s)"
    AGE_S=$((NOW_EPOCH - LAST_TICK_EPOCH))
    if [ "$AGE_S" -lt 900 ]; then
        POLLING_FRESH="true"
    else
        POLLING_FRESH="false"
    fi
else
    POLLING_FRESH="false"
    AGE_S=99999
fi

# --- 4. error count last 5 min ------------------------------------------------
ERROR_COUNT=0
if [ -f "$SERVER_LOG" ]; then
    # Local-time prefix; matches backend logger's asctime format.
    SINCE="$(date -d '5 minutes ago' +%Y-%m-%dT%H:%M)"
    # Grep ERROR lines that are recent enough; fall back to last-N if no recent
    # strings(1) strips embedded binary noise so awk reliably sees text.
    ERROR_COUNT="$(strings "$SERVER_LOG" 2>/dev/null | awk -v since="$SINCE" '
        /ERROR/ {
            ts = substr($0, 1, 16)
            gsub(" ", "T", ts)
            if (ts >= since) c++
        }
        END { print c+0 }
    ' "$SERVER_LOG")"
fi

# --- 5. disk -----------------------------------------------------------------
DISK_PCT="$(df / | awk 'NR==2 {gsub("%",""); print $5}')"

# --- write snapshot -----------------------------------------------------------
SNAP_JSON="$(jq -n \
    --arg ts "$TS_ISO" \
    --arg health "$HEALTH_HTTP" \
    --argjson healthOk "$HEALTH_OK" \
    --argjson alive "$UVICORN_ALIVE" \
    --arg pollingFresh "$POLLING_FRESH" \
    --argjson pollingAgeS "$AGE_S" \
    --argjson errors5m "$ERROR_COUNT" \
    --argjson diskPct "$DISK_PCT" \
    '{ts:$ts, healthHttp:$health, healthOk:$healthOk, uvicornAlive:$alive, pollingFresh:$pollingFresh, pollingAgeS:$pollingAgeS, errors5m:$errors5m, diskPct:$diskPct}')"

echo "$SNAP_JSON" > "$STATE_DIR/snapshot.json"
echo "$SNAP_JSON" > "$SNAP_DIR/$TS_FILE.json"

# Trim historical snapshots > 7d
find "$SNAP_DIR" -name '*.json' -mtime +7 -delete 2>/dev/null

# --- decision tree ------------------------------------------------------------

# rate-limit window: keep restart timestamps from last hour in counter file
HOUR_AGO_EPOCH=$(($(date -u +%s) - 3600))
prune_counter() {
    [ -f "$RESTART_COUNTER" ] || return 0
    awk -v cutoff="$HOUR_AGO_EPOCH" '$1 >= cutoff' "$RESTART_COUNTER" > "$RESTART_COUNTER.tmp" \
        && mv "$RESTART_COUNTER.tmp" "$RESTART_COUNTER"
}
recent_restart_count() {
    [ -f "$RESTART_COUNTER" ] || { echo 0; return; }
    wc -l < "$RESTART_COUNTER"
}
record_restart() {
    echo "$(date -u +%s) $1" >> "$RESTART_COUNTER"
}

prune_counter
RESTARTS_THIS_HOUR="$(recent_restart_count)"

restart_backend() {
    local reason="$1"
    if [ "$RESTARTS_THIS_HOUR" -ge 3 ]; then
        log_event ALERT "restart suppressed (already $RESTARTS_THIS_HOUR this hour) — reason was: $reason"
        return 1
    fi
    log_event ACTION "restarting backend: $reason"
    sudo systemctl restart teplanner-backend >> "$INC_LOG" 2>&1 || true
    record_restart "$reason"
    return 0
}

# Backend dead?
if ! $HEALTH_OK || ! $UVICORN_ALIVE; then
    log_event ALERT "health=$HEALTH_HTTP uvicorn=$UVICORN_ALIVE — backend dead"
    restart_backend "backend down"
fi

# Polling frozen?
if [ "$POLLING_FRESH" = "false" ] && $UVICORN_ALIVE && $HEALTH_OK; then
    log_event ALERT "polling stale (last tick ${AGE_S}s ago) but backend up"
    # Only restart if we haven't already in last hour
    if [ "$RESTARTS_THIS_HOUR" -lt 1 ]; then
        restart_backend "polling frozen"
    fi
fi

# Disk pressure?
if [ "$DISK_PCT" -gt 90 ]; then
    log_event ALERT "disk usage ${DISK_PCT}%"
    LAST_VACUUM_FILE="$STATE_DIR/last-vacuum"
    DO_VACUUM="true"
    if [ -f "$LAST_VACUUM_FILE" ]; then
        LAST_VACUUM_EPOCH="$(cat "$LAST_VACUUM_FILE")"
        NOW_EPOCH="$(date -u +%s)"
        if [ $((NOW_EPOCH - LAST_VACUUM_EPOCH)) -lt 86400 ]; then
            DO_VACUUM="false"
        fi
    fi
    if $DO_VACUUM; then
        log_event ACTION "vacuuming journal + old logs"
        sudo journalctl --vacuum-size=200M >> "$INC_LOG" 2>&1 || true
        find /home/ubuntu/TePlanner/backend -name 'server.log.*' -mtime +7 -delete 2>/dev/null
        date -u +%s > "$LAST_VACUUM_FILE"
    fi
fi

# Error spike (informational only)
if [ "$ERROR_COUNT" -gt 10 ]; then
    log_event ALERT "error spike: $ERROR_COUNT ERROR lines in last 5min"
fi

exit 0
