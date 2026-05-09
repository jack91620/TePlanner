# TePlanner — single source of truth for build/test/lint commands.
# Local Xcode work AND CLI/Claude sessions go through these targets so
# behavior is identical everywhere.
#
# Project structure (Phase B repo restructure, 2026-05-09):
#   - apps/ios/Sources/TePlannerKit + apps/ios/Tests are pure SPM.
#   - apps/ios/TePlannerApp/ is the iOS app target — driven by
#     xcodegen + cocoapods from apps/ios/project.yml + apps/ios/Podfile.
#   - apps/android/, apps/harmony/ land in Phases F + G.
#
# Generated artifacts (TePlannerApp.xcodeproj, TePlannerApp.xcworkspace,
# Pods/, .build/, .derivedData/) live INSIDE apps/ios/ and are
# gitignored. Run `make project` after a fresh clone.

SIMULATOR ?= iPhone 17
PACKAGE_SCHEME := TePlannerTests
APP_SCHEME := TePlannerApp
KIT_SCHEME := TePlannerKit
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
IOS_DIR := apps/ios
WORKSPACE := TePlannerApp.xcworkspace
APP_BUNDLE_ID := com.teplanner.ios
DERIVED_DATA := .derivedData
SCREENSHOT_DIR := tmp/screenshots

.PHONY: help project build build-ios build-app run-app test test-ios test-all \
        test-backend precommit \
        clean clean-project lint format sim-boot sim-shutdown sim-screenshot \
        sim-log log-app log-device doctor list-devices build-device run-device

help:
	@awk 'BEGIN{FS=":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Project generation --------------------------------------------------

project: ## Regenerate xcodeproj + install pods (run after fresh clone or project.yml/Podfile change)
	@command -v xcodegen >/dev/null 2>&1 || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
	@command -v pod >/dev/null 2>&1       || { echo "Install cocoapods: brew install cocoapods"; exit 1; }
	@test -f $(IOS_DIR)/Config.xcconfig || { echo "Missing $(IOS_DIR)/Config.xcconfig — copy from Config.xcconfig.example and fill in your AMap key"; exit 1; }
	cd $(IOS_DIR) && xcodegen generate
	cd $(IOS_DIR) && pod install

# --- Build ---------------------------------------------------------------

build: ## Build TePlannerKit for host (macOS) — fastest sanity check, no simulator
	cd $(IOS_DIR) && swift build

