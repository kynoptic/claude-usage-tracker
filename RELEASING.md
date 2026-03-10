# Release process

> [!IMPORTANT]
> The authoritative release workflow is in `CLAUDE.md` under **Release**. Follow that — the steps below cover verification and troubleshooting only.

## After releasing

Once the tag is pushed and `gh release create` completes:

1. **Check CI** — the Release workflow builds from the tag and attaches `Claude-Usage.zip` to the release. Confirm it completes green at `https://github.com/kynoptic/Claude-Usage-Tracker/actions`.
2. **Check the release page** — confirm the ZIP and SHA256 checksum are attached.
3. **Verify the appcast** — the Generate Appcast workflow runs after the release publishes. Check `https://kynoptic.github.io/Claude-Usage-Tracker/appcast.xml` contains the new version with a `<sparkle:version>` matching `CURRENT_PROJECT_VERSION`.
4. **Test in-app update** — run an older installed version, open **Claude Usage → Check for Updates**, and confirm the new version appears and installs correctly.

## Version numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major** (`X.0.0`): Breaking changes
- **Minor** (`x.Y.0`): New features, backwards compatible
- **Patch** (`x.y.Z`): Bug fixes, minor improvements

Both fields in `project.pbxproj` must be bumped for every release:

| Field | Purpose |
|-------|---------|
| `MARKETING_VERSION` | User-facing version string (e.g. `2.4.2`) |
| `CURRENT_PROJECT_VERSION` | Build number used by Sparkle to detect updates — must always increment, even for patches |

## Troubleshooting

### Update not showing in app

- Confirm `CURRENT_PROJECT_VERSION` was incremented (not just `MARKETING_VERSION`)
- Verify `appcast.xml` has a higher `<sparkle:version>` than the installed build
- Clear app caches: `~/Library/Caches/io.kynoptic.claude-usage-tracker/`

### Appcast not updating

- The Generate Appcast workflow triggers automatically after a release is published
- If it didn't run, trigger it manually from the Actions tab with the release tag
- If `appcast.xml` was manually edited, re-run the workflow to regenerate it with correct signatures

### Release ZIP missing from release

- Check the Release workflow run for that tag
- Re-run it from the Actions tab with `workflow_dispatch` if needed
