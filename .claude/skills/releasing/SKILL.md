# Releasing

Invoke this skill when the user says things like "prepare a release", "cut a release", "bump the version", "release X.Y.Z", or "tag a release". It codifies the exact release workflow for this project, including where the version is stored and how CI handles draft creation.

## Workflow

1. **Determine version bump**
   - PATCH for bug fixes
   - MINOR for new features
   - MAJOR for breaking changes
   - If the user specifies a version, use it directly.

2. **Bump `MARKETING_VERSION` in `project.pbxproj`**
   - File: `Claude Usage.xcodeproj/project.pbxproj`
   - Search for all occurrences of `MARKETING_VERSION` and update each to the new version.
   - This is the sole source of version truth — there is no `package.json`, `pyproject.toml`, or similar.

3. **Update `CHANGELOG.md`**
   - Follow Keep a Changelog format.
   - Add a new `## [X.Y.Z] - YYYY-MM-DD` section immediately below `## [Unreleased]`.
   - Move relevant entries from `## [Unreleased]` into the new section.
   - Leave `## [Unreleased]` in place (empty or with any entries that are not part of this release).

4. **Commit**
   ```
   chore(release): bump version to X.Y.Z
   ```
   Note: scopes are required in this repo, but release commits use this exact format without a scope after `chore`.

5. **Tag**
   ```bash
   git tag vX.Y.Z
   ```

6. **Push**
   ```bash
   git push origin main --tags
   ```

7. **Tell the user**
   CI will create a draft release in approximately 3–5 minutes. The user must review and publish it manually at:
   https://github.com/kynoptic/claude-usage-tracker/releases

## Key details

- CI trigger: `.github/workflows/release.yml` — fires on tags matching `vX.Y.Z`.
- Draft release is created automatically; publishing is a manual step.
- Remote: `origin` → `https://github.com/kynoptic/Claude-Usage-Tracker.git`
