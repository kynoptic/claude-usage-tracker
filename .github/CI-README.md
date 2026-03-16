# GitHub Configuration

Internal reference for CI/CD workflows and GitHub configuration.

## Workflows

### `build.yml` — Continuous Integration

**Triggers:** PRs to `main`, pushes to `main`

**Purpose:** Validate that code compiles and tests pass before merge.

**Steps:**
1. Build Debug configuration (required for test host)
2. Run unit tests (`xcodebuild test`)
3. Build Release configuration
4. Upload `.app` artifact (7-day retention)

**Why `macos-15`:** The project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16 feature). This project format requires Xcode 16+, which is only available on `macos-15` runners.

**Why code signing is disabled:** The app is unsigned (no Apple Developer certificate). Build flags bypass signing:
```
CODE_SIGN_IDENTITY=""
CODE_SIGNING_REQUIRED=NO
CODE_SIGNING_ALLOWED=NO
```

---

### `release.yml` — Automated Releases

**Triggers:** Push of tags matching `v*` (e.g., `v1.5.0`)

**Purpose:** Build release artifacts and create GitHub Release.

**Steps:**
1. Build Release configuration
2. Create `Claude-Usage.zip` from `.app` bundle
3. Generate `Claude-Usage.zip.sha256` checksum
4. Create draft GitHub Release with assets attached

**Outputs:**
- `Claude-Usage.zip` — App bundle for distribution
- `Claude-Usage.zip.sha256` — SHA256 checksum for verification

**Why draft releases:** Allows maintainer to review auto-generated notes, add context, screenshots, or highlights before publishing.

---

### `generate-appcast.yml` — Sparkle Appcast

**Triggers:** Release published, manual dispatch (`workflow_dispatch`)

**Purpose:** Regenerate the Sparkle appcast XML so users with automatic updates receive the release.

**Steps:**

1. Determine release tag (from event or manual input; defaults to latest)
2. Check out `gh-pages` branch
3. Download Sparkle 2.8.1 tools
4. Download the `Claude-Usage.zip` release asset
5. Extract `Info.plist` version metadata from the app bundle
6. Run `generate_appcast` with EdDSA signing (key piped via stdin)
7. Commit updated `appcast.xml` and release archive to `gh-pages`
8. Verify the appcast URL is accessible on GitHub Pages

**Secrets required:**

- `SPARKLE_PRIVATE_KEY` — EdDSA private key for signing appcast entries
- `RELEASE_TOKEN` — PAT with push access to `gh-pages`

**Output:** `https://kynoptic.github.io/Claude-Usage-Tracker/appcast.xml`

---

### `update-homebrew-cask.yml` — Homebrew Tap (disabled)

**Triggers:** Manual dispatch only (`workflow_dispatch`)

**Status:** Disabled. No Homebrew tap (`kynoptic/homebrew-claude-usage`) exists yet. Re-enable the release trigger and configure the tap repository before use.

**Purpose:** Update the Homebrew cask formula with the new version and SHA256 checksum after a release.

**Steps:**

1. Extract version from release tag
2. Download `Claude-Usage.zip` and compute SHA256
3. Check out `kynoptic/homebrew-claude-usage` tap repository
4. Update `Casks/claude-usage-tracker.rb` with new version and hash
5. Commit and push to the tap

**Secrets required:**

- `HOMEBREW_TAP_TOKEN` — PAT with push access to the tap repository

---

## Release Process

```bash
# 1. Bump MARKETING_VERSION in project.pbxproj
# 2. Update CHANGELOG.md
# 3. Commit
git commit -am "chore: bump version to X.Y.Z"

# 4. Tag and push
git tag vX.Y.Z
git push github main --tags

# 5. Workflow runs (~3-5 min)
# 6. Review draft release at github.com/.../releases
# 7. Edit notes if needed, click Publish
```

---

## Technical Constraints

| Constraint | Reason |
|------------|--------|
| `macos-15` runner | Xcode 16 required for project format |
| No code signing | Open source, no Apple Developer certificate |
| Debug build before tests | Test target needs `TEST_HOST` from Debug build |
| 20-min timeout | Prevents hung builds from consuming minutes |

---

## Issue Templates

- `bug_report.yml` — Structured bug reports with version/OS fields
- `feature_request.yml` — Feature suggestions with problem/solution format
- `documentation.yml` — Documentation improvements
- `config.yml` — Links to Discussions for questions
