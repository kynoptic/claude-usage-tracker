# ADR-006: Remove CodeQL workflow

**Status:** Accepted
**Date:** 2026-03-09

## Context

The repository inherited a CodeQL Advanced workflow that ran on every push and PR. It consistently failed because it used `macos-latest` (default Xcode) while the build requires Xcode 16 for Swift 6 concurrency rules. Each run consumed ~20 minutes of GitHub Actions macOS minutes.

## Decision

Delete the CodeQL workflow. Run CodeQL locally via the CLI when needed.

```bash
brew install codeql
codeql database create codeql-db --language=swift \
  --command='xcodebuild build -project "Claude Usage.xcodeproj" \
    -scheme "Claude Usage" -configuration Debug \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO' \
  --overwrite
codeql database analyze codeql-db \
  --format=sarif-latest --output=codeql-results.sarif \
  codeql/swift-queries:codeql-suites/swift-security-extended.qls
```

## Rationale

The app's attack surface is narrow: it reads `~/.claude/` and calls an HTTPS API. It has no SQL, no web rendering, no shell execution, and no user-controlled file paths — the primary classes of vulnerabilities CodeQL catches. The cost/benefit does not justify automated CI runs.

## Consequences

- No automated security scanning on push/PR — compensated by narrow attack surface and code review
- Re-enable if the app gains shell execution, file writes outside `~/.claude/`, or user-controlled input reaching dangerous sinks