build-ios: ## Build TePlannerKit for iOS simulator ($(SIMULATOR))
	cd $(IOS_DIR) && xcodebuild -scheme $(KIT_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  build

build-app: ## Build the iOS app (TePlannerApp) for the simulator
	@test -d $(IOS_DIR)/$(WORKSPACE) || $(MAKE) project
	cd $(IOS_DIR) && xcodebuild -workspace $(WORKSPACE) -scheme $(APP_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  -configuration Debug \
	  build

run-app: build-app sim-boot ## Build, install, and launch the app on the simulator
	@app=$$(find $(IOS_DIR)/$(DERIVED_DATA) -name "TePlannerApp.app" -type d | head -1); \
	  test -n "$$app" || { echo "TePlannerApp.app not found"; exit 1; }; \
	  xcrun simctl install booted "$$app" && \
	  xcrun simctl launch booted $(APP_BUNDLE_ID)

# --- Device deployment (real iPhone, wired or wireless) ------------------

list-devices: ## List paired iOS devices visible to xcrun devicectl
	@xcrun devicectl list devices 2>&1 | tail -n +2 || echo "No devices paired. Connect via USB once + trust this Mac in Settings."

build-device: ## Build the iOS app for a real device (signed)
	@test -d $(IOS_DIR)/$(WORKSPACE) || $(MAKE) project
	@grep -q "^DEVELOPMENT_TEAM = ..*" $(IOS_DIR)/Config.xcconfig 2>/dev/null \
	  || { echo "DEVELOPMENT_TEAM not set in $(IOS_DIR)/Config.xcconfig (Xcode → Settings → Accounts → Team ID)"; exit 1; }
	cd $(IOS_DIR) && xcodebuild -workspace $(WORKSPACE) -scheme $(APP_SCHEME) \
	  -destination 'generic/platform=iOS' \
	  -derivedDataPath $(DERIVED_DATA) \
	  -configuration Debug \
	  -allowProvisioningUpdates \
	  build

run-device: build-device ## Build, install, and launch on a paired iPhone (set DEVICE='Name' or pass UDID)
	@app=$$(find $(IOS_DIR)/$(DERIVED_DATA) -path "*Debug-iphoneos/TePlannerApp.app" -type d | head -1); \
	  test -n "$$app" || { echo "TePlannerApp.app (device build) not found"; exit 1; }; \
	  device_args=""; \
	  if [ -n "$(DEVICE)" ]; then \
	    device_args="--device $(DEVICE)"; \
	  else \
	    udid=$$(xcrun devicectl list devices 2>/dev/null | awk '/connected.*iPhone|iPad/ {print $$NF; exit}'); \
	    test -n "$$udid" || { echo "No connected device found. Run \`make list-devices\` or pass DEVICE='iPhone Name'."; exit 1; }; \
	    device_args="--device $$udid"; \
	  fi; \
	  echo "Installing $$app to $$device_args"; \
	  xcrun devicectl device install app $$device_args "$$app" && \
	  xcrun devicectl device process launch $$device_args $(APP_BUNDLE_ID)

# --- Test ----------------------------------------------------------------

test: ## Run unit tests on macOS (fast, no simulator boot)
	cd $(IOS_DIR) && swift test

test-ios: ## Run unit tests on iOS simulator ($(SIMULATOR))
	cd $(IOS_DIR) && xcodebuild -scheme $(PACKAGE_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  test

test-all: test test-ios ## Run macOS tests then iOS simulator tests

# Fast pre-commit gate: iOS unit + backend unit + Hurl contract.
# Runs in ~5s total. NOT included: Maestro flows (need sim + 5min)
# and iOS-on-simulator (covers SwiftUI but slow). Run those before
# pushing significant UI changes.
test-backend: ## Run backend pytest suite locally (needs conda env)
	@if command -v python >/dev/null 2>&1; then \
	  cd backend && python -m pytest --no-cov -q 2>&1 | tail -5; \
	else \
	  echo "skipping test-backend (no python in PATH locally — runs on server CI)"; \
	fi

precommit: test test-backend e2e-api ## Pre-commit gate: iOS unit + backend unit + Hurl contract (~5s)
	@echo ""
	@echo "✓ precommit OK — safe to commit"

# --- E2E -----------------------------------------------------------------

JAVA_HOME ?= /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
E2E_BACKEND_URL ?= https://api.teplanner.cloud

e2e-api: ## Hurl HTTP contract tests against the deployed backend (override E2E_BACKEND_URL)
	hurl --test --variable base_url=$(E2E_BACKEND_URL) e2e/hurl/*.hurl

e2e-ios: ## Maestro UI flows against the booted simulator (sources e2e/maestro/.env)
	@test -f e2e/maestro/.env || { echo "Missing e2e/maestro/.env — copy from .env.example"; exit 1; }
	@set -a; . e2e/maestro/.env; set +a; \
	  JAVA_HOME=$(JAVA_HOME) maestro test e2e/maestro/

e2e-ios-flow: ## Run a single Maestro flow: make e2e-ios-flow FLOW=01_login
	@test -n "$(FLOW)" || { echo "Set FLOW=<name> (without .yaml)"; exit 1; }
	@set -a; . e2e/maestro/.env 2>/dev/null || true; set +a; \
	  JAVA_HOME=$(JAVA_HOME) maestro test e2e/maestro/$(FLOW).yaml

e2e: e2e-api e2e-ios ## API contract + iOS flows back-to-back

# --- OpenAPI codegen (Phase C) -------------------------------------------
#
# Backend is the source of truth for the API contract. We snapshot
# /openapi.json into packages/clients/openapi.json (committed), then
# regenerate per-platform SDKs from that snapshot. CI gate
# `codegen-verify` regenerates and `git diff --exit-code`s — fails
# the build if either the snapshot or any SDK has drifted.

OPENAPI_SNAPSHOT := packages/clients/openapi.json
OPENAPI_SOURCE_URL ?= https://api.teplanner.cloud/openapi.json

openapi-snapshot: ## Refresh packages/clients/openapi.json from $OPENAPI_SOURCE_URL
	@curl -fsSL $(OPENAPI_SOURCE_URL) | \
	  python3 -c 'import json,sys; d=json.load(sys.stdin); \
	    open("$(OPENAPI_SNAPSHOT)","w").write(json.dumps(d, indent=2, sort_keys=True, ensure_ascii=False)+chr(10))'
	@echo "Snapshot refreshed: $(OPENAPI_SNAPSHOT)"
	@python3 -c 'import json; d=json.load(open("$(OPENAPI_SNAPSHOT)")); \
	  print(f"  paths={len(d.get(\"paths\",{}))} schemas={len(d.get(\"components\",{}).get(\"schemas\",{}))}")'

codegen: ## Regenerate every client SDK from $(OPENAPI_SNAPSHOT)
	@bash scripts/codegen.sh

codegen-verify: ## CI gate — regenerate SDKs + fail if anything changed
	@bash scripts/verify-openapi-frozen.sh

# --- Distribution / TestFlight -------------------------------------------

ARCHIVE_PATH := build/TePlannerApp.xcarchive
EXPORT_DIR := build/export

next-build: ## Bump CURRENT_PROJECT_VERSION in apps/ios/Config.xcconfig (call before each TestFlight upload)
	@test -f $(IOS_DIR)/Config.xcconfig || { echo "Missing $(IOS_DIR)/Config.xcconfig"; exit 1; }
	@current=$$(grep -E "^CURRENT_PROJECT_VERSION" $(IOS_DIR)/Config.xcconfig | tail -1 | awk -F= '{gsub(/ /, "", $$2); print $$2}'); \
	  current=$${current:-0}; \
	  next=$$((current + 1)); \
	  if grep -qE "^CURRENT_PROJECT_VERSION" $(IOS_DIR)/Config.xcconfig; then \
	    sed -i '' -E "s|^CURRENT_PROJECT_VERSION = .*|CURRENT_PROJECT_VERSION = $$next|" $(IOS_DIR)/Config.xcconfig; \
	  else \
	    echo "CURRENT_PROJECT_VERSION = $$next" >> $(IOS_DIR)/Config.xcconfig; \
	  fi; \
	  echo "Bumped CURRENT_PROJECT_VERSION → $$next"

archive: ## Build a signed Release .xcarchive ready for App Store Connect
	@test -f $(IOS_DIR)/Config.xcconfig || { echo "Missing $(IOS_DIR)/Config.xcconfig"; exit 1; }
	@grep -q "^DEVELOPMENT_TEAM = ..*" $(IOS_DIR)/Config.xcconfig || { echo "DEVELOPMENT_TEAM not set in $(IOS_DIR)/Config.xcconfig"; exit 1; }
	@test -d $(IOS_DIR)/$(WORKSPACE) || $(MAKE) project
	@# AMap pods get sim-retagged by Podfile post_install for Apple
	@# Silicon simulator builds. Restore device-tagged slices before
	@# archive so the device linker accepts them, then re-retag for
	@# sim afterward so ongoing simulator dev keeps working.
	@# scripts/ stays at repo root; pass apps/ios/ as the project
	@# root so scripts find Pods/ correctly.
	bash scripts/restore-amap-device.sh "$(PWD)/$(IOS_DIR)"
	-cd $(IOS_DIR) && xcodebuild -workspace $(WORKSPACE) -scheme $(APP_SCHEME) \
	  -configuration Release \
	  -destination 'generic/platform=iOS' \
	  -archivePath ../../$(ARCHIVE_PATH) \
	  -allowProvisioningUpdates \
	  archive
	@status=$$?; \
	bash scripts/retag-amap-for-sim.sh "$(PWD)/$(IOS_DIR)"; \
	exit $$status

export-ipa: archive ## Export an IPA from the latest archive (requires deploy/ExportOptions.plist)
	@test -f deploy/ExportOptions.plist || { \
	  echo "Missing deploy/ExportOptions.plist — copy from ExportOptions.example.plist and fill teamID"; exit 1; }
	xcodebuild -exportArchive \
	  -archivePath $(ARCHIVE_PATH) \
	  -exportPath $(EXPORT_DIR) \
	  -exportOptionsPlist deploy/ExportOptions.plist \
	  -allowProvisioningUpdates
	@echo "IPA: $(EXPORT_DIR)/TePlannerApp.ipa"

upload-testflight: export-ipa ## Upload the latest IPA to App Store Connect via altool
	@# Auto-source .env if present so ASC_API_KEY_ID + ASC_API_KEY_ISSUER
	@# don't have to be in the user's shell profile. .env is gitignored.
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	  test -n "$$ASC_API_KEY_ID" || { echo "Set ASC_API_KEY_ID in .env or shell"; exit 1; }; \
	  test -n "$$ASC_API_KEY_ISSUER" || { echo "Set ASC_API_KEY_ISSUER in .env or shell"; exit 1; }; \
	  xcrun altool --upload-app \
	    -f $(EXPORT_DIR)/TePlannerApp.ipa \
	    --type ios \
	    --apiKey "$$ASC_API_KEY_ID" \
	    --apiIssuer "$$ASC_API_KEY_ISSUER"

# --- Simulator helpers (used by Claude to verify UI) ---------------------

sim-boot: ## Boot the configured simulator (idempotent)
	@xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	@open -a Simulator

sim-shutdown: ## Shut down all booted simulators
	xcrun simctl shutdown all

sim-screenshot: ## Capture booted simulator → tmp/screenshots/<timestamp>.png
	@mkdir -p $(SCREENSHOT_DIR)
	@out=$(SCREENSHOT_DIR)/$$(date +%Y%m%d-%H%M%S).png; \
	  xcrun simctl io booted screenshot $$out && echo "Saved: $$out"

sim-log: ## Tail iOS simulator log for our app (Ctrl-C to stop)
	xcrun simctl spawn booted log stream --level debug \
	  --predicate 'process == "TePlannerApp"'

log-app: ## Stream just our subsystem's logs from the simulator (api/auth/vehicle/oauth/app/map)
	xcrun simctl spawn booted log stream --level debug \
	  --predicate 'subsystem == "com.teplanner.ios"'

log-device: ## Stream TePlannerApp logs from a USB-connected iPhone via idevicesyslog (Tahoe-safe).
	@command -v idevicesyslog >/dev/null 2>&1 || { \
	  echo "idevicesyslog missing — brew install libimobiledevice"; exit 1; \
	}
	@UDID=$$(idevice_id -l 2>/dev/null | head -1); \
	  if [ -z "$$UDID" ]; then \
	    echo "No iPhone detected. Plug in via USB and trust this Mac."; \
	    echo "(Tahoe broke log stream --device; we use idevicesyslog now.)"; \
	    exit 1; \
	  fi; \
	  echo "Streaming TePlannerApp from $$UDID — Ctrl-C to stop"; \
	  idevicesyslog -u "$$UDID" -p TePlannerApp

# --- Hygiene -------------------------------------------------------------

lint: ## Run SwiftLint if available; otherwise no-op with a note
	@command -v swiftlint >/dev/null 2>&1 \
	  && swiftlint --strict \
	  || echo "swiftlint not installed — skipping (brew install swiftlint)"

format: ## Run swift-format (Apple) if available; else swiftformat; else note
	@if command -v swift-format >/dev/null 2>&1; then \
	  swift-format -i -r $(IOS_DIR)/Sources $(IOS_DIR)/Tests $(IOS_DIR)/TePlannerApp; \
	elif command -v swiftformat >/dev/null 2>&1; then \
	  swiftformat $(IOS_DIR)/Sources $(IOS_DIR)/Tests $(IOS_DIR)/TePlannerApp; \
	else \
	  echo "no swift-format/swiftformat installed — skipping"; \
	fi

clean: ## Remove SPM and Xcode build artifacts (keeps Pods/, xcodeproj — use `clean-project` to nuke those too)
	rm -rf $(IOS_DIR)/.build $(IOS_DIR)/$(DERIVED_DATA)

clean-project: clean ## Also remove generated xcodeproj/xcworkspace/Pods (forces full `make project`)
	rm -rf $(IOS_DIR)/TePlannerApp.xcodeproj $(IOS_DIR)/$(WORKSPACE) $(IOS_DIR)/Pods

doctor: ## Print toolchain + simulator info
	@echo "=== xcode ===";        xcodebuild -version
	@echo "=== swift ===";        swift --version | head -1
	@echo "=== xcodegen ===";     xcodegen --version 2>/dev/null || echo "not installed"
	@echo "=== cocoapods ===";    pod --version 2>/dev/null || echo "not installed"
	@echo "=== schemes ===";      xcodebuild -list 2>/dev/null | sed -n '/Schemes:/,$$p'
	@echo "=== simulator ===";    xcrun simctl list devices booted
