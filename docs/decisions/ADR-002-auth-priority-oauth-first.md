# ADR-002: CLI OAuth preferred over claude.ai session key

**Status:** Accepted
**Date:** 2026-02-10 (revised from original session-key-only approach)

## Context

The app originally used only the manually-extracted claude.ai session cookie (`sk-ant-sid01-...`). Session keys expire silently: the API returns 403 with no expiry signal, and users had no way to know until the app stopped updating. CLI OAuth tokens issued by `claude login` auto-refresh and are more stable, but they use a different endpoint and require different HTTP headers.

## Decision

`ClaudeAPIService.getAuthentication()` implements a three-step priority chain, preferring CLI OAuth over session keys. The full sequence and fallback logic are documented in [Authentication chain](../explanations/auth-chain.md).

## Consequences

**Positive:**
- Users who install the app while Claude Code is already logged in get a working setup with no manual configuration
- OAuth tokens that expire are refreshed automatically by the CLI; the app does not handle re-auth flows
- Fewer support cases caused by expired session keys silently breaking the display

**Negative:**
- The OAuth endpoint (`Constants.APIEndpoints.oauthUsage`) returns usage in the same structure as the session-key endpoint, but with different auth headers — this adds complexity to request construction
- Token expiry normalization is required: the CLI stores `expiresAt` in milliseconds in some versions, seconds in others. `ClaudeCodeSyncService.isTokenExpired()` must handle both.
- Statusline cannot use OAuth (see [ADR-004](ADR-004-statusline-session-key-injection.md)); a session key is still required for that feature.

## Alternatives considered

**Session key only:** Simpler, but fails silently on expiry and requires manual reconfiguration.

**OAuth only:** Would break users who do not use Claude Code CLI and configure a session key manually. The session key path must be retained as a fallback.
