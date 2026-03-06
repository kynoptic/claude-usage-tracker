#!/usr/bin/env bash
set -euo pipefail

# Screenshot verification workflow for visual regression checking.
#
# Usage:
#   ./scripts/screenshot-check.sh before   # Capture baseline screenshots
#   ./scripts/screenshot-check.sh after    # Capture post-change screenshots
#   ./scripts/screenshot-check.sh compare  # List before/after pairs for review
#   ./scripts/screenshot-check.sh clean    # Remove all screenshot artifacts

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_ROOT/.screenshots"
BEFORE_DIR="$SCREENSHOTS_DIR/before"
AFTER_DIR="$SCREENSHOTS_DIR/after"

XCODEBUILD_FLAGS=(
    -project "$PROJECT_ROOT/Claude Usage.xcodeproj"
    -scheme "Claude Usage"
    -only-testing:"Claude UsageTests/ScreenshotTests"
    -configuration Debug
    CODE_SIGN_IDENTITY=""
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=NO
)

run_tests() {
    echo "Running screenshot tests..."
    if ! xcodebuild test "${XCODEBUILD_FLAGS[@]}" 2>&1 | tail -40; then
        echo "Error: Screenshot tests failed. Check output above."
        return 1
    fi
    echo ""
}

copy_screenshots() {
    local dest="$1"
    local label="$2"
    mkdir -p "$dest"
    cp "$SCREENSHOTS_DIR"/*.png "$dest/" 2>/dev/null || true
    local count
    count=$(find "$dest" -name '*.png' | wc -l | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        echo "Warning: No screenshots were generated."
        return 1
    fi
    echo "Captured $count $label screenshots in $dest"
}

cmd_before() {
    rm -rf "$BEFORE_DIR"
    run_tests
    copy_screenshots "$BEFORE_DIR" "baseline"
}

cmd_after() {
    rm -rf "$AFTER_DIR"
    run_tests
    copy_screenshots "$AFTER_DIR" "post-change"
}

cmd_compare() {
    if [ ! -d "$BEFORE_DIR" ] || [ ! -d "$AFTER_DIR" ]; then
        echo "Error: Run 'before' and 'after' first."
        exit 1
    fi

    local has_before has_after
    has_before=$(find "$BEFORE_DIR" -name '*.png' | wc -l | tr -d ' ')
    has_after=$(find "$AFTER_DIR" -name '*.png' | wc -l | tr -d ' ')
    if [ "$has_before" -eq 0 ] && [ "$has_after" -eq 0 ]; then
        echo "No screenshots found in either directory."
        exit 1
    fi

    echo "Screenshot pairs for review:"
    echo "─────────────────────────────"
    for before_file in "$BEFORE_DIR"/*.png; do
        [ -f "$before_file" ] || continue
        local name after_file
        name=$(basename "$before_file")
        after_file="$AFTER_DIR/$name"
        if [ -f "$after_file" ]; then
            local before_size after_size  # re-declared each iteration; harmless in bash
            before_size=$(stat -f%z "$before_file" 2>/dev/null || stat -c%s "$before_file")
            after_size=$(stat -f%z "$after_file" 2>/dev/null || stat -c%s "$after_file")
            if [ "$before_size" = "$after_size" ]; then
                echo "  $name  (same size: ${before_size}B)"
            else
                echo "  $name  (before: ${before_size}B → after: ${after_size}B) ← CHANGED"
            fi
        else
            echo "  $name  ← REMOVED (no after)"
        fi
    done

    # Check for new screenshots
    for after_file in "$AFTER_DIR"/*.png; do
        [ -f "$after_file" ] || continue
        local name
        name=$(basename "$after_file")
        if [ ! -f "$BEFORE_DIR/$name" ]; then
            echo "  $name  ← NEW"
        fi
    done
}

cmd_clean() {
    rm -rf "$SCREENSHOTS_DIR"
    echo "Cleaned .screenshots/"
}

case "${1:-}" in
    before)  cmd_before ;;
    after)   cmd_after ;;
    compare) cmd_compare ;;
    clean)   cmd_clean ;;
    *)
        echo "Usage: $0 {before|after|compare|clean}"
        echo ""
        echo "  before   Capture baseline screenshots"
        echo "  after    Capture post-change screenshots"
        echo "  compare  List before/after pairs for review"
        echo "  clean    Remove all screenshot artifacts"
        exit 1
        ;;
esac
