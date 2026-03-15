# Storage Strategy

This document explains when to use each of the two storage mechanisms in the app.

## Two Storage Layers

### 1. DataStore (App-Wide Settings)

**Use for:** User preferences, UI configuration, cached data that applies across all profiles — including statusline configuration, wizard state, and language selection.

**Implementation:** `DataStore.shared` wraps `UserDefaults.standard` (app container).

**Examples:**

- Menu bar icon style preference (battery, progress bar, percentage)
- Notification settings (enabled/disabled)
- Color mode preference
- Debug logging toggles
- Last opened settings tab
- Statusline feature toggles (show directory, show branch, show usage, show progress bar)
- Language/localization selection
- Setup wizard completion state
- GitHub star prompt tracking

**Key trait:** Shared across all profiles. Changing a setting affects every profile immediately.

**How to use:**

```swift
// Save
DataStore.shared.saveNotificationsEnabled(true)
DataStore.shared.saveMenuBarIconStyle(.battery)

// Load
let style = DataStore.shared.loadMenuBarIconStyle()
```

---

### 2. ProfileStore (Per-Profile Credentials & Data)

**Use for:** Data that belongs to a specific profile, including credentials, profile-specific settings, and cached usage.

**Implementation:** All profiles are persisted together via `ProfileStore` using the `profiles_v3` key in `UserDefaults.standard`.

**Examples:**

- Claude.ai session key (credentials)
- CLI OAuth token blob (credentials)
- Organization ID
- Profile display name
- Per-profile icon style override
- Per-profile refresh interval
- Cached usage data

**Key trait:** Isolated per profile. Each profile has its own credentials, settings, and cached data.

**Access pattern:** Never read `ProfileStore` directly. Instead:

1. `ProfileManager.profiles` (list of all profiles)
2. `ProfileManager.activeProfile` (current profile)
3. Access fields on the `Profile` struct

**How to use:**

```swift
// Add a new profile
let newProfile = Profile(name: "Work Account", ...)
ProfileManager.shared.createProfile(newProfile)

// Switch profiles
try await ProfileManager.shared.activateProfile(id: profileId)

// Access active profile's data
let sessionKey = ProfileManager.shared.activeProfile?.claudeSessionKey
let usage = ProfileManager.shared.activeProfile?.claudeUsage
```

> **Note:** Credentials are currently embedded in the `Profile` struct serialised to `UserDefaults`. ADR-008 proposes migrating per-profile credentials to dedicated Keychain items.

---

## Decision Matrix

Use this flowchart to choose the right storage for new data:

```text
Is this setting specific to a profile?
├─ YES → Use ProfileStore (access via ProfileManager.activeProfile)
└─ NO  → Use DataStore
```

---

## Examples: Which Storage?

| Data | Storage | Reason |
| --- | --- | --- |
| "Use battery icon style" | DataStore | Applies to all profiles; global UI preference |
| "Profile name is 'Work'" | ProfileStore | Per-profile identity |
| "Active profile is Work" | ProfileStore | Stored in `activeProfileId` on ProfileManager |
| "Show usage in statusline" | DataStore | Global feature toggle; not profile-specific |
| "Work profile's session key" | ProfileStore | Per-profile credential |
| "CLI token expires at 2026-03-20" | ProfileStore | Per-profile credential metadata |
| "Last menubar icon refresh" | DataStore | Transient cache; global to app |
| "Setup wizard completed" | DataStore | One-time app state; not profile-specific |

---

## Related Docs

- [Multi-profile system](../explanations/multi-profile.md) — how profiles are organized
- [ADR-003](ADR-003-credentials-embedded-in-profile.md) — why credentials live in Profile, not separate Keychain entries
- [ADR-008](ADR-008-keychain-per-profile-credentials.md) — planned migration of per-profile credentials to Keychain (supersedes ADR-003)
- [ADR-001](ADR-001-mvvm-profile-manager.md) — why ProfileManager is the single source of truth
