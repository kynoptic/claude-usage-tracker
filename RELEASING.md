# Release process

The authoritative release procedure lives in [`docs/procedures/DEPLOY.md`](docs/procedures/DEPLOY.md). It covers version bumping, changelog updates, tagging, CI workflows, and publishing.

This file covers post-release verification and troubleshooting only.

## After releasing

Once the tag is pushed and the CI draft release is published:

1. **Check CI** — the Release workflow builds from the tag and attaches `Claude-Usage.zip` to the release. Confirm it completes green.
2. **Check the release page** — confirm the ZIP and SHA256 checksum are attached.
3. **Verify the appcast** — the Generate Appcast workflow runs after the release publishes. Check `appcast.xml` contains the new version with a `<sparkle:version>` matching `CURRENT_PROJECT_VERSION`.
4. **Test in-app update** — run an older installed version, open **Claude Usage → Check for Updates**, and confirm the new version appears and installs correctly.

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
