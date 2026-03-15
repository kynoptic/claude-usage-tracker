# Deployment and Release

This document is the single source of truth for building, deploying, and releasing Claude Usage Tracker.

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

### Why Each Step

- **Pull latest** — ensures you have the latest code before building
- **Kill first** — macOS can keep the old process in memory even after replacing the bundle
- **Nuke DerivedData** — `clean build` alone can reuse stale object files from incremental caches
- **Clean build** — ensures no stale object files or build artifacts are included
- **`rm -rf` before `cp -R`** — `cp -R` silently skips overwriting an existing `.app` directory, leaving the stale binary in place
- **`grep` not `awk`** — the `awk` pattern for `BUILT_PRODUCTS_DIR` can match the wrong line (e.g. `CODE_SIGNING_ALLOWED = YES`)
- **Relaunch** — verifies the app starts successfully

### Verification After Deploy

- App appears in menu bar within a few seconds of launch
- Click the icon — popover opens and usage data loads (not stuck on `~`)
- Settings → Claude Code shows existing statusline config, if previously configured

---

## Release

Releases are automated via GitHub Actions but require manual steps.

### Step 1: Bump Version

Edit `project.pbxproj` and update both:
- `MARKETING_VERSION` — the user-facing version (e.g., 2.4.3)
- `CURRENT_PROJECT_VERSION` — the build number (increment by 1)

### Step 2: Update CHANGELOG

Add a new section at the top of `CHANGELOG.md`:

```markdown
## [2.5.0] - 2026-03-15

### Added
- Feature description

### Fixed
- Bug fix description

### Changed
- Change description
```

### Step 3: Commit and Tag

```bash
# Commit with sign-off
git commit -S -m "$(cat <<'EOF'
chore(release): v2.5.0

- Bump MARKETING_VERSION to 2.5.0
- Update CHANGELOG.md with release notes
EOF
)"

# Tag the commit (annotated, signed)
git tag -a -s v2.5.0 -m "Release v2.5.0"

# Push to fork
git push origin main
git push origin v2.5.0
```

### Step 4: GitHub Actions Workflow

The CI workflow (`/.github/workflows/release.yml`) automatically:
1. Detects the new tag
2. Builds the Release configuration
3. Creates a GitHub release with the built `.app` bundle
4. Uploads the `.app` as a draft release asset

### Step 5: Publish Release

1. Go to [Releases](https://github.com/kynoptic/Claude-Usage-Tracker/releases)
2. Find the draft release for your tag
3. Edit the description to match the CHANGELOG section
4. Click **Publish release**

Users can now download the `.app` from the release page.

---

## Build Commands for Reference

### Debug Build

```bash
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Release Build

```bash
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Run Tests

```bash
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### Screenshot Tests (Headless)

```bash
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" \
  -only-testing:"Claude UsageTests/ScreenshotTests" \
  -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

PNGs are written to `.screenshots/`. Open with: `open .screenshots/<name>.png`

---

## Related Docs

- [CLAUDE.md](../../CLAUDE.md) — Project instructions and build environment
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — Contribution guidelines
- [GitHub Actions Workflows](../../.github/workflows/) — CI/CD automation
