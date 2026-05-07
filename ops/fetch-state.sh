#!/bin/bash
#
# Pulls current ops state from the VM into local ops/state/ so a
# Claude session can review without needing live SSH every time.
#
# Outputs (all gitignored):
#   ops/state/snapshot.json           latest tick
#   ops/state/incidents.log           full incidents log (overwrites)
#   ops/state/recent-errors.txt       last 100 ERROR lines from server.log
#
# Usage: SSHPASS='...' ops/fetch-state.sh

set -euo pipefail

if [ -z "${SSHPASS:-}" ]; then
    echo "Set SSHPASS env var first." >&2
    exit 1
fi

REMOTE_HOST="${REMOTE_HOST:-ubuntu@82.156.248.135}"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)/state"
mkdir -p "$LOCAL_DIR"
# Pre-create so downstream tools can rely on the files existing,
# even when the SSH stream produced no content for that section.
: > "$LOCAL_DIR/snapshot.json"
: > "$LOCAL_DIR/incidents.log"
: > "$LOCAL_DIR/recent-errors.txt"

# One SSH call, multiple cats. Avoids password prompts piling up.
sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_HOST" '
echo "===SNAPSHOT==="
cat ~/ops/state/snapshot.json 2>/dev/null || echo "{}"
echo "===INCIDENTS==="
tail -200 ~/ops/state/incidents.log 2>/dev/null || true
echo "===ERRORS==="
grep -E "ERROR|Exception|Traceback" ~/TePlanner/backend/server.log 2>/dev/null | tail -100 || true
echo "===END==="
' | awk '
    /^===SNAPSHOT===$/ { mode="snap"; next }
    /^===INCIDENTS===$/ { mode="inc"; next }
    /^===ERRORS===$/ { mode="err"; next }
    /^===END===$/ { mode="off"; next }
    mode=="snap" { print > "'"$LOCAL_DIR"'/snapshot.json" }
    mode=="inc"  { print > "'"$LOCAL_DIR"'/incidents.log" }
    mode=="err"  { print > "'"$LOCAL_DIR"'/recent-errors.txt" }
'

echo "Pulled to $LOCAL_DIR"
ls -la "$LOCAL_DIR"
