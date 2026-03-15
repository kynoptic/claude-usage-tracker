# ADR-008: Keychain-per-profile credential storage

**Status:** Accepted
**Date:** 2026-03-15
**Supersedes:** ADR-003 (when implemented)

## Context

ADR-003 chose to embed credentials directly in `Profile` structs serialised to `UserDefaults`. That trade-off was explicit: implementation simplicity over security, acceptable only while the app is unsigned and local-only.

Two conditions now make that calculus untenable:

1. Distribution via Homebrew or notarization expands the user base beyond the single developer.
2. Issue #90 replaces the `/usr/bin/security` subprocess with the Security framework, landing native Keychain I/O already in `KeychainService`. The infrastructure is ready.

Session keys and OAuth tokens in `UserDefaults` are readable by any process running as the same user. The `Profile` array is JSON-encoded; the only protection is that the key name (`profiles_v3`) is not publicly advertised.

## Decision

Move all per-profile credentials out of `Profile` / `UserDefaults` and into dedicated Keychain items. Each credential type for each profile becomes a separate Keychain generic-password item, keyed by `profile UUID`.

### Keychain item scheme

| Credential | `kSecAttrService` | `kSecAttrAccount` |
|---|---|---|
| Claude.ai session key | `com.claudeusagetracker.profile.claudeSessionKey` | `<profile-uuid>` |
| Claude.ai organization ID | `com.claudeusagetracker.profile.organizationId` | `<profile-uuid>` |
| API Console session key | `com.claudeusagetracker.profile.apiSessionKey` | `<profile-uuid>` |
| API Console organization ID | `com.claudeusagetracker.profile.apiOrganizationId` | `<profile-uuid>` |
| CLI OAuth JSON | `com.claudeusagetracker.profile.cliCredentialsJSON` | `<profile-uuid>` |

All items use `kSecAttrAccessibleWhenUnlocked` and `kSecAttrSynchronizable = false` (matching the existing `KeychainService` policy).

### Ownership

`KeychainService` owns all Keychain I/O. It gains per-profile CRUD methods accepting a `profileId: UUID`. `ProfileStore` calls `KeychainService` for credentials instead of encoding them into the `profiles_v3` blob. `Profile` retains credential fields for in-memory use but they are never persisted to `UserDefaults`.

### Profile deletion

`ProfileStore.deleteProfile(_:)` must call `KeychainService.deleteCredentials(for: profileId)` before removing the profile from the array. This is the key operational difference from the ADR-003 design: Keychain cleanup is now a required step, not an afterthought.

## Migration strategy

### Detection

On first launch after the upgrade, `ProfileMigrationService.migrateIfNeeded()` checks a new flag `didMigrateCredentialsToKeychainPerProfile` (separate from the existing `didMigrateToProfilesV3` flag).

### Steps

1. Load all profiles from `profiles_v3` using the current decoder (which still reads credential fields).
2. For each profile that has at least one non-nil credential field:
   a. Write each credential to the Keychain under the profile's UUID using the new per-profile scheme.
   b. If the Keychain write succeeds, nil-out the credential fields on the in-memory profile struct.
3. Save the modified profiles array back to `profiles_v3` (credentials are now absent).
4. Set `didMigrateCredentialsToKeychainPerProfile = true` in `UserDefaults`.

### Atomicity and failure handling

The migration is profile-by-profile. A failure for one profile is logged and skipped; the flag is not set, so the next launch retries. Profiles that were already migrated skip cleanly because Keychain `SecItemUpdate` is idempotent and in-memory credential fields will already be nil.

Existing Keychain items from `KeychainMigrationService` (the v1 migration that used fixed keys `com.claudeusagetracker.claude-session-key` and `com.claudeusagetracker.api-session-key`) are deleted after a successful per-profile migration, since those entries belong to the first profile and will have been re-written under the UUID scheme.

### `ProfileMigrationService` ordering

Both migration passes run at app launch in sequence:

1. `ProfileMigrationService.migrateIfNeeded()` — promotes v2.x single-profile data to `profiles_v3` (existing, unchanged).
2. `KeychainPerProfileMigrationService.migrateIfNeeded()` — moves credentials from `profiles_v3` fields to per-profile Keychain items (new).

Pass 2 is a no-op until Pass 1 has completed, so ordering is safe.

## Rollback

There is no automatic rollback. If the migration fails mid-flight, credentials remain in `UserDefaults` for the affected profiles and the flag stays unset, so the next launch retries. A deliberate rollback (e.g. downgrade to a previous build) requires deleting the new Keychain items and re-populating the `profiles_v3` blob — this is a developer operation, not a user-facing recovery path.

If a rollback path for users is required, it can be implemented as an export-and-wipe operation in Settings.

## Consequences

**Positive:**

- Credentials are protected by the Keychain's ACL. Without App Sandbox, processes running as the same user can still query Keychain items, but the attack surface is narrower than plaintext `UserDefaults` JSON (requires explicit Keychain API calls rather than a simple `defaults read`).
- Deleting a profile removes all its credentials atomically.
- `UserDefaults` no longer contains any sensitive material.
- Opens the path to App Sandbox and notarization.

**Negative:**

- Profile deletion requires a Keychain delete call; if this is skipped (e.g. via direct `UserDefaults` manipulation), orphaned Keychain items accumulate.
- Credential reads are now synchronous Security framework calls on `@MainActor`; latency is negligible for a menu bar app but worth monitoring if profile count grows large.
- Migration adds a new launch-time pass and a new `UserDefaults` flag to track.

## Open questions

1. **Access group:** The items currently use no explicit `kSecAttrAccessGroup`, which scopes them to the app. If a future widget or Notification Center extension needs to read credentials, an access group must be chosen before App Sandbox entitlements are added — changing it afterward requires another migration.

2. **Organization IDs:** `organizationId` and `apiOrganizationId` are not secret (they appear in API URLs), but storing them in the Keychain alongside the session keys simplifies the credential bundle and avoids a split-storage pattern. The alternative — keep org IDs in `UserDefaults` — reduces Keychain item count at the cost of a mixed-storage model. This should be decided before implementation.

3. **`cliCredentialsJSON` size:** The CLI OAuth JSON blob may be large (full token response). Keychain generic-password items support up to ~1 MB of data in modern macOS, but very large items affect Keychain performance. Measure the actual JSON size in production; if it consistently exceeds a few KB, store a file path in the Keychain and protect the file with POSIX permissions instead.

4. **Keychain prompts without App Sandbox:** Without a sandbox entitlement, the app reads its own Keychain items silently. Once a sandbox entitlement is added, the first read triggers a user prompt. UX review is needed before flipping that switch.
