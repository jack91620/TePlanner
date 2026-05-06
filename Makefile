# TePlanner — single source of truth for build/test/lint commands.
# Local Xcode work AND CLI/Claude sessions go through these targets so
# behavior is identical everywhere.
#
# Project structure:
#   - Sources/TePlannerKit + Tests are pure SPM (fast macOS tests).
#   - TePlannerApp/ is the iOS app target — driven by xcodegen + cocoapods,
#     pulls in AMap iOS SDK + the TePlannerKit SPM library.
#
# Generated artifacts (TePlannerApp.xcodeproj, TePlannerApp.xcworkspace,
# Pods/) are gitignored. Run `make project` after a fresh clone.

SIMULATOR ?= iPhone 16
PACKAGE_SCHEME := TePlanner-Package
APP_SCHEME := TePlannerApp
KIT_SCHEME := TePlannerKit
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
WORKSPACE := TePlannerApp.xcworkspace
APP_BUNDLE_ID := com.teplanner.ios
DERIVED_DATA := .derivedData
SCREENSHOT_DIR := tmp/screenshots

.PHONY: help project build build-ios build-app run-app test test-ios test-all \
        clean clean-project lint format sim-boot sim-shutdown sim-screenshot \
        sim-log log-app log-device doctor list-devices build-device run-device

help:
	@awk 'BEGIN{FS=":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Project generation --------------------------------------------------

project: ## Regenerate xcodeproj + install pods (run after fresh clone or project.yml/Podfile change)
	@command -v xcodegen >/dev/null 2>&1 || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
	@command -v pod >/dev/null 2>&1       || { echo "Install cocoapods: brew install cocoapods"; exit 1; }
	@test -f Config.xcconfig || { echo "Missing Config.xcconfig — copy from Config.xcconfig.example and fill in your AMap key"; exit 1; }
	xcodegen generate
	pod install

# --- Build ---------------------------------------------------------------

build: ## Build TePlannerKit for host (macOS) — fastest sanity check, no simulator
	swift build

build-ios: ## Build TePlannerKit for iOS simulator ($(SIMULATOR))
	xcodebuild -scheme $(KIT_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  build

build-app: ## Build the iOS app (TePlannerApp) for the simulator
	@test -d $(WORKSPACE) || $(MAKE) project
	xcodebuild -workspace $(WORKSPACE) -scheme $(APP_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  -configuration Debug \
	  build

run-app: build-app sim-boot ## Build, install, and launch the app on the simulator
	@app=$$(find $(DERIVED_DATA) -name "TePlannerApp.app" -type d | head -1); \
	  test -n "$$app" || { echo "TePlannerApp.app not found"; exit 1; }; \
	  xcrun simctl install booted "$$app" && \
	  xcrun simctl launch booted $(APP_BUNDLE_ID)

# --- Device deployment (real iPhone, wired or wireless) ------------------

list-devices: ## List paired iOS devices visible to xcrun devicectl
	@xcrun devicectl list devices 2>&1 | tail -n +2 || echo "No devices paired. Connect via USB once + trust this Mac in Settings."

build-device: ## Build the iOS app for a real device (signed)
	@test -d $(WORKSPACE) || $(MAKE) project
	@grep -q "^DEVELOPMENT_TEAM = ..*" Config.xcconfig 2>/dev/null \
	  || { echo "DEVELOPMENT_TEAM not set in Config.xcconfig (Xcode → Settings → Accounts → Team ID)"; exit 1; }
	xcodebuild -workspace $(WORKSPACE) -scheme $(APP_SCHEME) \
	  -destination 'generic/platform=iOS' \
	  -derivedDataPath $(DERIVED_DATA) \
	  -configuration Debug \
	  -allowProvisioningUpdates \
	  build

run-device: build-device ## Build, install, and launch on a paired iPhone (set DEVICE='Name' or pass UDID)
	@app=$$(find $(DERIVED_DATA) -path "*Debug-iphoneos/TePlannerApp.app" -type d | head -1); \
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
	  xcrun devicectl device process launch $$device_args --start-stopped=false $(APP_BUNDLE_ID)

# --- Test ----------------------------------------------------------------

test: ## Run unit tests on macOS (fast, no simulator boot)
	swift test

test-ios: ## Run unit tests on iOS simulator ($(SIMULATOR))
	xcodebuild -scheme $(PACKAGE_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  test

test-all: test test-ios ## Run macOS tests then iOS simulator tests

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

log-device: ## Stream our subsystem's logs from a paired iPhone (USB or Wi-Fi). Set DEVICE='Name'.
	@if [ -z "$(DEVICE)" ]; then \
	  echo "Set DEVICE='iPhone Name' (find with \`make list-devices\`)"; exit 1; \
	fi
	log stream --device '$(DEVICE)' --level debug \
	  --predicate 'subsystem == "com.teplanner.ios"'

# --- Hygiene -------------------------------------------------------------

lint: ## Run SwiftLint if available; otherwise no-op with a note
	@command -v swiftlint >/dev/null 2>&1 \
	  && swiftlint --strict \
	  || echo "swiftlint not installed — skipping (brew install swiftlint)"

format: ## Run swift-format (Apple) if available; else swiftformat; else note
	@if command -v swift-format >/dev/null 2>&1; then \
	  swift-format -i -r Sources Tests TePlannerApp; \
	elif command -v swiftformat >/dev/null 2>&1; then \
	  swiftformat Sources Tests TePlannerApp; \
	else \
	  echo "no swift-format/swiftformat installed — skipping"; \
	fi

clean: ## Remove SPM and Xcode build artifacts (keeps Pods/, xcodeproj — use `clean-project` to nuke those too)
	rm -rf .build $(DERIVED_DATA)

clean-project: clean ## Also remove generated xcodeproj/xcworkspace/Pods (forces full `make project`)
	rm -rf TePlannerApp.xcodeproj $(WORKSPACE) Pods

doctor: ## Print toolchain + simulator info
	@echo "=== xcode ===";        xcodebuild -version
	@echo "=== swift ===";        swift --version | head -1
	@echo "=== xcodegen ===";     xcodegen --version 2>/dev/null || echo "not installed"
	@echo "=== cocoapods ===";    pod --version 2>/dev/null || echo "not installed"
	@echo "=== schemes ===";      xcodebuild -list 2>/dev/null | sed -n '/Schemes:/,$$p'
	@echo "=== simulator ===";    xcrun simctl list devices booted
