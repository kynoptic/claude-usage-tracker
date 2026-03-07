# ADR-001: MVVM with centralised ProfileManager singleton

**Status:** Accepted
**Date:** 2026-01-07

## Context

The app shares profile state (active profile, profile list, display mode) across many independent components: menu bar icons, the popover, all settings tabs, and API service calls. Profile data must be consistent everywhere and must survive settings navigation without reloading from disk on every view.

## Decision

`ProfileManager` is a `@MainActor` singleton (`ProfileManager.shared`) that acts as the in-memory source of truth for all profile data. Services and views read from `ProfileManager` rather than loading from `ProfileStore` directly.

`MenuBarManager` is the primary ViewModel. It observes `ProfileManager` and holds all `@Published` state that drives UI updates. Views are kept "dumb": they bind to `@Published` properties and call methods on the manager but contain no business logic.

## Consequences

**Positive:**
- Single source of truth eliminates consistency bugs where two components hold different active profile state
- `@Published` on `ProfileManager.activeProfile` lets any observing view or service react to profile switches automatically
- Testing is straightforward: inject a mock `ProfileManager` or a mock `ClaudeAPIService` via protocols

**Negative:**
- `ProfileManager.shared` is a global; test isolation requires care
- `@MainActor` means profile mutations always run on the main thread, adding a small scheduling cost for background tasks that need to read profile data

## Alternatives considered

**Per-component UserDefaults reads:** Each service reads the active profile ID from `UserDefaults` and loads the profile itself. Rejected — this duplicates parsing logic and risks transient inconsistency during profile switches.

**Combine `PassthroughSubject` pipeline:** Emit profile change events and let each subscriber maintain its own state copy. Rejected — reasoning about current state becomes harder and the complexity has no clear benefit at this scale.
