# Multi-profile system

The app supports any number of named profiles. Each profile is isolated: separate credentials, appearance settings, refresh intervals, notification thresholds, and cached usage data.

## Data model

`Profile` is a `Codable` struct. Credentials are stored in the macOS Keychain as dedicated per-profile items, keyed by profile UUID (see [ADR-008](../decisions/ADR-008-keychain-per-profile-credentials.md)). `Profile` retains credential fields for in-memory use but `encode(to:)` excludes them — they are never serialized to `UserDefaults`.

Key fields:

| Field | Type | Purpose |
|-------|------|---------|
| `id` | `UUID` | Stable identity |
| `claudeSessionKey` | `String?` | claude.ai cookie credential |
| `organizationId` | `String?` | Required for session-key requests |
| `cliCredentialsJSON` | `String?` | Serialized CLI OAuth token blob |
| `claudeUsage` | `ClaudeUsage?` | Last fetched usage, persisted across launches |
| `iconConfig` | `MenuBarIconConfiguration` | Per-profile icon style and monochrome setting |
| `refreshInterval` | `TimeInterval` | Per-profile poll frequency |
| `isSelectedForDisplay` | `Bool` | Whether this profile appears in multi-display mode |

## ProfileManager

`ProfileManager` is a `@MainActor` singleton and the single source of truth for the profile list and the active profile. Views and services never read `ProfileStore` directly.

Responsibilities:
- Load profiles from `ProfileStore` on app start; create a default profile if none exist
- On first launch, auto-sync CLI credentials from the system Keychain into the default profile
- Expose `activeProfile` as a `@Published` property observed by `MenuBarManager` and all settings views
- Coordinate profile activation: re-sync CLI credentials before switching, update the statusline after

## Profile activation sequence

Switching profiles involves more than changing a pointer. `ProfileManager.activateProfile()` runs this sequence:

```
1. Check switchingSemaphore (prevent concurrent switches)
2. Re-sync current profile's CLI credentials before leaving
   └── Captures any token refresh that happened since last sync
3. Reload all profiles from disk (gets latest persisted data)
4. Apply target profile's CLI credentials to system Keychain
   └── So `claude` CLI uses the right account after switch
5. Update lastUsedAt timestamp
6. Update activeProfile and persist activeProfileId
7. Update statusline scripts if target profile has session-key credentials
```

## Display modes

`ProfileDisplayMode` controls what appears in the menu bar:

- **Single**: Only the active profile's icon is shown
- **Multi**: All profiles where `isSelectedForDisplay == true` are shown simultaneously, each with its own `NSStatusItem`

`ProfileManager.getSelectedProfiles()` returns the right list for each mode. `StatusBarUIManager` creates or destroys `NSStatusItem` instances to match.

In multi mode, clicking any profile icon opens the popover scoped to that profile's data. `MenuBarManager` tracks `clickedProfileId` and `clickedProfileUsage` to populate the popover for the right profile.

## Credential validity checks

`Profile` exposes computed properties so callers don't need to reach into services:

```swift
var hasClaudeAI: Bool              // session key + org ID both present
var hasAPIConsole: Bool            // API session key + API org ID both present
var hasValidOAuthCredentials: Bool // cached CLI OAuth validation result (stored Bool)
var hasUsageCredentials: Bool      // any of the above is true
```

## Related docs

- [Authentication chain](auth-chain.md) — per-profile credential selection
- [ADR-001](../decisions/ADR-001-mvvm-profile-manager.md) — why ProfileManager is a singleton
- [ADR-008](../decisions/ADR-008-keychain-per-profile-credentials.md) — per-profile Keychain credential storage
