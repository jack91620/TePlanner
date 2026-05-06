#!/bin/bash
#
# Retag AMap iOS SDK arm64 slices as iOS-Simulator (Mach-O platform 7) so
# the static archives link against the iphonesimulator SDK on Apple
# Silicon Macs. AMap publishes only legacy fat .a binaries (arm64-device
# + x86_64-simulator); without this rewrite Xcode either excludes arm64
# from simulator builds (failing on Apple Silicon) or refuses to link
# the iOS-tagged arm64 slice into a simulator binary.
#
# What it does, per AMap framework:
#   1. lipo-thin the arm64 slice out
#   2. ar-extract individual .o files
#   3. vtool -set-build-version 7 13.0 18.2 -replace each .o
#      (pod-generated Pods-*-dummy.o is too small to fit the new load
#      command — drop it; it's empty anyway)
#   4. ar-rebuild a new arm64 archive
#   5. lipo-recombine with the unchanged x86_64 archive
#   6. overwrite the framework binary in place
#
# Invoked automatically from Podfile's post_install. Idempotent: keeps a
# .orig copy of every framework binary so re-runs work from the
# untouched source.
#
# Reverts to original when running `pod deintegrate && pod install`.

set -uo pipefail

ROOT="${1:-$(pwd)}"
PODS_DIR="$ROOT/Pods"

if [ ! -d "$PODS_DIR" ]; then
    echo "retag-amap-for-sim: Pods/ not found under $ROOT — skipping" >&2
    exit 0
fi

retag() {
    local in="$1"
    local out="$2"
    in="$(cd "$(dirname "$in")" && pwd)/$(basename "$in")"
    out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    echo "  → $(basename "$out")"

    ( cd "$tmp" && lipo "$in" -thin arm64 -output arm64.a \
        && mkdir arm64-objs && cd arm64-objs && ar -x ../arm64.a ) || return 1

    (
        cd "$tmp/arm64-objs"
        for f in *.o; do
            if vtool -arch arm64 -set-build-version 7 13.0 18.2 \
                -replace -output "$f.sim" "$f" 2>/dev/null; then
                mv "$f.sim" "$f"
            else
                echo "    drop: $f (no header slack — likely Pods dummy)"
                rm -f "$f"
            fi
        done
        ar -rcs ../arm64-sim.a *.o
    ) || return 1

    ( cd "$tmp" && lipo "$in" -thin x86_64 -output x86_64.a 2>/dev/null ) || return 1

    lipo -create "$tmp/arm64-sim.a" "$tmp/x86_64.a" -output "$out" || return 1
}

frameworks=(
    "Pods/AMapFoundation/AMapFoundationKit.framework/AMapFoundationKit"
    "Pods/AMap3DMap/MAMapKit.framework/MAMapKit"
    "Pods/AMapSearch/AMapSearchKit.framework/AMapSearchKit"
    "Pods/AMapLocation/AMapLocationKit.framework/AMapLocationKit"
)

cd "$ROOT"

for fw in "${frameworks[@]}"; do
    if [ ! -f "$fw" ]; then
        echo "retag-amap-for-sim: $fw not found — skipping (run \`pod install\` first)" >&2
        continue
    fi
    test -f "$fw.orig" || cp -f "$fw" "$fw.orig"
    if ! retag "$fw.orig" "$fw"; then
        echo "retag-amap-for-sim: FAILED on $fw" >&2
        exit 1
    fi
done

echo "retag-amap-for-sim: all AMap arm64 slices retagged for iOS Simulator"
