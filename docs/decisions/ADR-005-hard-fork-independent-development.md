# ADR-005: Declare Hard Fork and Develop Independently

**Date:** 2026-03-09
**Status:** Accepted

## Context

This project began as a fork of [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker) at v2.3.0 (common ancestor `66d8899`). The original intent was to contribute improvements back to upstream.

Between the fork point and March 2026, both sides developed independently:

- **This fork** added: adaptive polling with exponential backoff, Retry-After header handling, stale data display, 5-zone pacing colours with configurable grey threshold, burn-up charts, and extensive test coverage.
- **Upstream** added: a multi-profile architecture, usage history charts, global shortcuts, a redesigned settings system, network debug logging, and a notification overhaul — shipping v3.0.1.

The upstream changes restructured `MenuBarManager`, `PopoverContentView`, and `ClaudeAPIService` — the same files where this fork's most significant work is concentrated. Both sides independently implemented time-elapsed markers, pace-aware colouring, and credential fallback chains.

An analysis of cherry-pick feasibility found:
- No upstream fixes applied cleanly to our codebase (either already implemented, inapplicable to our architecture, or entangled with the multi-profile system we don't have).
- Porting our rate-limiting and polling work to upstream would require re-implementing against their multi-profile architecture — not a patch, but a project.

## Decision

Declare this a hard fork. Develop independently. Treat upstream and other forks as read-only inspiration sources.

## Changes made

**Identity and ownership:**
- Bundle ID changed from `HamedElfayome.Claude-Usage` to `io.kynoptic.claude-usage-tracker`
- Generated new Sparkle EdDSA keypair; public key in `Info.plist`, private key in GitHub Actions secret
- All GitHub URLs (constants, services, workflows, templates, docs) redirected to the fork
- Homebrew cask workflow disabled (no tap configured)

**Infrastructure:**
- Created clean `gh-pages` branch; GitHub Pages enabled at `kynoptic.github.io/Claude-Usage-Tracker`
- `SPARKLE_PRIVATE_KEY` and `RELEASE_TOKEN` secrets set in GitHub Actions
- Repo description, homepage, and topics updated

**Attribution:**
- README retains attribution to Hamed Elfayome and upstream contributors (accurate and appropriate)
- About view "Created by" section unchanged — he built the foundation
- CHANGELOG historical version comparison links unchanged — those versions lived on upstream

## Consequences

- All issues, PRs, and releases are tracked exclusively on this fork
- Upstream and other forks (`tsvikas`, etc.) may be consulted for ideas; any porting requires manual adaptation
- Version numbering continues independently from upstream (currently 2.4.x; upstream is at 3.0.x)
- Auto-updates work through our own appcast at `kynoptic.github.io/Claude-Usage-Tracker/appcast.xml`
- Existing installs using the old bundle ID (`HamedElfayome.Claude-Usage`) will not receive automatic updates and will need to re-enter credentials after upgrading to a build with the new bundle ID
