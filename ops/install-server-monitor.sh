#!/bin/bash
#
# One-shot installer that copies the watchdog onto the Tencent VM,
# wires the user crontab, and runs one tick to verify.
#
# Idempotent: safe to re-run after editing server-monitor.sh.

set -euo pipefail

if [ -z "${SSHPASS:-}" ]; then
    echo "Set SSHPASS env var first (password auth via sshpass -e)." >&2
    exit 1
fi

REMOTE_HOST="${REMOTE_HOST:-ubuntu@82.156.248.135}"
REMOTE_OPS_DIR="/home/ubuntu/ops"

# Ensure remote ops dir exists before scp.
sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_HOST" "mkdir -p $REMOTE_OPS_DIR/state/snapshots"

echo "→ uploading server-monitor.sh + daily-inspection.sh"
sshpass -e scp -q -o StrictHostKeyChecking=no \
    "$(dirname "$0")/server-monitor.sh" \
    "$(dirname "$0")/daily-inspection.sh" \
    "$(dirname "$0")/simulate-alert.sh" \
    "$REMOTE_HOST:$REMOTE_OPS_DIR/"

echo "→ ensuring layout + cron"
sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_HOST" '
set -euo pipefail
mkdir -p ~/ops/state/snapshots ~/TePlanner/ops/reports
chmod +x ~/ops/server-monitor.sh ~/ops/daily-inspection.sh ~/ops/simulate-alert.sh
# Replace any existing TePlanner cron entries; preserve unrelated ones.
EXISTING="$(crontab -l 2>/dev/null | grep -v "ops/server-monitor.sh" || true)"
NEW="$(printf "%s\n%s\n" "$EXISTING" "*/5 * * * * /home/ubuntu/ops/server-monitor.sh >> /home/ubuntu/ops/state/cron.out 2>&1")"
echo "$NEW" | crontab -
echo "crontab now:"
crontab -l | grep ops || true
# Daily inspection: system cron at /etc/cron.d/teplanner-daily-inspection
# (managed via sudo, so installed manually — re-installer reminder below).
if [ ! -f /etc/cron.d/teplanner-daily-inspection ]; then
    echo "WARN: /etc/cron.d/teplanner-daily-inspection missing — install with:"
    echo "  sudo cp ops/cron/teplanner-daily-inspection.cron /etc/cron.d/teplanner-daily-inspection"
fi
'

echo "→ running one tick to verify"
sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_HOST" '
~/ops/server-monitor.sh
echo "--- snapshot ---"
cat ~/ops/state/snapshot.json | jq .
echo "--- last 5 incidents ---"
tail -5 ~/ops/state/incidents.log 2>/dev/null || echo "(empty)"
'

echo "✓ installed"
