# Dev log

Engineering record — refactors, internal tooling, build changes, ADRs, dependency updates.

## [Unreleased]

## [2.4.3] - 2026-03-14

MenuBarManager decomposition and commit quality tooling.

- `MenuBarManager` had grown into a grab bag — observer setup, menu item construction, and refresh timing were all tangled together. Decomposed into three focused collaborators so each concern can be read, tested, and changed without touching the others.
- CodeQL was removed after it failed on every run due to an Xcode version mismatch; it was consuming substantial macOS CI minutes for no signal. Running locally when needed is cheaper. ADR-006: CodeQL removed — see docs/decisions/ADR-006-codeql-removed.md
- Pre-commit hooks added to catch malformed commit messages before they hit CI. The check-commit-body script enforces the scoped Conventional Commits format required by CONTRIBUTING.md.

## [2.4.2] - 2026-03-09

UsageRefreshCoordinator removed; statusline validation tests added.

- `UsageRefreshCoordinator` turned out to be a premature abstraction — once `PollingScheduler` took over timing logic, the coordinator had no real job left and was just a pass-through. Removed; refresh coordination now sits in `ProfileManager` and the polling timer directly.
- Tests added for the new credential validation boundary in `StatuslineService`. The validation logic is security-relevant so test coverage was added alongside the fix rather than after.
- CodeQL added to CI as a complement to the manual local approach introduced in 2.4.1.

## [2.4.1] - 2026-03-09

CI pipeline revised for fork; hard-fork ADR; deploy/release skills.

- The release workflow was originally designed for the upstream project's signing and notarization setup. Forking required substantial revision — appcast URLs, signing identity, and Homebrew tap targets all pointed at upstream. Revised to target this fork's infrastructure.
- ADR-005: Hard fork — independent development declared — see docs/decisions/ADR-005-hard-fork-independent-development.md. The upstream and fork architectures had diverged too far for clean cherry-picks; formalising the split avoided ongoing confusion about which remote to target.
- Deploy and release steps that previously existed only as tribal knowledge were codified as Claude Code skills so they're reproducible without consulting prior chat history.

## [2.4.0] - 2026-03-07

New infrastructure services, ADRs 1–4, docs site, and test baseline.

- `PollingScheduler` was introduced as a pure value type rather than a class with a timer, because polling interval decisions (backoff, stability stretching) are pure logic that shouldn't own side effects. The caller (`MenuBarManager`) owns the timer and queries the scheduler for the next interval.
- `BoundaryDetector` centralised session reset detection, which had previously been implemented ad-hoc in two places with slightly different thresholds — diverging over time.
- `SessionHistoryStore` and `UsageHistoryStore` added to back the burn-up charts. Keeping history in memory wasn't viable across app restarts; on-disk storage was needed, but the stores are kept deliberately separate from the main `DataStore` to avoid coupling chart data to the settings/credentials storage layer.
- ADR-001: MVVM with centralised ProfileManager singleton — see docs/decisions/ADR-001-mvvm-profile-manager.md
- ADR-002: CLI OAuth preferred over claude.ai session key — see docs/decisions/ADR-002-auth-priority-oauth-first.md
- ADR-003: Credentials embedded in Profile model — see docs/decisions/ADR-003-credentials-embedded-in-profile.md
- ADR-004: Session key injected into statusline script at install time — see docs/decisions/ADR-004-statusline-session-key-injection.md
- README had grown to cover architecture, API integration, contributing, and troubleshooting in one file. Split into a `docs/` site so each topic can be navigated to directly; README reduced to an overview with links.
- Test suite written from scratch as part of the fork's quality baseline. The upstream project had minimal tests; this fork's rate-limit handling and pacing logic are complex enough that regressions were happening silently.

## [2.3.0] - 2026-01-23

Centralised usage calculation and multi-button MenuBarManager.

- Color-coding logic (green/yellow/orange/red thresholds, remaining-vs-used inversion) had been duplicated across five rendering paths. `UsageStatusCalculator` was extracted as the single source of truth so a threshold change doesn't require hunting down every caller.
- `MenuBarManager` was originally designed around a single status bar button. Multi-profile display mode requires one button per profile. Reworked to track buttons in a dictionary keyed by profile ID, with explicit cleanup when profiles are deleted — the alternative (recreating all buttons on every profile change) caused visible flicker.

