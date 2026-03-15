# ADR-007: Singleton pattern for services and managers

**Status:** Accepted
**Date:** 2026-03-14

## Context

The app needs shared, long-lived objects that maintain single sources of truth: API services, storage managers, logging, notification handling, and UI state coordination. These objects must be accessible from anywhere in the codebase without passing through multiple layers of dependency injection. Thread safety is critical on macOS when multiple tasks access shared state.

## Decision

Core services and managers use the `@MainActor` singleton pattern:

```swift
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var activeProfile: Profile?
    // ... properties and methods

    private init() {}
}
```

**Key points:**

- `static let shared` provides the singleton instance
- `private init()` prevents accidental instantiation
- `@MainActor` ensures all mutations run on the main thread, making thread safety guarantees automatic
- Services that publish state extend `ObservableObject` and use `@Published`
- Non-UI services (logging, storage) don't need `ObservableObject`

## Consequences

**Positive:**
- Single source of truth across the app eliminates state consistency bugs
- `@MainActor` enforces thread safety without explicit locks
- Views and services can observe state changes via `@Published` without polling
- Testing is straightforward: the singleton is available in test setup, or can be reset/mocked per test
- Global access (`ServiceName.shared`) is concise and doesn't require threading context through constructors

**Negative:**
- Singletons are global; test isolation requires care (reset mutable state in `tearDown`)
- Circular dependencies can emerge if services reference each other (mitigate with careful architecture)
- `@MainActor` adds a scheduling cost for background tasks that need to read profile data—necessary trade-off for safety

## When to use singletons

**YES: Services and managers**
- `ProfileManager` (in-memory profile state)
- `KeychainService` (credential storage)
- `DataStore`, `ProfileStore` (app-wide persistent state)
- `LoggingService` (centralized logging)
- `NotificationManager` (notification delivery)
- `NetworkMonitor` (network state tracking)
- `StatuslineService` (external tool integration)

**NO: Data models and views**
- Don't create `Profile.shared` — profiles are copied/passed by value
- Don't make SwiftUI views singletons — views are created per rendering
- Don't create singletons for temporary objects (network requests, UI calculations)

## Alternatives considered

**Dependency injection containers:** A registry that stores and vends singletons. Rejected — adds boilerplate without benefit at this scale. Direct `ServiceName.shared` access is clearer.

**Per-view/per-component state:** Each SwiftUI view holds its own copy of data. Rejected — leads to inconsistency and requires complex state synchronization logic.

**Weak singleton pattern:** Use `NSMapTable` or weak references to allow early deallocation. Rejected — services are meant to live for the app's lifetime, not be deallocated.
