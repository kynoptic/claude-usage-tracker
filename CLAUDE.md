# Claude Usage Tracker

Native macOS menu bar app (macOS 14.0+ / Sonoma) for real-time Claude AI usage monitoring. Built with Swift 5.0+ and SwiftUI, using Xcode 16+.

## Build & test

```bash
# Build (Debug)
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build (Release)
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

CI runs on `macos-15` (Xcode 16 required for `PBXFileSystemSynchronizedRootGroup` format). Code signing is disabled — open source, no Apple Developer certificate.

## Architecture

MVVM pattern. Keep views "dumb" — display only, no business logic.

```text
Claude Usage/
├── App/              # Entry point, lifecycle
├── MenuBar/          # Status item, popover UI, MenuBarManager (ViewModel)
├── Views/            # Settings, SetupWizard
└── Shared/
    ├── Models/       # Pure Swift data structs (ClaudeUsage, ClaudeStatus)
    ├── Services/     # API, notifications, statusline (async/await)
    ├── Storage/      # DataStore (UserDefaults wrapper)
    ├── Extensions/   # Date, UserDefaults helpers
    └── Utilities/    # Constants, FormatterHelper
```

Business logic belongs in managers/services. Prefer `async/await` over completion handlers.

## Code conventions

- Organize with `// MARK: -` sections (Properties → Initialization → Public Methods → Private Methods)
- Structs for data models (`Codable`, `Equatable`); enums for constants
- Use Swift type inference where unambiguous
- Document public APIs with doc comments (`///`)
- Extract complex SwiftUI sub-views into named structs

## Git

Follow `CONTRIBUTING.md` for all development conventions. The following **override global defaults**:

**Issue and PR templates:** Use the templates in `.github/` for work on this fork. If contributing to upstream, follow the lighter format described in `CONTRIBUTING.md` (macOS version, steps to reproduce, expected vs actual, screenshots, Console logs) — do not use our templates there.

**Commits:** `<type>(<scope>): <description>` — scopes are required here (overrides global no-scope rule)

Common scopes: `api`, `menubar`, `statusline`, `settings`, `services`, `models`, `ui`

**Branches:** `feat/`, `fix/`, `docs/`, `refactor/`, `chore/` prefixes (overrides global `issue-<id>-<slug>` convention)

**Remote:** `origin` → `https://github.com/kynoptic/Claude-Usage-Tracker.git` (your fork)

> [!CAUTION]
> **This is a fork.** All work — commits, issues, PRs, releases — happens exclusively on this fork (`kynoptic/claude-usage-tracker`).
> **NEVER push, open PRs, file issues, or interact with upstream or any other fork in any way.** Upstream and other forks are read-only references for ideas and cherry-picks only.

**`gh` CLI guard:** `gh repo set-default kynoptic/claude-usage-tracker` is configured so `gh pr create`, `gh issue create`, etc. target the fork — not the upstream. If `gh` ever prompts to choose a repo, always pick the fork. When using `gh` commands that accept `--repo`, pass `--repo kynoptic/claude-usage-tracker` explicitly as a safety net.

**Upstream and other forks** (`hamed-elfayome/Claude-Usage-Tracker`, `tsvikas`, others) are read-only references for ideas and inspiration. Cherry-picks and patches are possible but require manual porting — the architectures have diverged too far for clean applies. Always evaluate against our codebase before attempting.

## Deploy to /Applications

Full clean deploy — every step matters. Skipping any step risks shipping a stale binary.

```bash
# 1. Pull latest
git pull origin main

# 2. Quit the running app
kill $(pgrep -f "Claude Usage") 2>/dev/null; sleep 1

# 3. Nuke DerivedData to prevent stale object files
rm -rf ~/Library/Developer/Xcode/DerivedData/Claude_Usage-*

# 4. Clean build from scratch
xcodebuild clean build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 5. Locate the built product
DERIVED=$(xcodebuild -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release \
  -showBuildSettings CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  | grep '^\s*BUILT_PRODUCTS_DIR = ' | head -1 | sed 's/.*= //')

# 6. Remove old bundle, copy new, relaunch
rm -rf "/Applications/Claude Usage.app"
cp -R "$DERIVED/Claude Usage.app" "/Applications/"
open "/Applications/Claude Usage.app"
```

**Why each step:**

- **Kill first**: macOS can keep the old process in memory even after replacing the bundle.
- **Nuke DerivedData**: `clean build` alone can reuse stale object files from incremental caches.
- **`rm -rf` before `cp -R`**: `cp -R` silently skips overwriting an existing `.app` directory, leaving the stale binary in place.
- **`grep` not `awk`**: The `awk` pattern for `BUILT_PRODUCTS_DIR` can match the wrong line (e.g. `CODE_SIGNING_ALLOWED = YES`).

## Viewing UI without a display

The environment lacks display access (`screencapture` fails headlessly). Use `ScreenshotTests` to render SwiftUI views to PNG via `ImageRenderer`:

```bash
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" \
  -only-testing:"Claude UsageTests/ScreenshotTests" \
  -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

PNGs are written to `.screenshots/` at the project root. Open them with:

```bash
open .screenshots/<name>.png
```

Add a temporary test to `ScreenshotTests.swift` for the view you want to inspect — remove it after verification. `ImageRenderer` returns `nil` in fully headless CI (no GPU), but works in local terminal sessions.

## Release

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj`
2. Update `CHANGELOG.md`
3. Commit: `chore(release): bump version to X.Y.Z`
4. Tag: `git tag -a vX.Y.Z -m "<summary>" && git push origin main && git push origin vX.Y.Z`
5. Create release: `gh release create vX.Y.Z --title "vX.Y.Z" --notes "<changelog body>"`
