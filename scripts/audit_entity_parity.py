#!/usr/bin/env python3
"""Verify backend `_ENTITY_MAP` keys all have iOS `entityName` mappings.

Cross-platform contract: any `vehicle.*` entity exposed by backend's
automation interpreter (`backend/app/services/automation/interpreters.py`)
must have a Chinese-name mapping in iOS RuleDisplay.entityName
(`apps/ios/Sources/TePlannerKit/Automations/Interpreters/RuleDisplay.swift`).

Drift symptom: raw key like `vehicle.trunk_open` leaking into the UI
when a rule uses an entity iOS doesn't know how to label. See commit
bd21fb5 for the canonical instance + 12 entities that had silently
fallen behind.

Exit codes:
  0 — parity OK
  1 — drift detected (missing iOS mappings printed)
  2 — script error (file paths missing etc.)

Wired into `make precommit`. Run manually with:
    python3 scripts/audit_entity_parity.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BACKEND_INTERPRETERS = ROOT / "backend" / "app" / "services" / "automation" / "interpreters.py"
IOS_RULE_DISPLAY = ROOT / "apps" / "ios" / "Sources" / "TePlannerKit" / "Automations" / "Interpreters" / "RuleDisplay.swift"


def parse_backend_entities() -> set[str]:
    """Extract every `vehicle.*` key from _ENTITY_MAP in interpreters.py."""
    text = BACKEND_INTERPRETERS.read_text(encoding="utf-8")
    # The mapping block is bounded by `_ENTITY_MAP = {` ... `}`.
    m = re.search(r"_ENTITY_MAP\s*=\s*\{(.+?)^\}", text, re.DOTALL | re.MULTILINE)
    if not m:
        print("ERROR: couldn't locate _ENTITY_MAP block in", BACKEND_INTERPRETERS, file=sys.stderr)
        sys.exit(2)
    block = m.group(1)
    return set(re.findall(r'"(vehicle\.[a-z_.]+)"', block))


def parse_ios_entities() -> set[str]:
    """Extract every entity in `entityName(_:)`'s switch statement."""
    text = IOS_RULE_DISPLAY.read_text(encoding="utf-8")
    # Function bounded by `public static func entityName(` ... matching `}`.
    m = re.search(r"public static func entityName\(.+?\)\s*->\s*String\s*\{(.+?)^\s*\}\s*$",
                  text, re.DOTALL | re.MULTILINE)
    if not m:
        # Fallback: just grep for case lines anywhere in the file.
        cases = set(re.findall(r'case\s+"(vehicle\.[a-z_.]+)"\s*:\s*return', text))
        return cases
    block = m.group(1)
    return set(re.findall(r'case\s+"(vehicle\.[a-z_.]+)"\s*:\s*return', block))


def main() -> int:
    backend_entities = parse_backend_entities()
    ios_entities = parse_ios_entities()

    missing_in_ios = sorted(backend_entities - ios_entities)
    extra_in_ios = sorted(ios_entities - backend_entities)

    if not missing_in_ios and not extra_in_ios:
        print(f"entity parity OK ({len(backend_entities)} entities both sides)")
        return 0

    print("entity parity drift detected:", file=sys.stderr)
    if missing_in_ios:
        print(f"  backend has but iOS doesn't ({len(missing_in_ios)}):", file=sys.stderr)
        for e in missing_in_ios:
            print(f"    - {e}", file=sys.stderr)
        print(
            "  → add a Chinese name to "
            "apps/ios/Sources/TePlannerKit/Automations/Interpreters/RuleDisplay.swift "
            "in entityName(_:) before committing.",
            file=sys.stderr,
        )
    if extra_in_ios:
        print(f"  iOS has but backend doesn't ({len(extra_in_ios)}) — likely stale, safe to remove:", file=sys.stderr)
        for e in extra_in_ios:
            print(f"    - {e}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
