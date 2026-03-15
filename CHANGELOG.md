# Changelog

User-facing changes — new capabilities, behavior changes, fixes that affected usage.

## [Unreleased]

## [2.4.4] - 2026-03-15

Wizard credential-save fix and internal architecture cleanup.

### Fixed

- Credentials entered in the Setup Wizard now save correctly — a routing bug prevented them from reaching storage on first-time setup

## [2.4.3] - 2026-03-14

Improved rate-limit handling and error visibility in the popover.

### Added

- Open Console button in API Billing settings for quick access to Anthropic console

### Changed

- Rate-limit retry countdown now updates live every second, showing precise time until next attempt
- Error banners display specific failure reasons (auth expired, missing credentials) instead of generic "refresh failed"

## [2.4.2] - 2026-03-09

Credential safety hardening for statusline script generation.

### Security

- Statusline setup now validates session keys and organization IDs against an allowlist before writing the generated Swift script, preventing crafted credentials from injecting code

## [2.4.1] - 2026-03-09

Burn-up chart accuracy, stability hardening, and auto-updates for the fork.

### Changed

- Auto-update feed now points to this fork's releases — users will receive updates from kynoptic/Claude-Usage-Tracker going forward

### Fixed

- Burn-up chart line now extends to the current time between polls, eliminating the gap when usage data hasn't changed
- Burn-up charts refresh every 60 seconds so the "now" marker stays current even without new data
- Crashes on empty organizations list, unavailable Application Support directory, and invalid wizard step values replaced with graceful error handling
- Feedback link in About now opens GitHub Issues instead of a broken email address

## [2.4.0] - 2026-03-07

Projection-based pacing, burn-up charts, and resilient polling.

### Added

- Five-zone pacing colours (grey / green / yellow / orange / red) based on projected end-of-session utilisation, replacing the old three-bucket system
- Configurable grey zone threshold (10–80%) in Appearance settings to flag underutilised sessions
- Flip-card burn-up charts on usage cards showing historical usage progression with a pace line and "now" marker
- Time-elapsed tick mark on menu bar icons, popover progress bars, and the CLI statusline
- Staleness banner in the popover when data is outdated, with countdown to next retry
- Adaptive polling with exponential backoff on 429 responses, honouring the server's Retry-After header

### Changed

- CLI OAuth tokens are now tried before cookie sessions, making authentication more reliable for Claude Code users
- OAuth 429 responses fall back to the session endpoint before giving up
- Popover can no longer be detached as a floating window (prevented a crash during card-flip animations)

### Fixed

- Circle and concentric-ring menu bar icons drew arcs counter-clockwise instead of clockwise from 12 o'clock
- OAuth 429 errors were misclassified as "unauthorized", prompting unnecessary re-sync suggestions
- Millisecond OAuth token expiry timestamps were interpreted as seconds, causing premature expiry

## [2.3.0] - 2026-01-23

Multi-profile menu bar display and configurable remaining percentage view.

### Added

