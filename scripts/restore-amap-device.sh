#!/bin/bash
#
# Restore AMap iOS SDK framework binaries from the .orig copies that
# retag-amap-for-sim.sh stashed away. Needed before `make archive`
# because the simulator-retagged arm64 slices (platform=7) won't link
# into a device build (which needs platform=2 / iOS).
#
# Pairs with retag-amap-for-sim.sh: that script always saves the
# original framework binary to <fw>.orig before rewriting. This
# script just copies the .orig back. Idempotent: a no-op if the
# binary is already the original (no .orig present means nothing
# was retagged).
#
# Usage: restore-amap-device.sh [PROJECT_ROOT]

set -uo pipefail

ROOT="${1:-$(pwd)}"
PODS_DIR="$ROOT/Pods"

if [ ! -d "$PODS_DIR" ]; then
    echo "restore-amap-device: Pods/ not found under $ROOT — skipping" >&2
    exit 0
fi

restored=0
for fw in \
    "$PODS_DIR/AMapFoundation/AMapFoundationKit.framework/AMapFoundationKit" \
    "$PODS_DIR/AMap3DMap/MAMapKit.framework/MAMapKit" \
    "$PODS_DIR/AMapSearch/AMapSearchKit.framework/AMapSearchKit" \
    "$PODS_DIR/AMapLocation/AMapLocationKit.framework/AMapLocationKit"
do
    if [ -f "$fw.orig" ]; then
        cp -f "$fw.orig" "$fw"
        echo "  → restored $(basename "$fw") from .orig"
        restored=$((restored + 1))
    fi
done

echo "restore-amap-device: $restored framework(s) restored to device build"
