# Configure the Claude Code statusline

Display live usage data in your Claude Code terminal prompt.

> [!IMPORTANT]
> The statusline requires a manually configured `claude.ai` session key. CLI OAuth cannot be used — see [session key injection](../explanations/statusline.md#session-key-injection) for why.

## Prerequisites

- Claude Code installed and working
- A session key configured in **Settings** → **Claude.AI** (the 3-step wizard)

## Setup

1. Open **Settings** → **Claude Code**
2. Toggle on the components you want:

   | Component | Example output |
   |-----------|---------------|
   | Directory | `my-project` |
   | Git branch | `⎇ main` |
   | Usage | `Usage: 25%` |
   | Progress bar | `▓▓░░░░░░░░` |
   | Reset time | `→ Reset: 4:15 PM` |
   | Time marker | `│` at elapsed position in bar |

3. Check the live preview to confirm the output looks right
4. Click **Apply**
5. Restart Claude Code. The statusline appears at the bottom of your terminal.

### Example output

All components enabled:
```
my-project │ ⎇ feature/new-ui │ Usage: 47% ▓▓▓▓▓░░░░░ → Reset: 4:15 PM
```

Usage only:
```
Usage: 12% ▓░░░░░░░░░
```

## What gets installed

Applying writes four files to `~/.claude/`:

| File | Purpose |
|------|---------|
| `fetch-claude-usage.swift` | Fetches usage from the API; credentials injected at install time |
| `statusline-command.sh` | Builds the statusline string from config and script output |
| `statusline-config.txt` | Toggle flags for each component |
| `settings.json` | Updated with `"statusLine": {"type": "command", ...}` |

### How the files work together

Claude Code reads `settings.json` to find the statusline command and runs `statusline-command.sh` on each prompt render. The bash script reads `statusline-config.txt` to know which components are enabled, then calls `swift ~/.claude/fetch-claude-usage.swift` to get the live usage values. The Swift script has your session credentials baked in at install time, so it can contact the API directly without any app involvement.

When you switch profiles, the app rewrites `fetch-claude-usage.swift` with the new profile's credentials — `statusline-command.sh` and `statusline-config.txt` are left unchanged.

## Disable

1. Open **Settings** → **Claude Code**
2. Click **Reset**
3. Restart Claude Code

This removes the `statusLine` entry from `settings.json` and replaces the Swift script with a placeholder. The other files remain, so re-enabling is instant.

## Troubleshooting

**Statusline not appearing**
- Verify Claude Code is installed and working independently
- Confirm you restarted Claude Code after clicking **Apply**
- Check that `~/.claude/settings.json` contains a `statusLine` key

**Shows `Usage: ~`**
The Swift script could not fetch usage data:
- Verify your session key is valid in **Settings** → **Claude.AI**
- Confirm you're connected to the internet

**Permission error on the scripts**
```bash
chmod 755 ~/.claude/fetch-claude-usage.swift
chmod 755 ~/.claude/statusline-command.sh
```
