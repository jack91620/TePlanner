# Daily ops review — Claude prompt template

This is the prompt body the Claude-side cron uses each day. Pasting
it back into a session also works for ad-hoc reviews.

---

You are doing a daily ops review of TePlanner. Strictly follow the
boundaries in `ops/RUNBOOK.md` — only auto-fix what's listed there;
everything else goes into a report for the user.

## Steps

1. Run `SSHPASS='Welcome09!' ./ops/fetch-state.sh` to pull the latest
   state from the production VM into `ops/state/`.

2. Read these files:
   - `ops/state/snapshot.json` — current health
   - `ops/state/incidents.log` — last 200 incidents
   - `ops/state/recent-errors.txt` — last 100 ERROR lines from server.log

3. Triage:
   - For each incident in last 24h: classify as "auto-fixed (no action)"
     / "still alarming" / "false positive".
   - For ERROR lines: cluster by exception type. Anything new vs
     yesterday's report?
   - Check disk / errors5m / pollingAgeS in snapshot.

4. Self-upgrade pass (only what's listed in RUNBOOK.md "Self-upgrade
   scope" as direct-edit-OK):
   - Look for line numbers in CLAUDE.md or docs/ios-port-plan.md that
     reference files that no longer exist or are at different paths.
   - Look for stale TODOs (>30d via `git log -L`) that are clearly
     resolved.
   - Look for `xcodeproj` regenerate need.
   Fix what's safe; commit with a `chore(ops):` prefix.

5. Self-upgrade pass — propose only:
   - Patch deps bumps (do not commit, write to today's report)
   - Functions/files with zero references (write to report)

6. Write today's report to `ops/reports/YYYY-MM-DD.md`:
   - **Status** (one line: green/yellow/red + why)
   - **Last 24h incidents** (count by category)
   - **Auto-fixed** (what the watchdog did without me)
   - **Auto-fixed by Claude** (what I edited this run)
   - **Needs your review** (proposals + rationale, with file:line refs)
   - **Tomorrow** (what to watch for)

7. Output a 5-line chat summary so the user sees it on next session
   open, even if they don't read the report.

## Refusal cases

If the snapshot shows the backend is hard-down OR there's an
incident pattern that suggests the watchdog auto-fix is in a loop
(>2 restarts in last hour), DO NOT attempt your own fix — write the
incident to the report, ping the user in chat, stop.

If you find ERROR patterns involving Tesla/AMap integrations,
DO NOT auto-edit. Write the diagnosis to the report.
