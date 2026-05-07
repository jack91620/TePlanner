# Ops runbook

This file defines the **automated** ops loop — what runs without
human intervention, what auto-fixes, what only reports. Anything not
listed here requires explicit user approval.

## The two loops

### A. Server-side watchdog (always-on)

Lives on the Tencent VM (`82.156.248.135`) as a crontab entry
running `/home/ubuntu/ops/server-monitor.sh` every 5 minutes. No LLM
involvement; pure bash + jq.

What it does each tick:

1. Probes `https://api.teplanner.cloud/health` (timeout 5s).
2. Checks the backend Python process is alive (`pgrep -f "uvicorn app.main"`).
3. Checks polling loop is ticking (looks for `polling tick complete`
   line in `~/TePlanner/backend/server.log` within the last 15 min).
4. Counts ERROR-level log lines in the last 5 min.
5. Checks disk usage (`df /`) and RAM (`free`).
6. Writes a JSON snapshot to `~/ops/state/snapshot.json` (single file,
   overwritten each tick — historical state lives in
   `~/ops/state/snapshots/<ts>.json`, kept 7 days).
7. If any **auto-fixable** condition triggers, applies the fix and
   logs to `~/ops/state/incidents.log`.
8. If a **non-auto-fixable** alarm fires, writes an entry to
   `~/ops/state/incidents.log` (humans + future Claude session catch up).

### B. Claude-side review (when a session is open)

Local Claude Code cron (durable). Fires daily; reads the latest
incidents, does the triage, applies safe fixes, produces a report
under `ops/reports/YYYY-MM-DD.md`.

Also fires manually on demand (`/loop` from the user, or just asking
"check ops").

## Auto-fix matrix

| Trigger | Detection | Action | Limit |
|---|---|---|---|
| Backend dead | `/health` not 200 AND no uvicorn process | `bash ~/TePlanner/backend/start.sh -d -s` | Max 3 restarts/hour |
| Polling loop frozen | Last `polling tick complete` > 15 min ago AND backend up | Restart backend | Max 1/hour |
| Disk > 90% | `df /` % | `journalctl --vacuum-size=200M`, gzip+rm `server.log.*` older than 7d | Once per day |

Non-auto-fixable (alert only):

- 5xx rate spike (>1% of recent requests)
- AMap quota hit (`infocode != "10000"` in logs)
- Tesla 401 burst across users (token refresh failing for >3 users)
- TLS cert expiring < 14d
- RAM > 90%
- Unrecognized exception in last 5 min

## Self-upgrade scope

Daily review may auto-commit:

- **Documentation drift**: line numbers in `CLAUDE.md` referencing wrong
  file paths, broken anchors. Direct edit + commit.
- **Generated artifacts**: regenerate xcodeproj if `project.yml` newer
  than xcodeproj's last mod time AND there are no uncommitted changes
  to the generated tree.

Daily review may **propose** (PR draft, not merged):

- Patch-version dep bumps in `requirements.txt` / `Package.swift`
- Removing functions / files with zero references
- Performance fixes for clearly slow loops (>O(N²) in hot path)

Daily review will **never** auto-touch:

- Anything in `Tesla*`, `AMap*` integration code
- Database schema (models.py)
- API contracts
- Any code paying real money (Tesla quota, AMap quota, APNs cost)
- Any cert / key material

## Reporting

- **Always-on monitor**: appends to `~/ops/state/incidents.log` on the VM
- **Claude review**: writes `ops/reports/YYYY-MM-DD.md` (gitignored)
- **User-visible**: at end of each session where ops work happened, I
  state in chat what I did and what's pending review

## Notification channels

For now: file-based. The user reads `ops/reports/` next time they
open a session. Future: pipe into the APNs `/devices` channel so a
production failure pushes to the developer's TestFlight-installed
phone — same plumbing we built for product alerts.