## [2.2.3] - 2026-01-18

Build and localization housekeeping.

- Removed `buildArchitectures = "Universal"` from the Xcode scheme — this setting was left over from an earlier CI configuration and was overriding the project-level architecture setting in unexpected ways.

## [2.2.2] - 2026-01-18

OAuth token expiry edge case and entitlement fix.

- CLI OAuth tokens store `expiresAt` in milliseconds in some CLI versions and seconds in others. Normalisation was added to `ClaudeCodeSyncService` after users with recently-issued tokens were seeing premature expiry — the millisecond value, interpreted as seconds, put the expiry date in 1970.
- Network client entitlements were missing, causing Keychain credential reads to silently fail in some sandboxed configurations.

## [2.2.1] - 2026-01-14

Sleep/wake reliability for auto-start.

- Mac wake events can fire multiple times in rapid succession — especially when external displays reconnect. Without debouncing, the auto-start check would race with itself and sometimes trigger twice. The 10-second debounce window was chosen to be long enough to absorb display reconnect chatter but short enough to catch a session reset that happened during sleep.
- Timer tolerance set to 30 seconds as an Apple-recommended energy efficiency practice for non-critical polling timers.

## [2.2.0] - 2026-01-12

Multi-profile architecture.

- The key architectural decision was `ProfileManager` as a `@MainActor` singleton, rather than having each component read from `UserDefaults` independently. Independent reads created transient inconsistency: during a profile switch, `MenuBarManager` and `ClaudeAPIService` could briefly disagree on which profile was active. The singleton is the single source of truth and all profile mutations route through it. ADR-001: MVVM with centralised ProfileManager singleton — see docs/decisions/ADR-001-mvvm-profile-manager.md
- Credentials are stored directly in the `Profile` model rather than in separate Keychain entries per profile. Multi-profile Keychain management would require key namespacing that's hard to reason about across migration paths; embedding in `UserDefaults` (which already has App Groups support) kept the storage model simpler. ADR-003: Credentials embedded in Profile model — see docs/decisions/ADR-003-credentials-embedded-in-profile.md
- Migration uses a one-time flag rather than version-based detection so it's idempotent — running it twice has no effect, which made it safe to run unconditionally on launch.

## [2.1.2] - 2026-01-10

Eliminated API call from statusline execution path.

- The statusline script runs on every terminal prompt render. The original implementation fetched the organization ID from the API each time, which was slow and consumed rate limit quota for a value that never changes between sessions. Org ID is now injected at install time, the same way the session key is. ADR-004: Session key injected into statusline script at install time — see docs/decisions/ADR-004-statusline-session-key-injection.md

## [2.1.1] - 2026-01-05

Minor helpers for session time display feature.

- Date utility functions and a `MenuBarIconConfig` property added to support the contributor-supplied session countdown feature. No architectural changes.

## [2.1.0] - 2025-12-29

Non-destructive session key validation and notification modernisation.

- The original save path wrote the session key to Keychain immediately on "Test Connection", which meant a failed test left the app in a broken state requiring manual cleanup. `testSessionKey()` validates without writing, so nothing is committed until the user confirms in the wizard's final step.
- `preserveOrgIfUnchanged` was added to `saveSessionKey()` because most reconfiguration is adjusting the key while keeping the same organization. The old path cleared org ID on every key change, causing a confusing 403 on save because the org had been wiped.
- `NSUserNotification` was deprecated in macOS 11.0; the warnings had been accumulating. Migrated to `UNUserNotificationCenter` to clear the build output and future-proof the notification path.

## [2.0.0] - 2025-12-28

Automated release pipeline and error framework.

- The release pipeline (signing, notarization, Sparkle appcast generation, Homebrew cask update) was the main engineering story for this release — getting all four stages automated end-to-end was fiddly because each stage depends on the previous one's output artifacts.
- The error framework (`AppError`, `ErrorLogger`, `ErrorPresenter`, `ErrorRecovery`) was introduced because raw Swift errors were being caught and silently discarded in several places. Users were seeing a blank display with no feedback when the API failed; the framework ensures every failure path produces a user-visible message.

