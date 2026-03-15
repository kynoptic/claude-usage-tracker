# Storage Strategy

This document explains when to use each of the three storage mechanisms in the app.

## Three Storage Layers

### 1. DataStore (App-Wide Settings)

**Use for:** User preferences, UI configuration, cached data that applies across all profiles.

**Implementation:** `DataStore.shared` wraps `UserDefaults.standard` (app container).

**Examples:**
- Menu bar icon style preference (battery, progress bar, percentage)
- Notification settings (enabled/disabled)
- Color mode preference
- Debug logging toggles
- Last opened settings tab

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

**Implementation:** Each `Profile` struct is persisted via `ProfileStore` (UserDefaults with `profile_<UUID>` key pattern).

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

---

### 3. SharedDataStore (Cross-Profile App State)

**Use for:** Global app state that is shared but not profile-specific, particularly statusline configuration and setup wizard state.

**Implementation:** `SharedDataStore.shared` wraps `UserDefaults.standard` (same as DataStore; note: currently does NOT use app groups despite the name).

**Examples:**
- Statusline feature toggles (show directory, show branch, show usage, show progress bar)
- Language/localization selection
- Setup wizard completion state
- GitHub star prompt tracking

**Key trait:** Single shared value across all profiles. Changes affect the entire app, not just one profile.

**How to use:**
```swift
// Save
SharedDataStore.shared.saveStatuslineShowUsage(true)

// Load
let showUsage = SharedDataStore.shared.loadStatuslineShowUsage()
```

---

## Decision Matrix

Use this flowchart to choose the right storage for new data:

```
Is this setting specific to a profile?
├─ YES → Use ProfileStore (access via ProfileManager.activeProfile)
└─ NO  → Is this cross-app global state (not per-profile)?
         ├─ YES (statusline config, wizard state) → Use SharedDataStore
         └─ NO (user preferences, UI style) → Use DataStore
```

---

## Examples: Which Storage?

| Data | Storage | Reason |
|------|---------|--------|
| "Use battery icon style" | DataStore | Applies to all profiles; global UI preference |
| "Profile name is 'Work'" | ProfileStore | Per-profile identity |
| "Active profile is Work" | ProfileStore | Stored in `activeProfileId` on ProfileManager |
| "Show usage in statusline" | SharedDataStore | Global feature toggle; not profile-specific |
| "Work profile's session key" | ProfileStore | Per-profile credential |
| "CLI token expires at 2026-03-20" | ProfileStore | Per-profile credential metadata |
| "Last menubar icon refresh" | DataStore | Transient cache; global to app |
| "Setup wizard completed" | SharedDataStore | One-time app state; not profile-specific |

---

## Related Docs

- [Multi-profile system](../explanations/multi-profile.md) — how profiles are organized
- [ADR-003](ADR-003-credentials-embedded-in-profile.md) — why credentials live in Profile, not separate Keychain entries
- [ADR-001](ADR-001-mvvm-profile-manager.md) — why ProfileManager is the single source of truth
