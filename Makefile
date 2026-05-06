# TePlanner — single source of truth for build/test/lint commands.
# Both local Xcode + Claude Code sessions and remote dispatched
# sessions should use these targets so behavior matches everywhere.

SIMULATOR ?= iPhone 16
PACKAGE_SCHEME := TePlanner-Package
APP_SCHEME := TePlannerApp
KIT_SCHEME := TePlannerKit
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
DERIVED_DATA := .derivedData
SCREENSHOT_DIR := tmp/screenshots

.PHONY: help build build-ios test test-ios test-all clean lint format \
        sim-boot sim-shutdown sim-screenshot sim-log doctor

help:
	@awk 'BEGIN{FS=":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Build ---------------------------------------------------------------

build: ## Build everything for host (macOS) — fastest sanity check
	swift build

build-ios: ## Build TePlannerKit for iOS simulator ($(SIMULATOR))
	xcodebuild -scheme $(KIT_SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED_DATA) \
	  build

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

# --- Hygiene -------------------------------------------------------------

lint: ## Run SwiftLint if available; otherwise no-op with a note
	@command -v swiftlint >/dev/null 2>&1 \
	  && swiftlint --strict \
	  || echo "swiftlint not installed — skipping (brew install swiftlint)"

format: ## Run swift-format (Apple) if available; else swiftformat; else note
	@if command -v swift-format >/dev/null 2>&1; then \
	  swift-format -i -r Sources Tests; \
	elif command -v swiftformat >/dev/null 2>&1; then \
	  swiftformat Sources Tests; \
	else \
	  echo "no swift-format/swiftformat installed — skipping"; \
	fi

clean: ## Remove SPM and Xcode build artifacts
	rm -rf .build $(DERIVED_DATA)

doctor: ## Print toolchain + simulator info — useful when debugging dispatch
	@echo "=== xcode ===";     xcodebuild -version
	@echo "=== swift ===";     swift --version | head -1
	@echo "=== schemes ===";   xcodebuild -list 2>/dev/null | sed -n '/Schemes:/,$$p'
	@echo "=== simulator ==="; xcrun simctl list devices booted
