# Deploying App to /Applications

Auto-invoke when the user asks to deploy, install, copy the built app to /Applications, or update the local installation (e.g. "deploy the app", "install the latest build", "copy to Applications", "update /Applications", "install locally", "push to Applications").

## Workflow

Follow the procedure in [`docs/procedures/DEPLOY.md`](../../../docs/procedures/DEPLOY.md) exactly. That document is the single source of truth for building, deploying, and releasing.

Key points:

- Run all commands from the repo root
- Always use `clean build`, never just `build` — incremental Release builds can reuse stale object files
- Always `rm -rf` the existing bundle before copying — `cp -R` silently skips overwriting
- Always pass code signing flags: `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- Always quit and reopen the app after deploying

## Critical gotchas

| Gotcha | Wrong | Correct |
|--------|-------|---------|
| Build command | `xcodebuild build` | `xcodebuild clean build` |
| Overwriting the bundle | `cp -R ... /Applications/` (stale binary stays) | `rm -rf` first, then `cp -R` |
| Code signing | Omit flags | Always pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| Working directory | Any directory | Repo root |
