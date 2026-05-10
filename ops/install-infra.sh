#!/bin/bash
#
# One-shot infra deploy: push every committed config template
# (systemd units, nginx vhost, system cron) to the prod VM and
# reload the matching daemon. Idempotent — diff'd before applying,
# noop if the target file already matches.
#
# Usage:
#   SSHPASS='...' bash ops/install-infra.sh           # apply
#   SSHPASS='...' bash ops/install-infra.sh --dry-run # preview only
#
# What it does NOT do:
#   - Backend code deploy (use git pull + systemctl restart instead)
#   - Watchdog scripts (use ops/install-server-monitor.sh — separate
#     because that one runs a verify tick after install)
#   - Secrets (.env / alert.env / teplanner-keys/) — manual ops, never
#     pushed via this script

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [ -z "${SSHPASS:-}" ]; then
    echo "Set SSHPASS env var first (password auth via sshpass -e)." >&2
    exit 1
fi

REMOTE_HOST="${REMOTE_HOST:-ubuntu@82.156.248.135}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# (local-path, remote-path, post-install hook)
ASSETS=(
    "ops/systemd/teplanner-backend.service|/etc/systemd/system/teplanner-backend.service|systemd|teplanner-backend.service"
    "ops/systemd/tesla-http-proxy.service|/etc/systemd/system/tesla-http-proxy.service|systemd|tesla-http-proxy.service"
    "ops/systemd/fleet-telemetry.service|/etc/systemd/system/fleet-telemetry.service|systemd|fleet-telemetry.service"
    "ops/nginx/teplanner.conf|/etc/nginx/sites-enabled/teplanner|nginx|"
    "ops/cron/teplanner-daily-inspection.cron|/etc/cron.d/teplanner-daily-inspection|cron|"
)

# Track which daemons need reload — only reload once per kind even if
# multiple files of that kind changed.
NEED_SYSTEMD_RELOAD=false
NEED_NGINX_RELOAD=false
NEED_CRON_RELOAD=false
SYSTEMD_TO_RESTART=()

ssh_run() {
    sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_HOST" "$@"
}

scp_run() {
    sshpass -e scp -q -o StrictHostKeyChecking=no "$@"
}

local_sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
remote_sha() {
    ssh_run "sudo -n sha256sum '$1' 2>/dev/null | awk '{print \$1}'"
}

# Phase 1: detect drift
echo "→ scanning for drift"
for asset in "${ASSETS[@]}"; do
    IFS='|' read -r local_path remote_path kind unit_name <<< "$asset"
    abs_local="$ROOT/$local_path"
    if [ ! -f "$abs_local" ]; then
        echo "  ✗ missing local: $local_path" >&2
        exit 1
    fi
    L="$(local_sha "$abs_local")"
    R="$(remote_sha "$remote_path" || true)"
    if [ "$L" = "$R" ]; then
        echo "  ✓ $local_path → $remote_path (in sync)"
    else
        echo "  Δ $local_path → $remote_path (DIFFERS)"
        case "$kind" in
            systemd)
                NEED_SYSTEMD_RELOAD=true
                SYSTEMD_TO_RESTART+=("$unit_name")
                ;;
            nginx) NEED_NGINX_RELOAD=true ;;
            cron)  NEED_CRON_RELOAD=true ;;
        esac
    fi
done

if ! $NEED_SYSTEMD_RELOAD && ! $NEED_NGINX_RELOAD && ! $NEED_CRON_RELOAD; then
    echo "✓ all infra in sync — no work to do"
    exit 0
fi

if $DRY_RUN; then
    echo "(dry-run) would push:"
    $NEED_SYSTEMD_RELOAD && echo "  systemd units: ${SYSTEMD_TO_RESTART[*]}"
    $NEED_NGINX_RELOAD && echo "  nginx vhost"
    $NEED_CRON_RELOAD && echo "  system cron"
    exit 0
fi

# Phase 2: upload via tmp + sudo move (need sudo for /etc/* destinations)
echo "→ uploading to /tmp on remote"
TMP_DIR="/tmp/teplanner-infra-$$"
ssh_run "mkdir -p $TMP_DIR"
TO_UPLOAD=()
for asset in "${ASSETS[@]}"; do
    IFS='|' read -r local_path remote_path kind unit_name <<< "$asset"
    L="$(local_sha "$ROOT/$local_path")"
    R="$(remote_sha "$remote_path" || true)"
    [ "$L" = "$R" ] && continue
    base="$(basename "$remote_path")"
    scp_run "$ROOT/$local_path" "$REMOTE_HOST:$TMP_DIR/$base"
    TO_UPLOAD+=("$base|$remote_path")
done

echo "→ installing to /etc with sudo"
for entry in "${TO_UPLOAD[@]}"; do
    IFS='|' read -r base remote_path <<< "$entry"
    ssh_run "sudo -n install -m 644 -o root -g root $TMP_DIR/$base $remote_path"
    echo "  ✓ $remote_path"
done
ssh_run "rm -rf $TMP_DIR"

# Phase 3: reload affected daemons
if $NEED_SYSTEMD_RELOAD; then
    echo "→ systemctl daemon-reload"
    ssh_run "sudo -n systemctl daemon-reload"
    for unit in "${SYSTEMD_TO_RESTART[@]}"; do
        echo "→ systemctl restart $unit"
        ssh_run "sudo -n systemctl restart $unit"
        sleep 2
        active=$(ssh_run "systemctl is-active $unit" || echo "fail")
        if [ "$active" = "active" ]; then
            echo "  ✓ $unit active"
        else
            echo "  ✗ $unit is $active — check journalctl -u $unit" >&2
            exit 1
        fi
    done
fi

if $NEED_NGINX_RELOAD; then
    echo "→ nginx -t && reload"
    ssh_run "sudo -n nginx -t && sudo -n nginx -s reload"
fi

if $NEED_CRON_RELOAD; then
    # /etc/cron.d/ is auto-rescanned by cron daemon; just verify
    # it's present + has correct perms (no execute bit).
    echo "→ verifying cron file perms"
    ssh_run "sudo -n stat -c '%a %U:%G %n' /etc/cron.d/teplanner-daily-inspection"
fi

# Phase 4: post-install verification
echo "→ post-install health check"
HEALTH="$(curl -sS -o /dev/null -w '%{http_code}' https://api.teplanner.cloud/health)"
echo "  /health: $HEALTH"
[ "$HEALTH" = "200" ] || { echo "  ✗ backend not responding" >&2; exit 1; }

echo "✓ infra deploy complete"
