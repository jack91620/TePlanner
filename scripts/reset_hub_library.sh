#!/usr/bin/env bash
# Reset the Hub Quick Actions library back to the 4 system seeds.
#
# Tests like e2e/maestro/24_hub_quick_actions_delete.yaml assume
# slot 4 is empty. After multiple test runs the user's library
# accumulates "待删", "保留我", etc. leftovers in slots 4-7.
# Resetting via the manage-sheet UI clears them.
#
# Backend has no admin endpoint for this (auth is per-user JWT and
# scripts can't easily get one), so we drive the reset through the
# Tautomation app's manage sheet via a Maestro helper flow. The app
# does the right thing — HubActionsStore.resetToDefaults wipes every
# custom action and re-seeds the 4 system defaults, then persists to
# user_settings.
#
# Usage:
#   bash scripts/reset_hub_library.sh                   # auto-pick device
#   bash scripts/reset_hub_library.sh ios               # use booted iOS sim
#   bash scripts/reset_hub_library.sh android           # use first adb device
#   bash scripts/reset_hub_library.sh <UDID-or-serial>  # explicit device
#
# Precondition: the target device has Tautomation installed and the
# user is already authenticated (the helper calls ensure_logged_in
# first, so first-run OAuth still works if .env is set).

set -euo pipefail

cd "$(dirname "$0")/.."

JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}"
ENV_FILE="e2e/maestro/.env"
HELPER_IOS="e2e/maestro/_helpers/reset_hub_library.yaml"
HELPER_ANDROID="e2e/maestro/_helpers/reset_hub_library_android.yaml"

if [[ -f "$ENV_FILE" ]]; then
  set -a; . "$ENV_FILE"; set +a
fi

target="${1:-auto}"

resolve_device() {
  case "$target" in
    auto)
      # Prefer iOS sim if booted, else first Android device.
      local ios_udid
      ios_udid="$(xcrun simctl list devices booted 2>/dev/null \
        | awk '/Booted/ {gsub(/[()]/,""); print $(NF-1); exit}')"
      if [[ -n "${ios_udid:-}" ]]; then
        echo "ios|$ios_udid"; return
      fi
      local android
      android="$(${ANDROID_SDK:-$HOME/Library/Android/sdk}/platform-tools/adb devices \
        | awk '/\sdevice$/ {print $1; exit}')"
      if [[ -n "${android:-}" ]]; then
        echo "android|$android"; return
      fi
      echo "ERROR: no booted iOS sim or attached Android device" >&2
      exit 1
      ;;
    ios)
      local ios_udid
      ios_udid="$(xcrun simctl list devices booted 2>/dev/null \
        | awk '/Booted/ {gsub(/[()]/,""); print $(NF-1); exit}')"
      if [[ -z "${ios_udid:-}" ]]; then
        echo "ERROR: no booted iOS simulator" >&2; exit 1
      fi
      echo "ios|$ios_udid"
      ;;
    android)
      local android
      android="$(${ANDROID_SDK:-$HOME/Library/Android/sdk}/platform-tools/adb devices \
        | awk '/\sdevice$/ {print $1; exit}')"
      if [[ -z "${android:-}" ]]; then
        echo "ERROR: no adb device attached" >&2; exit 1
      fi
      echo "android|$android"
      ;;
    *)
      # Explicit UDID-or-serial; guess platform by format.
      if [[ "$target" =~ ^emulator- ]] || [[ "$target" =~ ^[0-9A-Z]{4,}$ && ! "$target" =~ - ]]; then
        echo "android|$target"
      else
        echo "ios|$target"
      fi
      ;;
  esac
}

resolved="$(resolve_device)"
platform="${resolved%%|*}"
udid="${resolved##*|}"

helper="$HELPER_IOS"
[[ "$platform" == "android" ]] && helper="$HELPER_ANDROID"

if [[ ! -f "$helper" ]]; then
  echo "ERROR: helper flow missing: $helper" >&2
  exit 1
fi

echo "==> resetting Hub Quick Actions library on $platform device $udid"
JAVA_HOME="$JAVA_HOME" maestro --device "$udid" test "$helper"
echo "==> reset OK"
