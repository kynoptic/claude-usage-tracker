# Releasing

<!-- This skill is the automation layer for releases. The authoritative
     procedure with rationale lives in docs/procedures/DEPLOY.md.
     Post-release verification and troubleshooting are in RELEASING.md. -->

Invoke this skill when the user says things like "prepare a release", "cut a release", "bump the version", "release X.Y.Z", or "tag a release". It codifies the exact release workflow for this project, including where the version is stored and how CI handles draft creation.

## Workflow

1. **Determine version bump**
   - PATCH for bug fixes
   - MINOR for new features
   - MAJOR for breaking changes
   - If the user specifies a version, use it directly.

2. **Bump version numbers in `project.pbxproj`**
   - File: `Claude Usage.xcodeproj/project.pbxproj`
   - Update all occurrences of `MARKETING_VERSION` to the new version (e.g., `2.5.0`).
   - Increment all occurrences of `CURRENT_PROJECT_VERSION` by 1. This is the build number that Sparkle uses for upgrade eligibility — omitting it produces an appcast entry that Sparkle will not surface as an upgrade.
   - These are the sole source of version truth — there is no `package.json`, `pyproject.toml`, or similar.
   - See `RELEASING.md` for post-release verification of the appcast `<sparkle:version>` value.

3. **Update `CHANGELOG.md` and `DEVLOG.md`**
   - Follow Keep a Changelog format.
   - Add a new `## [X.Y.Z] - YYYY-MM-DD` section immediately below `## [Unreleased]`.
   - Move relevant entries from `## [Unreleased]` into the new section.
   - Leave `## [Unreleased]` in place (empty or with any entries that are not part of this release).
   - If the release includes significant engineering changes (architecture, refactors, build changes), also add an entry to `DEVLOG.md` under the new version. User-facing changes belong in `CHANGELOG.md`; engineering rationale belongs in `DEVLOG.md`.

4. **Commit**
   ```
   chore(release): vX.Y.Z
   ```

5. **Tag**
   ```bash
   git tag vX.Y.Z
   ```

6. **Push**
   ```bash
   git push github main --tags
   ```

7. **Tell the user**
   CI will create a draft release in approximately 3–5 minutes. The user must review and publish it manually at:
   https://github.com/kynoptic/claude-usage-tracker/releases

## Key details

- CI trigger: `.github/workflows/release.yml` — fires on tags matching `vX.Y.Z`.
- Draft release is created automatically; publishing is a manual step.
- Remote: `github` → `https://github.com/kynoptic/Claude-Usage-Tracker.git`
