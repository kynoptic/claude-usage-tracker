#!/usr/bin/env bash
# Pre-commit hook fragment: lint staged Swift files against the baseline.
# Installed by `make init` — appended to .git/hooks/pre-commit.

STAGED_SWIFT=$(git diff --cached --name-only --diff-filter=d | grep '\.swift$' || true)
if [ -n "$STAGED_SWIFT" ]; then
  if command -v swiftlint >/dev/null 2>&1; then
    echo "$STAGED_SWIFT" | xargs swiftlint lint --baseline .swiftlint.baseline --strict --quiet 2>/dev/null
    LINT_EXIT=$?
    if [ $LINT_EXIT -ne 0 ]; then
      echo >&2
      echo "[ERROR] SwiftLint found new violations. Fix them before committing." >&2
      echo >&2
      exit 1
    fi
  fi
fi
