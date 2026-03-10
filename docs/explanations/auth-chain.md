# Authentication chain

Every usage fetch resolves a credential through a three-step priority chain inside `ClaudeAPIService.getAuthentication()`. The chain picks the most reliable available credential and falls through when the current one is missing or expired.

## Priority order

```
1. Saved CLI OAuth token  (profile.cliCredentialsJSON, non-expired)
        │  not present or expired
        ▼
2. System Keychain CLI OAuth  (Claude Code's own Keychain entry, non-expired)
        │  not present or expired
        ▼
3. Claude.ai session key  (profile.claudeSessionKey, validated format)
        │  not present or invalid
        ▼
   throw AppError(.sessionKeyNotFound)
```

## Why this order

CLI OAuth tokens auto-refresh when the user runs Claude Code, making them more reliable than a manually-extracted session cookie that can expire silently. The System Keychain fallback means a profile without synced credentials can still use the CLI account logged in on the machine. Session key is last because it is user-managed and does not self-renew.

> [!NOTE]
> The Console API session key is deliberately excluded from this chain. It only provides billing data, not usage statistics.

## Credential types and their HTTP headers

| Type | Header | Notes |
|------|--------|-------|
| CLI OAuth | `Authorization: Bearer <token>` + `anthropic-beta: oauth-2025-04-20` + `User-Agent: claude-code/2.1.5` | Uses the dedicated OAuth usage endpoint; no org ID required |
| Claude.ai session | `Cookie: sessionKey=<key>` | Requires org ID; fetches from `/organizations/<id>/usage` |
| Console API | `Cookie: sessionKey=<key>` | Different endpoint; billing data only |

## Token expiry handling

`ClaudeCodeSyncService.isTokenExpired()` reads the `expiresAt` field from the stored JSON. The field is normalized from milliseconds to seconds during parsing to guard against a known edge case where the Anthropic CLI stores expiry in milliseconds, which would make a valid token appear expired if interpreted as Unix seconds.

Expiry is checked at the start of each fetch, before any network call. If the stored CLI OAuth token (step 1 in the chain) is expired, the chain immediately falls through to step 2 (System Keychain). If the Keychain token is also expired or absent, the chain falls through to the session key (step 3). There is no mid-fetch token refresh — if a token expires while a request is in-flight, the request fails and the next polling cycle re-evaluates the chain from the top, picking up a refreshed token if Claude Code has renewed it in the meantime.

## Multi-profile fetch

When fetching all profiles in multi-display mode, `MenuBarManager` calls a separate helper (`fetchUsageForProfile()`) for each profile. That helper runs the same OAuth-first → cookie fallback logic against each profile's stored credentials independently, so profiles can authenticate through different methods at the same time.

## Related docs

- [Multi-profile system](multi-profile.md) — per-profile credential storage
- [ADR-002](../decisions/ADR-002-auth-priority-oauth-first.md) — why OAuth is preferred
