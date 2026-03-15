# Claude Usage Tracker

Native macOS menu bar app (macOS 14.0+ / Sonoma) for real-time Claude AI usage monitoring. Built with Swift 5.0+ and SwiftUI, using Xcode 16+.

## Build & test

```bash
# Build (Debug)
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build (Release)
xcodebuild build -project "Claude Usage.xcodeproj" -scheme "Claude Usage" -configuration Release CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

CI runs on `macos-15` (Xcode 16 required for `PBXFileSystemSynchronizedRootGroup` format). Code signing is disabled — open source, no Apple Developer certificate.

## Architecture

MVVM pattern. Keep views "dumb" — display only, no business logic.

```text
Claude Usage/
├── App/              # Entry point, lifecycle
├── MenuBar/          # Status item, popover UI, MenuBarManager (ViewModel)
├── Views/            # Settings, SetupWizard
└── Shared/
    ├── Models/       # Pure Swift data structs (ClaudeUsage, ClaudeStatus)
    ├── Services/     # API, notifications, statusline (async/await)
    ├── Storage/      # DataStore (UserDefaults wrapper)
    ├── Extensions/   # Date, UserDefaults helpers
    ├── Utilities/    # Constants, FormatterHelper
    ├── Components/   # Reusable SwiftUI components
    ├── ErrorHandling/# Error types, presenter, logger, recovery
    ├── Localization/ # LanguageManager, string resources
    ├── Patterns/     # SingletonBase protocol
    └── Protocols/    # Shared protocol definitions
```

Business logic belongs in managers/services. Prefer `async/await` over completion handlers.

## Code conventions

- Organize with `// MARK: -` sections (Properties → Initialization → Public Methods → Private Methods)
- Structs for data models (`Codable`, `Equatable`); enums for constants
- Use Swift type inference where unambiguous
- Document public APIs with doc comments (`///`)
- Extract complex SwiftUI sub-views into named structs

### Singleton pattern

Services and managers use the `@MainActor` singleton pattern for a single source of truth across the app. Thread safety and consistency are guaranteed by `@MainActor`.

**Pattern:**

```swift
@MainActor
final class ServiceName: ObservableObject {
    static let shared = ServiceName()

    @Published var state: SomeType?

    private init() {}
}
```

**When to use:** Services (`KeychainService`, `LoggingService`), managers (`ProfileManager`, `StatuslineService`), and storage (`DataStore`).

**When NOT to use:** Data models (`Profile`, `ClaudeUsage`), SwiftUI views, or temporary objects.

See [`docs/decisions/ADR-007-singleton-pattern.md`](docs/decisions/ADR-007-singleton-pattern.md) for detailed rationale, testing patterns, and thread safety guarantees. Optionally adopt the `Singleton` protocol in `Claude Usage/Shared/Patterns/SingletonBase.swift` to document the pattern explicitly (adoption is optional for existing singletons).

## Git

Follow `CONTRIBUTING.md` for all development conventions. The following **override global defaults**:

**Issue and PR templates:** Use the templates in `.github/` for all issues and PRs on this fork.

**Commits:** `<type>(<scope>): <description>` — scopes are required here (overrides global no-scope rule)

Common scopes: `api`, `menubar`, `statusline`, `settings`, `services`, `models`, `ui`

**Branches:** `feat/`, `fix/`, `docs/`, `refactor/`, `chore/` prefixes (overrides global `issue-<id>-<slug>` convention)

**Remote:** `origin` → `https://github.com/kynoptic/Claude-Usage-Tracker.git` (your fork)

> [!CAUTION]
> **This is a fork.** All work — commits, issues, PRs, releases — happens exclusively on this fork (`kynoptic/claude-usage-tracker`).
> **NEVER push, open PRs, file issues, or interact with upstream or any other fork in any way.** Upstream and other forks are read-only references for ideas and cherry-picks only.

**`gh` CLI guard:** `gh repo set-default kynoptic/claude-usage-tracker` is configured so `gh pr create`, `gh issue create`, etc. target the fork — not the upstream. If `gh` ever prompts to choose a repo, always pick the fork. When using `gh` commands that accept `--repo`, pass `--repo kynoptic/claude-usage-tracker` explicitly as a safety net.

**Upstream and other forks** (`hamed-elfayome/Claude-Usage-Tracker`, `tsvikas`, others) are read-only references for ideas and inspiration. Cherry-picks and patches are possible but require manual porting — the architectures have diverged too far for clean applies. Always evaluate against our codebase before attempting.

## Deploy to /Applications

See [`docs/procedures/DEPLOY.md`](docs/procedures/DEPLOY.md) for the complete deployment procedure, including detailed rationale for each step.

## Viewing UI without a display

The environment lacks display access (`screencapture` fails headlessly). Use `ScreenshotTests` to render SwiftUI views to PNG via `ImageRenderer`:

```bash
xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" \
  -only-testing:"Claude UsageTests/ScreenshotTests" \
  -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

PNGs are written to `.screenshots/` at the project root. Open them with:

```bash
open .screenshots/<name>.png
```

Add a temporary test to `ScreenshotTests.swift` for the view you want to inspect — remove it after verification. `ImageRenderer` returns `nil` in fully headless CI (no GPU), but works in local terminal sessions.

## Release

See [`docs/procedures/DEPLOY.md`](docs/procedures/DEPLOY.md) for the complete release procedure, including version bumping, changelog updates, tagging, and GitHub Actions workflow details.
