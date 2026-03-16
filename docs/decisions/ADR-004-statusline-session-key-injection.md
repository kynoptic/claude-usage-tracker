# ADR-004: Session key injected into statusline script at install time

**Status:** Accepted
**Date:** 2026-01-15

## Context

The statusline feature runs a Swift script (`fetch-claude-usage.swift`) on every terminal prompt render. The script needs to authenticate with the claude.ai API to fetch current usage. Options for supplying the credential:

1. Read the credential from the macOS Keychain at runtime
2. Read a credential file from disk (e.g. `~/.claude-session-key`)
3. Inject the credential into the script source when the app installs it

## Decision

Option 3: `StatuslineService.generateSwiftScript(sessionKey:organizationId:)` interpolates the session key and org ID directly into the Swift source code. The generated script is written to `~/.claude/fetch-claude-usage.swift` with permissions `755`.

When the statusline is disabled or credentials are unavailable, a placeholder script is written instead. The placeholder exits immediately with `ERROR:NO_SESSION_KEY`, preventing the prompt from hanging.

Credentials are refreshed in the script whenever:
- The user re-enables the statusline (full install)
- The active profile is switched (if the new profile has session-key credentials)
- Any settings save triggers `StatuslineService.updateScriptsIfInstalled()`

## Consequences

**Positive:**
- The script has no runtime dependency on the app, Keychain APIs, or a credential file — it is fully self-contained
- Works in all terminal environments without environment variables or helper processes
- No sandboxing complexity: the script does not call back into the app

**Negative:**
- The session key sits in plaintext in a file on disk. The file is `0600` (owner-only read/write), which is weaker than Keychain storage but limits exposure to the current user.
- Credentials go stale when the session key rotates. The app mitigates this by re-injecting on profile switch, but a user who updates their session key in settings without re-enabling the statusline will have stale credentials until the next update trigger.
- CLI OAuth cannot be used for the statusline for the same reason: OAuth tokens expire and rotate, and the standalone script has no mechanism to refresh them. A manually-configured session key is always required for this feature.

## Alternatives considered

**Runtime Keychain read from the script:** Swift can call Security framework APIs, but this requires a signed app with the right entitlements and triggers Keychain prompts in some sandbox configurations. Too fragile for a script running in varied terminal contexts.

**Read `~/.claude-session-key` file:** Simpler than Keychain, but creates a dependency on a file that may not exist (the app moved away from file-based credential storage in v2.0). Also does not solve the org ID requirement, which cannot be read from a standard path.
