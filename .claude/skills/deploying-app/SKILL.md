# Deploying App to /Applications

Auto-invoke when the user asks to deploy, install, copy the built app to /Applications, or update the local installation (e.g. "deploy the app", "install the latest build", "copy to Applications", "update /Applications", "install locally", "push to Applications").

## Workflow

Run all commands from the repo root.

### 1. Pull latest

```bash
git pull origin main
```

### 2. Clean build (Release)

**Always use `clean build`, never just `build`.** Incremental Release builds can reuse stale object files and silently ship the old behaviour.

```bash
xcodebuild clean build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Code signing flags are always required — the project has no Apple Developer certificate.

### 3. Get the derived products directory

The `awk` pattern is unreliable — use a hardcoded path or `grep`/`sed` instead:

```bash
DERIVED=$(xcodebuild -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release \
  -showBuildSettings CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>/dev/null \
  | grep '^\s*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
```

### 4. Remove the existing bundle

**Always `rm -rf` before copying.** `cp -R` silently skips overwriting an existing `.app` directory, leaving the stale binary in place.

```bash
rm -rf "/Applications/Claude Usage.app"
```

### 5. Copy the new build

```bash
cp -R "$DERIVED/Claude Usage.app" "/Applications/"
```

### 6. Quit and reopen the app

**Always quit and reopen after deploying** — the running instance won't pick up the new binary automatically.

```bash
osascript -e 'quit app "Claude Usage"'; sleep 1 && open "/Applications/Claude Usage.app"
```

## Critical gotchas

| Gotcha | Wrong | Correct |
|--------|-------|---------|
| Build command | `xcodebuild build` | `xcodebuild clean build` |
| Overwriting the bundle | `cp -R ... /Applications/` (stale binary stays) | `rm -rf` first, then `cp -R` |
| Code signing | Omit flags | Always pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| Working directory | Any directory | Repo root |
