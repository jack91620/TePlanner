#!/usr/bin/env bash
# Phase C — CI gate: regenerate every committed SDK and fail if
# anything would change. Catches the case where a developer edited
# packages/clients/openapi.json by hand or forgot to run
# `make codegen` after a backend schema change.
#
# Compares against the committed working-tree files via
# `git diff --exit-code`. Run from the repo root.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain packages/clients/ 2>/dev/null)" ]]; then
  echo "✗ packages/clients/ has uncommitted changes — commit or stash before running this gate" >&2
  git status --short packages/clients/ >&2
  exit 1
fi

echo "==> Regenerating all SDKs from packages/clients/openapi.json"
bash "$ROOT/scripts/codegen.sh"

echo
echo "==> Diffing against committed SDKs"
if ! git diff --exit-code --stat packages/clients/ ; then
  echo
  echo "✗ codegen produced changes that aren't committed."
  echo "  Run \`make codegen\` locally and commit the result."
  exit 1
fi

echo "✓ all generated SDKs match committed snapshots"
