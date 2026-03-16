# Storage Strategy

This document explains when to use each storage mechanism in the app.

## Storage Layers

### 1. Keychain (Credentials)

**Use for:** All sensitive credentials — session keys, OAuth tokens, organization IDs tied to authentication.

**Implementation:** `KeychainService.shared` wraps the Security framework. Per-profile credentials are keyed by profile UUID (see [ADR-008](ADR-008-keychain-per-profile-credentials.md)).

**Examples:**

- Claude.ai session key
- Claude.ai organization ID
- API Console session key
- API Console organization ID
- CLI OAuth JSON blob

**Key trait:** Credentials are never serialized to `UserDefaults`. `Profile.encode(to:)` explicitly excludes credential fields.

### 2. ProfileStore (Per-Profile Configuration & Cached Data)

**Use for:** Non-credential data that belongs to a specific profile — display settings, cached usage, metadata.

**Implementation:** All profiles are persisted together via `ProfileStore` using the `profiles_v3` key in `UserDefaults.standard`.

**Examples:**

- Profile display name
- Per-profile icon style override (`iconConfig`)
- Per-profile refresh interval
- Cached usage data (`claudeUsage`, `apiUsage`)
- Notification settings
- CLI account sync metadata

**Access pattern:** Never read `ProfileStore` directly. Use `ProfileManager.shared`:

```swift
ProfileManager.shared.activeProfile      // current profile
ProfileManager.shared.profiles           // all profiles
try await ProfileManager.shared.activateProfile(id: profileId)
```

### 3. DataStore (Global Preferences)

**Use for:** User preferences and cached data that applies across all profiles.

**Implementation:** `DataStore.shared` wraps `UserDefaults.standard`.

**Examples:**

- Notification enabled/disabled
- Debug logging toggle
- Language/localization selection
- Global refresh interval
- API tracking enabled/disabled

### 4. AppearanceStore (Icon & Display Settings)

**Use for:** Menu bar icon style, grey zone thresholds, monochrome mode, and icon configuration.

**Implementation:** `AppearanceStore.shared` wraps `UserDefaults.standard`.

```swift
AppearanceStore.shared.saveMenuBarIconStyle(.battery)
let style = AppearanceStore.shared.loadMenuBarIconStyle()
```

### 5. StatuslineConfigStore (Statusline Feature Toggles)

**Use for:** Statusline feature toggles — show directory, show branch, show usage, show progress bar.

### 6. SetupPromptStore (Onboarding State)

**Use for:** Setup wizard completion, GitHub star prompt tracking, first-launch state.

### 7. SessionHistoryStore / UsageHistoryStore (Historical Data)

**Use for:** Session history snapshots and usage history data for trend analysis.

---

## Decision Matrix

```text
Is this a credential (session key, OAuth token, org ID for auth)?
├─ YES → Keychain (via KeychainService)
└─ NO
   ├─ Is it specific to a profile?
   │  ├─ YES → ProfileStore (access via ProfileManager)
   │  └─ NO
   │     ├─ Is it appearance/icon related?
   │     │  ├─ YES → AppearanceStore
   │     │  └─ NO
   │     │     ├─ Is it statusline config? → StatuslineConfigStore
   │     │     ├─ Is it onboarding/prompt state? → SetupPromptStore
   │     │     ├─ Is it historical data? → SessionHistoryStore / UsageHistoryStore
   │     │     └─ Otherwise → DataStore
```

---

## Examples: Which Storage?

| Data | Storage | Reason |
| --- | --- | --- |
| "Work profile's session key" | Keychain | Per-profile credential (ADR-008) |
| "CLI token JSON" | Keychain | Per-profile credential |
| "Profile name is 'Work'" | ProfileStore | Per-profile identity |
| "Active profile is Work" | ProfileStore | Stored in `activeProfileId` |
| "Use battery icon style" | AppearanceStore | Global icon preference |
| "Show usage in statusline" | StatuslineConfigStore | Statusline feature toggle |
| "Setup wizard completed" | SetupPromptStore | One-time app state |
| "Debug logging enabled" | DataStore | Global preference |
| "Last menubar icon refresh" | DataStore | Transient cache; global to app |

---

## Related Docs

- [Multi-profile system](../explanations/multi-profile.md) — how profiles are organized
- [ADR-008](ADR-008-keychain-per-profile-credentials.md) — per-profile Keychain credential storage (supersedes ADR-003)
- [ADR-001](ADR-001-mvvm-profile-manager.md) — why ProfileManager is the single source of truth
