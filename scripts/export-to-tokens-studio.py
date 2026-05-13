#!/usr/bin/env python3
"""Generate packages/design-tokens/tokens-studio.json from tokens.json.

The Tokens Studio Figma plugin (https://tokens.studio) consumes a
specific JSON shape that differs from ours:

  - Top-level wrapper: {"global": {...}} (set names as keys)
  - Numeric values: strings with units, e.g. "16px"
  - Typography composite: {fontSize, fontWeight, lineHeight, ...}
  - Shadow composite: {offsetX, offsetY, blur, spread, color, type}
  - Dimension subdivides into spacing / borderRadius / opacity per path
  - No equivalent for our ios_system_color (Color(.systemBackground)
    is iOS-runtime adaptive; Tokens Studio expects concrete hex);
    skipped with a top-level $comment listing what was dropped.

Workflow:
  edit packages/design-tokens/tokens.json
  python3 scripts/generate-tokens.py        # SwiftUI + Compose
  python3 scripts/export-to-tokens-studio.py  # Figma plugin
  git diff
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "packages" / "design-tokens" / "tokens.json"
OUT = ROOT / "packages" / "design-tokens" / "tokens-studio.json"


_WEIGHT_STUDIO = {
    "regular": "Regular",
    "medium": "Medium",
    "semibold": "SemiBold",
    "bold": "Bold",
}


def _studio_dimension_type(path: list[str], name: str) -> str:
    """Map a dimension token's path → Tokens Studio dimension subtype."""
    head = path[0] if path else ""
    if head == "radius":
        return "borderRadius"
    if name.endswith("_alpha") or "alpha" in name:
        return "opacity"
    if head == "spacing":
        return "spacing"
    return "spacing"


def _hex_with_alpha(hexstr: str, opacity: float) -> str:
    """`#RRGGBB` + opacity → `#RRGGBBAA` (W3C / CSS alpha-last)."""
    h = hexstr.lstrip("#")
    alpha = round(max(0.0, min(1.0, opacity)) * 255)
    return f"#{h.upper()}{alpha:02X}"


def _convert_typography(spec: dict) -> dict:
    """Our {size,weight?,design?} → Studio typography composite.

    Studio has no equivalent for design:monodigit; flagged inline.
    fontFamily uses "Inter" (Figma's universally available default)
    rather than "System" — the iOS app actually renders SF Pro via
    .system font, but Figma can't find a font literally named "System"
    and the whole composite import fails. Designer can override per-
    Variable to SF Pro Text if they've installed it locally."""
    out: dict[str, Any] = {
        "fontFamily": "Inter",
        "fontSize": f"{spec['size']}px",
    }
    if w := spec.get("weight"):
        out["fontWeight"] = _WEIGHT_STUDIO.get(w, "Regular")
    if spec.get("design") == "monospaced":
        out["fontFamily"] = "Menlo"
    return out


def _convert_shadow(spec: dict) -> dict:
    """Our {color,opacity?,radius,x?,y?} → Studio boxShadow composite.

    Tokens Studio plugin uses x/y (not offsetX/offsetY — those are the
    sd-transforms output format for code consumption, NOT the plugin
    input format)."""
    return {
        "color": _hex_with_alpha(spec["color"], spec.get("opacity", 1.0)),
        "type": "dropShadow",
        "x": f"{spec.get('x', 0)}px",
        "y": f"{spec.get('y', 0)}px",
        "blur": f"{spec['radius']}px",
        "spread": "0px",
    }


def _set(node: dict, path: list[str], leaf: dict) -> None:
    """Insert `leaf` at `path` in nested-dict `node`."""
    cur = node
    for part in path[:-1]:
        cur = cur.setdefault(part, {})
    cur[path[-1]] = leaf


def _walk(node: Any, prefix: list[str], out: dict, skipped: list[str]) -> None:
    if not isinstance(node, dict):
        return
    if "value" in node and (
        not isinstance(node["value"], dict)
        or node.get("type") in ("typography", "shadow")
    ):
        kind = node.get("type", "")
        name = prefix[-1] if prefix else ""
        if kind == "color":
            _set(out, prefix, {"value": node["value"], "type": "color"})
        elif kind == "dimension":
            studio_type = _studio_dimension_type(prefix, name)
            if studio_type == "opacity":
                _set(out, prefix, {"value": str(node["value"]), "type": "opacity"})
            else:
                _set(out, prefix, {"value": f"{node['value']}px", "type": studio_type})
        elif kind == "typography":
            _set(out, prefix, {"value": _convert_typography(node["value"]), "type": "typography"})
        elif kind == "shadow":
            _set(out, prefix, {"value": _convert_shadow(node["value"]), "type": "boxShadow"})
        elif kind == "ios_system_color":
            skipped.append(".".join(prefix) + f" (iOS Color(.{node['value']}))")
        return
    for k, v in node.items():
        if k.startswith("$"):
            continue
        _walk(v, prefix + [k], out, skipped)


def main() -> None:
    spec = json.loads(SRC.read_text())
    global_set: dict = {}
    skipped: list[str] = []
    _walk(spec, [], global_set, skipped)

    payload = {
        "$schema": "https://schemas.tokens.studio/latest/tokens-schema.json",
        "$metadata": {
            "tokenSetOrder": ["global"],
            "generatedFrom": "packages/design-tokens/tokens.json via scripts/export-to-tokens-studio.py",
            "skipped": skipped,
            "note": (
                "Edit tokens.json (source of truth), not this file. "
                "Tokens Studio plugin pulls this via GitHub sync; designer "
                "changes flow back as a PR that edits tokens.json. "
                "ios_system_color tokens are runtime-adaptive iOS Color "
                "references with no Figma Variables equivalent — listed in "
                "skipped[]; designers see them only in iOS app, not in "
                "Figma."
            ),
        },
        "global": global_set,
    }
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    total = sum(1 for _ in _flatten(global_set))
    print(f"wrote {total} tokens → {OUT}")
    if skipped:
        print(f"  skipped {len(skipped)} ios_system_color token(s):")
        for s in skipped:
            print(f"    - {s}")


def _flatten(node: Any):
    if isinstance(node, dict):
        if "value" in node and "type" in node:
            yield node
        else:
            for v in node.values():
                yield from _flatten(v)


if __name__ == "__main__":
    main()
