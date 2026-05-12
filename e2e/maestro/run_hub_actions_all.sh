#!/usr/bin/env bash
# Ship gate for the Hub Quick Actions feature — runs every Maestro
# flow 21..34 against the iOS sim with a real-Tesla session, resetting
# user 241's hub.* settings between runs.
#
# Each flow logs PASS / FAIL with elapsed time; non-zero exit if any
# fail. Use before TestFlight upload.
#
# Usage:
#   TEPLANNER_SSH_PASS='...' bash e2e/maestro/run_hub_actions_all.sh
#
# Env / prerequisites:
#   - iOS sim 'iPhone 17' booted with the latest debug build
#     (`make run-app` once before running this)
#   - e2e/maestro/.env populated with MAESTRO_TESLA_* creds
#   - TEPLANNER_SSH_PASS to wipe backend state between runs (else
#     tests run against whatever state was left over)
set -uo pipefail

cd "$(dirname "$0")/../.."

if [ -f e2e/maestro/.env ]; then
  set -a; . e2e/maestro/.env; set +a
fi

JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
MAESTRO="${MAESTRO_BIN:-/opt/homebrew/bin/maestro}"
UDID="${IOS_SIM_UDID:-$(xcrun simctl list devices booted | awk -F '[()]' '/iOS/ {next} /Booted/ {print $2; exit}')}"
RESET="$(pwd)/e2e/maestro/_helpers/reset_hub_actions.sh"

if [ -z "$UDID" ]; then
  echo "no booted iOS sim — run 'make run-app' first" >&2
  exit 2
fi
echo "iOS sim UDID: $UDID"
echo

flows=(
  21_hub_quick_actions
  22_hub_quick_actions_editor
  23_hub_quick_actions_long_press_edit
  24_hub_quick_actions_delete
  25_hub_quick_actions_confirm_dialog
  26_hub_quick_actions_macro
  27_hub_quick_actions_persistence
  28_hub_quick_actions_picker_existing
  29_hub_quick_actions_cancel_no_save
  30_hub_quick_actions_manage_button
  31_hub_quick_actions_save_validation
  32_hub_quick_actions_dispatch
  33_hub_quick_actions_step_limit
  34_hub_quick_actions_edit_persistence
)

declare -a results
fail_count=0
for flow in "${flows[@]}"; do
  echo "─── ${flow} ───"
  # Reset backend state before each flow. Retry once on flake —
  # Tencent Cloud occasionally drops SSH connections mid-run.
  if ! bash "$RESET" >/dev/null 2>&1; then
    sleep 2
    if ! bash "$RESET" >/dev/null 2>&1; then
      echo "  (warn) reset failed twice — skipping flow"
      results+=("? ${flow}  (reset failed)")
      continue
    fi
  fi
  # Kill the app between runs so each test's ensure_logged_in
  # forces a fresh quickActionsStore.load() from backend. Without
  # this, the previous test's in-memory edits (e.g. 09 renaming
  # 锁车→锁车2) leak into the next test even though backend is
  # wiped, because the store doesn't auto-refresh on app foreground.
  xcrun simctl terminate "$UDID" com.teplanner.ios >/dev/null 2>&1 || true
  # Brief settle — give the DB commit time to propagate before
  # maestro re-launches the app + GETs /user/settings. Skipping
  # this caused flakes where slot 4 still held a prior test's
  # tile because the in-flight write hadn't reached the read.
  sleep 1
  start=$(date +%s)
  if JAVA_HOME="$JAVA_HOME" "$MAESTRO" --udid "$UDID" test \
       "e2e/maestro/${flow}.yaml" >/dev/null 2>&1; then
    elapsed=$(( $(date +%s) - start ))
    results+=("✓ ${flow}  (${elapsed}s)")
    echo "  PASS  (${elapsed}s)"
  else
    elapsed=$(( $(date +%s) - start ))
    results+=("✗ ${flow}  (${elapsed}s)")
    echo "  FAIL  (${elapsed}s)"
    fail_count=$((fail_count + 1))
  fi
done

echo
echo "─── Summary ───"
for r in "${results[@]}"; do echo "$r"; done
echo
total=${#flows[@]}
pass=$((total - fail_count))
echo "Result: ${pass}/${total} flows passed"
exit "$fail_count"
