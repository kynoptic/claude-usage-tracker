# Statusline integration

The statusline feature embeds live usage data into the Claude Code terminal prompt. It works by installing a small set of scripts into `~/.claude/` and configuring `settings.json` to run them on every prompt render.

## Installed files

| File | Purpose |
|------|---------|
| `~/.claude/fetch-claude-usage.swift` | Fetches usage from the API; outputs `utilization|resets_at` |
| `~/.claude/statusline-command.sh` | Reads config, calls the Swift script, builds and prints the statusline string |
| `~/.claude/statusline-config.txt` | Shell variables controlling which components appear |
| `~/.claude/settings.json` | `"statusLine": {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}` |

## Session key injection

The Swift script is not generic — the active profile's session key and organization ID are baked into it at install time by `StatuslineService.generateSwiftScript(sessionKey:organizationId:)`. This removes the need for the script to read the macOS Keychain or call back into the app at runtime.

The trade-off is that the script becomes stale when credentials change. `StatuslineService.updateScriptsIfInstalled()` runs automatically on:
- Profile activation (if the new profile has session key credentials)
- Any settings save that modifies statusline config

If no session key is available, a placeholder script is installed that prints `ERROR:NO_SESSION_KEY` and exits immediately, preventing the prompt from hanging.

> [!IMPORTANT]
> The statusline only supports the claude.ai session-key auth method. CLI OAuth does not work here because the statusline script runs as a standalone process that cannot access the app's OAuth token. A manually configured session key is always required.

## Color logic

Color selection mirrors `UsageStatusCalculator.colorLevel()` exactly. The bash script replicates the same pacing algorithm in shell arithmetic:

1. Compute elapsed session fraction from the `resets_at` timestamp
2. If elapsed fraction ≥ 15%: use pacing mode — project end-of-session usage and map to a 1–10 color level
3. Otherwise: fall back to absolute thresholds

The 10 levels map to three severity bands:

| Levels | Colour | Projected usage |
|--------|--------|-----------------|
| 1–3 | Green | < 75% |
| 4–7 | Orange | 75–95% |
| 8–10 | Red | ≥ 95% |

The comment in `statusline-command.sh` explicitly flags this contract: "Logic mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync." Any change to the Swift pacing thresholds must be mirrored in the bash script. See [pacing-aware colour logic](pacing-colours.md) for the full threshold specification.

## Time marker

The progress bar optionally shows a `│` character at the position corresponding to how far through the session window the current time is, letting you see at a glance whether usage is ahead of or behind the expected pace.

The marker position is computed from the same `elapsed_secs` value used for color selection. `SHOW_TIME_MARKER` in the config file controls it independently of the progress bar.

## Config file

`statusline-config.txt` is a plain shell variable file sourced by the bash script:

```sh
SHOW_DIRECTORY=1
SHOW_BRANCH=1
SHOW_USAGE=1
SHOW_PROGRESS_BAR=1
SHOW_RESET_TIME=1
SHOW_TIME_MARKER=1
```

`StatuslineService.updateConfiguration()` rewrites this file. The bash script sources it at the top of every execution, so changes take effect on the next prompt render without a restart.

## Disable / reset

Disabling the statusline:
1. Replaces the Swift script with the placeholder (no credentials in the file)
2. Removes the `statusLine` key from `settings.json`
3. Leaves the bash script and config file in place for easy re-enabling

## Related docs

- [Authentication chain](auth-chain.md) — why CLI OAuth cannot be used for statusline
- [ADR-004](../decisions/ADR-004-statusline-session-key-injection.md) — why credentials are injected rather than read at runtime
