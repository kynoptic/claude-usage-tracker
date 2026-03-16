.PHONY: help init build build-release test lint deploy clean

# Build configuration (matches CLAUDE.md requirements)
PROJECT = Claude Usage.xcodeproj
SCHEME = Claude Usage
XCODE_FLAGS = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
DERIVED_DATA_PATTERN = ~/Library/Developer/Xcode/DerivedData/Claude_Usage-*
APP_NAME = Claude Usage
APP_BUNDLE = $(APP_NAME).app
APPS_DIR = /Applications

help:
	@echo "Claude Usage Tracker — Makefile targets"
	@echo ""
	@echo "  make init           Check Xcode 16+ and git configuration"
	@echo "  make build          Debug build (code signing disabled)"
	@echo "  make build-release  Release build"
	@echo "  make test           Run unit tests"
	@echo "  make lint           Run SwiftLint (new violations only via baseline)"
	@echo "  make deploy         Deploy to /Applications (clean full deploy)"
	@echo "  make clean          Clean build artifacts and DerivedData"
	@echo ""

# Check Xcode 16+ and verify git remote configuration
init:
	@echo "Checking Xcode version..."
	@xcode_version=$$(xcodebuild -version | grep Xcode | awk '{print $$2}'); \
	major_version=$$(echo $$xcode_version | cut -d. -f1); \
	if [ $$major_version -lt 16 ]; then \
		echo "❌ Xcode 16+ required (found: $$xcode_version)"; \
		exit 1; \
	fi; \
	echo "✓ Xcode $$xcode_version"
	@echo ""
	@echo "Checking git remote configuration..."
	@if ! git remote | grep -q github; then \
		echo "❌ 'github' remote not found"; \
		exit 1; \
	fi; \
	echo "✓ 'github' remote configured"
	@echo ""
	@echo "Resolving SPM dependencies..."
	@xcodebuild -resolvePackageDependencies \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		> /dev/null 2>&1 && echo "✓ SPM dependencies resolved" || echo "⚠ SPM resolution failed — try opening Xcode once to resolve"
	@echo ""
	@echo "Installing pre-commit hooks..."
	@pre-commit install --hook-type commit-msg > /dev/null 2>&1 && echo "✓ pre-commit hooks installed" || echo "⚠ pre-commit not found — run: pip install pre-commit"
	@echo ""
	@echo "Installing SwiftLint pre-commit hook..."
	@if [ -f .git/hooks/pre-commit ] && ! grep -q 'swiftlint' .git/hooks/pre-commit; then \
		cat scripts/swiftlint-precommit.sh >> .git/hooks/pre-commit; \
		echo "✓ SwiftLint pre-commit hook appended"; \
	elif ! [ -f .git/hooks/pre-commit ]; then \
		echo "#!/usr/bin/env bash" > .git/hooks/pre-commit; \
		cat scripts/swiftlint-precommit.sh >> .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "✓ SwiftLint pre-commit hook created"; \
	else \
		echo "✓ SwiftLint pre-commit hook already present"; \
	fi
	@echo ""
	@echo "✓ Init checks passed"

# Debug build (xcodebuild flags from CLAUDE.md)
build:
	@echo "Building Debug configuration..."
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		$(XCODE_FLAGS)
	@echo "✓ Debug build complete"

# Release build (xcodebuild flags from CLAUDE.md)
build-release:
	@echo "Building Release configuration..."
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		$(XCODE_FLAGS)
	@echo "✓ Release build complete"

# Run unit tests (debug configuration)
test:
	@echo "Running unit tests..."
	xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		$(XCODE_FLAGS) \
		-skip-testing:"Claude UsageTests/KeychainServiceTests" \
		-skip-testing:"Claude UsageTests/KeychainServicePerProfileTests" \
		-skip-testing:"Claude UsageTests/KeychainPerProfileMigrationServiceTests"
	@echo "✓ Tests passed"

# Run SwiftLint with baseline (reports only new violations)
lint:
	@echo "Running SwiftLint..."
	swiftlint lint --baseline .swiftlint.baseline --strict
	@echo "✓ No new SwiftLint violations"

# Deploy to /Applications (full clean deploy per docs/procedures/DEPLOY.md)
# Each step is critical — skipping any risks shipping a stale binary.
deploy: build-release
	@echo "Deploying to /Applications..."
	@echo ""
	@echo "Step 1: Pull latest from github..."
	git pull github main
	@echo ""
	@echo "Step 2: Killing running app instance..."
	@kill $$(pgrep -f "$(APP_NAME)") 2>/dev/null; sleep 1 || true
	@echo ""
	@echo "Step 3: Nuking DerivedData to prevent stale object files..."
	@rm -rf $(DERIVED_DATA_PATTERN)
	@echo ""
	@echo "Step 4: Clean build from scratch..."
	xcodebuild clean build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		$(XCODE_FLAGS)
	@echo ""
	@echo "Step 5: Locating built product..."
	@DERIVED=$$(xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-showBuildSettings \
		$(XCODE_FLAGS) \
		| grep '^\s*BUILT_PRODUCTS_DIR = ' | head -1 | sed 's/.*= //'); \
	echo "Build products at: $$DERIVED"; \
	echo ""; \
	echo "Step 6: Removing old bundle and copying new..."; \
	rm -rf "$(APPS_DIR)/$(APP_BUNDLE)"; \
	cp -R "$$DERIVED/$(APP_BUNDLE)" "$(APPS_DIR)/"; \
	echo ""; \
	echo "Step 7: Relaunching app..."; \
	open "$(APPS_DIR)/$(APP_BUNDLE)"
	@echo ""
	@echo "✓ Deploy complete"
	@echo ""
	@echo "Verification checklist:"
	@echo "  • App appears in menu bar within a few seconds"
	@echo "  • Click icon — popover opens and usage data loads"
	@echo "  • Settings → Claude Code shows statusline config"

# Clean build artifacts and DerivedData
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild clean \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)"
	@echo ""
	@echo "Cleaning DerivedData..."
	@rm -rf $(DERIVED_DATA_PATTERN)
	@echo "✓ Clean complete"
