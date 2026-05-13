#!/usr/bin/env bash
# CI gate: regenerate every generated artifact from
# packages/design-tokens/tokens.json and fail if anything would change.
# Catches: (a) someone hand-edited Tokens.swift / Tokens.kt /
# tokens-studio.json bypassing tokens.json; (b) someone edited
# tokens.json but forgot to run `make tokens`.
#
# Mirrors scripts/verify-openapi-frozen.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GENERATED=(
  apps/ios/Sources/TePlannerKit/Theme/Tokens.swift
  apps/android/core/ui/src/main/java/cloud/teplanner/android/core/ui/Tokens.kt
  packages/design-tokens/tokens-studio.json
)

if [[ -n "$(git status --porcelain "${GENERATED[@]}" packages/design-tokens/tokens.json 2>/dev/null)" ]]; then
  echo "✗ design-tokens has uncommitted changes — commit or stash before running this gate" >&2
  git status --short "${GENERATED[@]}" packages/design-tokens/tokens.json >&2
  exit 1
fi

echo "==> Regenerating all design-token artifacts"
python3 "$ROOT/scripts/generate-tokens.py"
python3 "$ROOT/scripts/export-to-tokens-studio.py"

echo
echo "==> Diffing against committed artifacts"
if ! git diff --exit-code --stat "${GENERATED[@]}" ; then
  echo
  echo "✗ token generation produced changes that aren't committed."
  echo "  Run \`make tokens\` locally and commit the result."
  exit 1
fi

echo "✓ all generated token artifacts match committed snapshots"
