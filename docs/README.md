# Documentation

Architecture documentation and decision records for Claude Usage Tracker.

## Explanations

Guides to how the app works internally.

| Document | What it covers |
|----------|---------------|
| [Architecture overview](explanations/architecture.md) | MVVM structure, data flow, key components |
| [Authentication chain](explanations/auth-chain.md) | How credentials are selected and prioritised |
| [Multi-profile system](explanations/multi-profile.md) | Profile data model, switching, multi-display mode |
| [Adaptive polling and rate limits](explanations/polling-and-rate-limits.md) | PollingScheduler, backoff, staleness |
| [Statusline integration](explanations/statusline.md) | How terminal statusline scripts are generated and updated |
| [Pacing-aware colour logic](explanations/pacing-colours.md) | How green/orange/red is calculated from burn rate, not raw percentage |

## How-to guides

Guides for setup and debugging.

| Document | What it covers |
|----------|---------------|
| [Configure the statusline](how-to/configure-statusline.md) | Step-by-step statusline setup, components, troubleshooting |
| [Troubleshooting](how-to/troubleshooting.md) | Connection errors, 403s, expired session keys, update issues |

## Reference

Technical specifications.

| Document | What it covers |
|----------|---------------|
| [API endpoints](reference/api-endpoints.md) | Endpoint URLs, authentication headers, response fields, rate limiting |

## Architecture decision records

Records of key design decisions and their rationale.

| ADR | Decision |
|-----|---------|
| [ADR-001](decisions/ADR-001-mvvm-profile-manager.md) | MVVM with centralised ProfileManager singleton |
| [ADR-002](decisions/ADR-002-auth-priority-oauth-first.md) | CLI OAuth preferred over session key |
| [ADR-003](decisions/ADR-003-credentials-embedded-in-profile.md) | Credentials stored directly in Profile struct |
| [ADR-004](decisions/ADR-004-statusline-session-key-injection.md) | Session key injected into statusline script at install time |
| [ADR-005](decisions/ADR-005-hard-fork-independent-development.md) | Declare hard fork and develop independently |
