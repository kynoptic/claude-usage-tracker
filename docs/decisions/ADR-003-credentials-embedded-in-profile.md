# ADR-003: Credentials stored directly in Profile struct

**Status:** Accepted
**Date:** 2026-01-07

## Context

Earlier versions stored the session key in a single macOS Keychain entry and a single `UserDefaults` key. When multi-profile support was added, per-profile credentials needed a home: separate Keychain items keyed by profile UUID, or fields embedded directly in the serialized `Profile` struct in `UserDefaults`.

## Decision

Credentials are stored as fields on `Profile` and persisted with the rest of the profile data in `UserDefaults` via `ProfileStore`. There are no separate per-profile Keychain entries for session keys.

`ProfileCredentials` is a lightweight transfer struct used when reading or writing credentials through `ProfileManager.loadCredentials` / `saveCredentials`. Changes write back into the `Profile` struct immediately after saving.

## Scope

This decision covers **session keys** (`claudeSessionKey`) and OAuth tokens (`cliCredentialsJSON`) stored on the `Profile` struct. It does not govern the System Keychain — that entry belongs to the Claude Code CLI, not this app. The authentication chain (`auth-chain.md`) can read from the System Keychain as a fallback, but this app never writes to it.

## Consequences

**Positive:**
- Profile serialization is a single `JSONEncoder` call — all profile data including credentials is atomic
- Deleting a profile removes its credentials with no separate cleanup step
- Migration is straightforward: `ProfileMigrationService` copies the legacy Keychain value into the first profile's `claudeSessionKey` field once, then ignores the old Keychain entry
- No Keychain permission prompts when macOS sandboxing changes

**Negative:**
- `UserDefaults` is less secure than the Keychain. Session keys are sensitive credentials. The original single-key approach used Keychain storage for better protection.
- The `Profile` array in `UserDefaults` includes credentials in plaintext (obfuscated only by base64 encoding of the JSON). On a compromised machine, credentials are more accessible than they would be in the Keychain.

> [!CAUTION]
> If this app is ever distributed with App Sandbox entitlements, revisit this decision. Credentials in `UserDefaults` are readable by any process running as the same user; Keychain entries require explicit access control.

## Alternatives considered

**Per-profile Keychain items (`profileId + ".sessionKey"` as service name):** More secure, but complicates profile deletion (Keychain entries must be explicitly removed) and migration. Rejected for simplicity at this stage.

**Keychain for session keys only, UserDefaults for everything else:** Protects the most sensitive field without reworking the full profile model. Could be adopted in a future hardening pass.
