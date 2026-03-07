# Architecture overview

Claude Usage Tracker follows MVVM. Views are purely declarative; all state lives in `MenuBarManager`. Services handle I/O and have no SwiftUI dependencies.

## Component map

```
App entry
└── ClaudeUsageTrackerApp / AppDelegate
    └── MenuBarManager  (ViewModel — @MainActor ObservableObject)
        ├── StatusBarUIManager      renders NSStatusItem(s)
        ├── PollingScheduler        computes next poll interval
        ├── ClaudeAPIService        fetches usage from claude.ai / OAuth
        ├── ClaudeStatusService     fetches system status (status.claude.ai)
        ├── NotificationManager     fires threshold alerts
        └── ProfileManager          manages profile list and active profile
            └── ProfileStore        persists profiles to UserDefaults
```

Views (`PopoverContentView`, `SettingsView`, etc.) receive `MenuBarManager` via `@ObservedObject` or `@EnvironmentObject` and read `@Published` properties. They never call services directly.

## Data flow: normal refresh cycle

```
Timer fires (PollingScheduler.currentInterval)
  │
  └─► MenuBarManager.refreshUsage()
        │
        ├─► ClaudeAPIService.fetchUsageData()          (async, background)
        │     └─► getAuthentication()                  selects credential
        │           └─► HTTP GET usage endpoint
        │
        ├─► ClaudeStatusService.fetchStatus()          (async, concurrent)
        │
        └─► [on success] MainActor
              ├── @Published usage = newUsage           triggers SwiftUI redraw
              ├── @Published status = newStatus
              ├── @Published lastSuccessfulFetch = now
              ├── pollingScheduler.recordSuccess(usage) updates streak
              ├── updateStaleness()                     recalculates isStale
              ├── NotificationManager.checkAndNotify()  sends alert if threshold crossed
              └── StatusBarUIManager.updateIcons()      redraws menu bar item(s)
```

On a rate-limit (HTTP 429):
```
ClaudeAPIService throws AppError(.apiRateLimited, retryAfter: n)
  └─► MenuBarManager catches it
        ├── pollingScheduler.recordRateLimitError(retryAfter: n)
        └── updateStaleness()  → isStale = true  (stale indicator shown in menu bar)
```

## Key source files

| File | Role |
|------|------|
| `MenuBar/MenuBarManager.swift` | Central ViewModel; owns timer, published state, orchestrates all services |
| `MenuBar/StatusBarUIManager.swift` | Owns `NSStatusItem`(s); renders menu bar icons per profile |
| `MenuBar/MenuBarIconRenderer.swift` | Draws icon images (battery, bar, percentage, etc.) |
| `MenuBar/PopoverContentView.swift` | Main popover UI shown on icon click |
| `Shared/Services/ClaudeAPIService.swift` | All HTTP calls to claude.ai and the OAuth endpoint |
| `Shared/Services/ProfileManager.swift` | Profile CRUD, activation, credential delegation |
| `Shared/Storage/ProfileStore.swift` | UserDefaults read/write for `[Profile]` |
| `Shared/Utilities/PollingScheduler.swift` | Stateless struct; computes next poll interval |
| `Shared/Utilities/UsageStatusCalculator.swift` | Centralized green/orange/red logic with pacing |
| `Shared/Services/StatuslineService.swift` | Generates and installs `~/.claude/` scripts with injected credentials |

## Data persistence

Usage data is cached in the `Profile` struct and written to `UserDefaults` after every successful fetch via `ProfileManager.saveClaudeUsage()`. On next launch, the last known values are loaded immediately so the menu bar icon populates before the first API call completes.

There is no automatic expiry — cached values persist until overwritten by a fresh fetch or until the profile is deleted. The `UsageHistoryStore` maintains a rolling series of `UsageSnapshot` records used by the burn-up chart; this history is also stored in `UserDefaults` per profile.

## Threading model

All `@Published` mutations happen on `MainActor`. Service calls are `async` and run on the cooperative thread pool. `ProfileManager` is `@MainActor`. `PollingScheduler` is a plain `struct` mutated by `MenuBarManager` on the main thread.

## Related docs

- [Authentication chain](auth-chain.md) — how `getAuthentication()` selects a credential
- [Multi-profile system](multi-profile.md) — how multiple profiles are fetched and displayed
- [Adaptive polling and rate limits](polling-and-rate-limits.md) — how `PollingScheduler` works
