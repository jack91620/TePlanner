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
SERVER_LOG="/home/ubuntu/TePlanner/backend/server.log"
HEALTH_URL="https://api.teplanner.cloud/health"

mkdir -p "$SNAP_DIR"
TS_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TS_FILE="$(date -u +%Y%m%dT%H%M%SZ)"

log_event() {
    local kind="$1"; shift
    echo "$TS_ISO $kind $*" >> "$INC_LOG"
}

# --- 1. health probe ----------------------------------------------------------
HEALTH_HTTP="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$HEALTH_URL" || echo "000")"
HEALTH_OK="false"
[ "$HEALTH_HTTP" = "200" ] && HEALTH_OK="true"

# --- 2. uvicorn alive ---------------------------------------------------------
UVICORN_PID="$(pgrep -f 'uvicorn app.main' | head -1 || true)"
UVICORN_ALIVE="false"
[ -n "$UVICORN_PID" ] && UVICORN_ALIVE="true"

# --- 3. polling tick recency --------------------------------------------------
POLLING_FRESH="unknown"
if [ -f "$SERVER_LOG" ]; then
    LAST_TICK_LINE="$(grep 'polling tick complete' "$SERVER_LOG" | tail -1 || true)"
    if [ -n "$LAST_TICK_LINE" ]; then
        # Two log formats coexist depending on whether structlog is
        # wired this boot:
        #   JSON: {"event":"polling tick complete","timestamp":"2026-05-08T05:25:04.596542Z",...}
        #   Plain: 2026-05-08 02:32:50 - INFO - app.services.polling - polling tick complete: ...
        # Try JSON first; on parse failure fall back to extracting the
        # leading "YYYY-MM-DD HH:MM:SS" prefix.
        LAST_TICK_TS="$(echo "$LAST_TICK_LINE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('timestamp',''))" 2>/dev/null || true)"
        if [ -z "$LAST_TICK_TS" ]; then
            LAST_TICK_TS="$(echo "$LAST_TICK_LINE" | awk '{print $1" "$2}')"
        fi
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
else
    AGE_S=99999
fi

# --- 4. error count last 5 min ------------------------------------------------
ERROR_COUNT=0
if [ -f "$SERVER_LOG" ]; then
    # Local-time prefix; matches backend logger's asctime format.
    SINCE="$(date -d '5 minutes ago' +%Y-%m-%dT%H:%M)"
    # Grep ERROR lines that are recent enough; fall back to last-N if no recent
    ERROR_COUNT="$(awk -v since="$SINCE" '
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
    cd /home/ubuntu/TePlanner/backend && yes y | bash start.sh -d -s >> "$INC_LOG" 2>&1 || true
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