## [1.6.2] - 2025-12-22

Release pipeline repair.

- The original ZIP step used `zip`, which strips extended attributes including the code signature. macOS Gatekeeper was rejecting the resulting bundle as "damaged". Switched to `ditto`, which preserves the signature. The runner was also downgraded from `macos-15` to `macos-14` because Xcode 16 isn't available on `macos-15` in the GitHub-hosted runner pool.

## [1.6.1] - 2025-12-21

Root cause analysis and fix for menu bar icon CPU regression.

- Root cause: the icon was being redrawn from scratch on every refresh cycle. macOS creates a "replicant" of each menu bar item for every display, Space, and Stage Manager context, so one redraw triggered N renders — scaling linearly with display count. About 45% of CPU time was going to `_updateReplicantsUnlessMenuIsTracking`.
- Image caching keyed on (percentage, appearance, icon style, monochrome mode) eliminates the redraw on cache hits. The cache is narrow enough that it rarely holds stale data — percentage changes slowly and appearance changes are rare.
- 12 instances of deprecated `UserDefaults.synchronize()` removed from `DataStore`. The call blocks the main thread and has been a no-op since macOS 10.14 — the OS syncs automatically.

## [1.6.0] - 2025-12-21

Coordinator pattern extracted from MenuBarManager.

- `MenuBarManager` had accumulated refresh scheduling, popover lifecycle management, and icon rendering. The coordinator pattern split these into `UsageRefreshCoordinator`, `WindowCoordinator`, and `StatusBarUIManager`. The split was motivated primarily by testability — the monolithic manager was impossible to test in isolation.
- Protocol abstractions (`APIServiceProtocol`, `NotificationServiceProtocol`, `StorageProvider`) were added for the same reason: dependency injection for tests, not runtime polymorphism.

## [1.5.0] - 2025-12-16

Star prompt timing logic.

- The 24-hour delay before showing the star prompt was chosen to avoid prompting users who opened the app once to evaluate it and never came back — the prompt is only shown to people who have actually used the app for a day.

## [1.4.0] - 2025-12-15

Outside-click detection for popover.

- Standard `NSPopover` close-on-outside-click behaviour doesn't work for menu bar apps — the app is never truly "deactivated" because it has no dock presence, so NSPopover never receives the deactivation event it waits for. A global event monitor is required to catch clicks outside the popover window.
- `NSPopoverDelegate.detachableWindow(for:)` was implemented to support the draggable floating window mode; the delegate also needed to handle window close to restore the popover-toggle behaviour on the menu bar icon.

## [1.3.0] - 2025-12-14

Statusline scripts embedded in app binary.

- The statusline scripts are embedded in the Swift binary rather than shipped as separate files. This means installation is a file write — no download, no package management, no version mismatch between the app and the scripts. The tradeoff is that the scripts can only be updated by updating the app.
- The session key is baked in at install time rather than read from Keychain at runtime because the statusline runs in a plain shell context that has no access to the app's Keychain items. ADR-004: Session key injected into statusline script at install time — see docs/decisions/ADR-004-statusline-session-key-injection.md

## [1.2.0] - 2025-12-13

Minor DataStore extension for extra usage feature.

- `DataStore` extended to persist the overage limit opt-in setting. No architectural decisions.

## [1.1.0] - 2025-12-13

Foreground notification delivery for menu bar apps.

- Without implementing `UNUserNotificationCenterDelegate.willPresent(_:withCompletionHandler:)`, notifications are silently suppressed while the app is running. This is a documented quirk of menu bar apps: macOS considers them always-foreground, so the default delivery path (which only shows banners for background apps) drops every notification.

## [1.0.0] - 2025-12-13

No engineering-only changes.

[2.4.3]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.4.2...v2.4.3
[2.4.2]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.4.1...v2.4.2
[2.4.1]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.2.3...v2.3.0
[2.2.3]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.2.2...v2.2.3
[2.2.2]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.6.2...v2.0.0
[1.6.2]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/kynoptic/Claude-Usage-Tracker/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/kynoptic/Claude-Usage-Tracker/releases/tag/v1.0.0