- Multi-profile display mode — show all profiles side-by-side in the menu bar simultaneously, each with its own icon style and independent refresh
- Toggle between Single mode (active profile only) and Multi mode in Manage Profiles settings; preference persists across restarts
- Configurable percentage display: show remaining percentage instead of used percentage, with inverted color coding (green for high remaining, red for low remaining) (contributed by [@eliasyin](https://github.com/eliasyin))

### Fixed

- Monochrome mode was not applied to API icons
- Color transitions were incorrect when switching between used and remaining percentage modes
- Icons not updating when switching the active profile
- Popover showing wrong profile data after a profile switch
- Refresh timers not respecting per-profile intervals
- Icons appearing in wrong order or with inconsistent spacing in multi-profile mode

### Contributors

- [@eliasyin](https://github.com/eliasyin) — remaining percentage display feature

## [2.2.3] - 2026-01-18

Setup wizard enhancements and complete 8-language localization.

### Added

- Claude Code info banner in setup wizard (shown when CLI credentials are detected)
- Data migration banner in setup wizard with manual migration option and auto-close on success
- Complete localization in 8 languages

## [2.2.2] - 2026-01-18

CLI OAuth authentication fallback.

### Added

- Automatic fallback to Claude Code CLI OAuth when no session key is configured, using credentials from the system Keychain

### Changed

- Auto-start session logic simplified for more predictable trigger behavior

### Fixed

- Keychain credential reads silently failed in some configurations due to missing network client entitlements

## [2.2.1] - 2026-01-14

Sonnet weekly usage tracking and reliable auto-start after sleep.

### Added

- Sonnet weekly usage displayed in the popover alongside total weekly usage

### Fixed

- Auto-start sessions now trigger reliably after Mac sleep/wake, including sessions that reset during extended sleep periods

## [2.2.0] - 2026-01-12

Multi-profile management, Claude Code CLI integration, and Korean localization.

### Added

- Create and manage unlimited profiles for different Claude accounts, each with isolated credentials, settings, and usage data
- Profile switcher accessible from the popover header and settings sidebar
- Per-profile independent settings: credentials, icon style, refresh interval, auto-start, and notification thresholds
- One-click sync to import your currently logged-in Claude Code account credentials into a profile
- Automatic credential switching in Claude Code's system Keychain when changing the active profile
- Dedicated CLI Account settings tab showing sync status, masked token, subscription type, and last sync time
- Automatic statusline script updates when switching profiles — no manual reconfiguration needed
- Per-profile auto-start session monitoring; each profile with auto-start enabled is monitored independently
- Fun auto-generated profile names (e.g., "Quantum Llama", "Sneaky Penguin"); custom renaming supported
- Korean (한국어) added as the 8th supported language
- Reorganized settings with sidebar navigation; profile switcher integrated at the top

### Changed

- Credentials are now stored and isolated per profile
- Popover header shows a dropdown profile switcher with credential status badges

### Fixed

- Automatic one-time migration from v2.1.x: existing credentials and settings become the first profile on upgrade

### Migration

- On first launch after upgrading, existing credentials and settings are migrated automatically to the first profile. Your icon configuration, refresh interval, and notification preferences are preserved. No action required.

### Security

- Each profile's credentials are stored in isolation; CLI credentials are managed per-profile via the system Keychain

## [2.1.2] - 2026-01-10

Statusline reliability and organization ID handling improvements.

### Fixed

- Statusline scripts only update when already installed, preventing errors when statusline is not configured
- Organization ID is now injected directly into generated scripts rather than fetched via API, improving reliability and eliminating unnecessary network requests during statusline execution
- Clear error message shown when organization ID is not configured, preventing installation with incomplete settings

### Contributors

- [@oomathias](https://github.com/oomathias) — organization ID injection fix

## [2.1.1] - 2026-01-05

Next session reset countdown in menu bar icon.

### Added

- Session reset countdown displayed in the menu bar icon in HH:MM format (e.g., "2:45"); shows "in <1h" when under an hour remains (contributed by [@khromov](https://github.com/khromov))
- Toggle to enable or disable the session time display in Appearance Settings

### Fixed

- Time display for sessions under 1 hour now correctly shows "in <1h" instead of an incorrect format

### Contributors

- [@khromov](https://github.com/khromov) (Stanislav Khromov) — next session time display feature

## [2.1.0] - 2025-12-29

3-step setup wizard, modern notification system, and menu bar icon stability.

### Added

- 3-step setup wizard for initial configuration: validate session key, select organization, then confirm and save — no data written to Keychain until the final step (contributed by [@alexbartok](https://github.com/alexbartok))
- Same 3-step flow available in Personal Usage settings for reconfiguration
- Visual step progress indicator: numbered circles with checkmark on completion and accent highlight on current step

### Changed

- Session key no longer saved until explicitly confirmed in the wizard's final step
- Organization ID preserved when reconfiguring with the same session key, preventing data loss on reconfiguration

### Fixed

- Menu bar icons no longer flash zeros during data refresh — previous data stays visible until new data arrives
- Fixed 403 errors when saving after organization selection in the wizard
- Setup wizard now shows clear visual progress so the current step is always apparent

### Contributors

- [@alexbartok](https://github.com/alexbartok) (Alex Bartok) — 3-step wizard, organization selection, smart preservation, menu bar icon flicker fix

## [2.0.0] - 2025-12-28

Apple code signing, automatic updates, Keychain credential storage, and 6-language support.

### Added

- App is now signed with an Apple Developer certificate — no security warnings or Gatekeeper prompts on installation
- Automatic in-app updates via Sparkle: update notifications, one-click installation, configurable check frequency, and release notes displayed in-app
- Session keys stored securely in macOS Keychain; automatic migration from prior file/UserDefaults storage on first launch
- Support for 6 languages: English, Spanish, French, German, Italian, Portuguese
- Configure independent menu bar icons for different metrics (session, weekly, API) simultaneously, each with its own icon style
- Session key format validated with clear feedback before saving
- Network connectivity monitoring with automatic retry when connectivity is restored
- Launch at login option in Session Management settings

### Changed

- Settings first-run wizard streamlined: icon style no longer configured in wizard; data refreshes immediately when session key is saved

### Fixed

- Keychain migration handles all edge cases safely
- App recovers gracefully from network interruptions and API failures
- Multi-display support improved for multiple concurrent menu bar icons

### Migration

- Session keys are migrated automatically from prior storage formats on first launch. No action required.

### Security

- Session keys now stored in macOS Keychain
- App signed with Apple Developer certificate
- Automatic updates delivered over HTTPS with signature verification

## [1.6.2] - 2025-12-22

Settings navigation fix.

### Fixed

- Settings sidebar tabs now respond to clicks across the full tab area, not just the label text

## [1.6.1] - 2025-12-21

Critical CPU usage fix for multi-display setups.

### Fixed

- CPU usage reduced by 70–80% on multi-display setups (was 10–35%, now ~2–9% depending on display count); particularly benefited users with multiple monitors, Retina displays, or Stage Manager enabled

## [1.6.0] - 2025-12-21

API console tracking, customizable icon styles, monochrome mode, and redesigned settings.

### Added

- API console usage tracking: configure a separate API key and organization to monitor Anthropic API spending alongside web usage
- API usage statistics displayed in the popover in real time
- 5 menu bar icon styles: Battery (original), Progress Bar, Percentage Only, Icon with Bar, and Compact
- Monochrome mode toggle for a minimalist black-and-white icon aesthetic
- New Appearance Settings tab with icon style picker and live preview
- Redesigned settings interface with dedicated tabs for each feature area
- Auto-start initialization conversations are deleted after sending to prevent conversation clutter

### Fixed

- Uniform spacing and alignment across all settings views

## [1.5.0] - 2025-12-16

GitHub star prompt and contributors display.

### Added

- GitHub star prompt appears in settings after 24 hours of use; one-time display with "Maybe Later" option
- Contributors section in About showing project contributors with avatars

### Fixed

- Enhanced status display layout in the popover footer for improved readability

## [1.4.0] - 2025-12-15

Claude system status indicator and detachable popover.

### Added

- Real-time Claude API status indicator in the popover footer: color-coded (operational/minor/major/critical/unknown), clickable to open status.claude.com for details
- Detachable popover: drag the popover away from the menu bar to float it as a standalone window

### Fixed

- Popover now closes when clicking outside it
- Version number in About now reads dynamically from the app bundle instead of being hardcoded

### Contributors

- [@ggfevans](https://github.com/ggfevans) — Claude status indicator, detachable popover, outside-click fix, dynamic version display, issue templates, contributing guide

## [1.3.0] - 2025-12-14

Claude Code terminal statusline integration.

### Added

- Terminal statusline integration: display session usage directly in your Claude Code terminal prompt
  - Configurable components: working directory, git branch, usage percentage with 10-level color gradient, progress bar, and reset countdown
  - Live preview in the new Claude Code Settings tab
  - One-click installation to `~/.claude/` with automatic Claude Code settings update
- Session key validation required before statusline configuration
- At least one component must be selected before applying

### Fixed

- Statusline percentage display now shows a single `%` correctly (was showing `%%`)
- Leading whitespace removed from generated config file to prevent parsing errors

## [1.2.0] - 2025-12-13

Extra usage cost tracking.

### Added

- Real-time cost monitoring for Claude Extra: shows current spending vs. budget limit (e.g., 15.38 / 25.00 EUR) with a progress bar, displayed below weekly usage when Claude Extra is active (contributed by [@khromov](https://github.com/khromov))

### Contributors

- [@khromov](https://github.com/khromov) (Stanislav Khromov) — extra usage cost tracking feature

## [1.1.0] - 2025-12-13

Auto-start session and notification improvements.

### Added

- Auto-start session: when usage hits 0%, a new session is automatically initialized using Claude 3.5 Haiku; configurable in Settings → Session
- Notification when a session is auto-started
- Confirmation notification when enabling notifications, listing which thresholds are active (75%, 90%, 95%)
- New Session settings tab with feature explanation
- Settings window enlarged for better content display

### Fixed

- Menu bar icon now adapts to light/dark mode and wallpaper changes in real time; no restart needed when switching themes
- Notifications now display while the app is running (required for menu bar apps)

## [1.0.0] - 2025-12-13

Initial release.

### Added

- Real-time Claude usage monitoring: session, weekly, and Opus-specific usage
- Menu bar battery-style progress indicator
- Usage threshold notifications at 75%, 90%, and 95%
- Session reset notifications
- Setup wizard for first-run configuration
- Configurable refresh intervals (5–120 seconds)
- Settings interface (API, General, Notifications, About)
- Detailed usage dashboard with countdown timers
- macOS 14.0+ (Sonoma) support

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
