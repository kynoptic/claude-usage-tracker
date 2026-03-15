# Troubleshooting

Common problems with Claude Usage Tracker and how to fix them.

## Application not connecting

1. Verify your session key is valid in **Settings** → **Claude.AI**
2. Confirm you're logged into `claude.ai` in your browser
3. Try extracting a fresh session key (see [getting started](../../README.md#getting-started))
4. Ensure you have an active internet connection

## 403 / unauthorized errors

Your session key or organisation selection is incorrect.

1. Open **Settings** → **Claude.AI**
2. Re-run the 3-step wizard:
   - Paste your session key and click **Test Connection**
   - Select the correct organisation from the list
   - Click **Save Configuration**

The wizard preserves your organisation selection when you update the key, so you only need to re-select if you're switching accounts.

## Menu bar icon not appearing

1. Check **System Settings** → **Control Centre** → **Menu Bar** and ensure the app isn't hidden
2. Restart the app
3. Check **Console.app** for error messages (filter by `Claude Usage`)

## Menu bar icons briefly flash to zero

Stale data is held until new data arrives. If you see this, update to the latest version.

## Session key expired

Session keys expire periodically without warning. Extract a fresh key from `claude.ai`:

1. Open `claude.ai` in a browser
2. Open DevTools → **Application** → **Cookies** → `https://claude.ai`
3. Copy the `sessionKey` value (`sk-ant-sid01-...`)
4. Paste it in **Settings** → **Claude.AI** → step 1 of the wizard

## Automatic updates not working

1. Check **Settings** → **Updates** and ensure automatic checking is enabled
3. Verify your internet connection
4. Download the latest release manually from the [releases page](https://github.com/kynoptic/Claude-Usage-Tracker/releases) if needed

## Usage data looks stale

The menu bar icon shows a staleness indicator (dimmed icon or tilde prefix, e.g. `~47%`) when displayed data may be out of date. No action is usually needed — the app recovers automatically once the rate-limit clears. If it persists, check your internet connection or manually refresh from the popover.

See [adaptive polling and rate limits](../explanations/polling-and-rate-limits.md#staleness-indicator) for what triggers this state.

## CLI OAuth token not working

If the app is configured with a synced CLI account but shows no data:

1. In your terminal, run `claude` to confirm you're still logged in
2. Open **Settings** → **CLI Account** and click **Sync from Claude Code** to refresh the stored token
3. If the token keeps expiring, fall back to a manual session key in **Settings** → **Claude.AI**

## Notifications not firing

1. Confirm notifications are enabled in **Settings** → **General** for the active profile
2. Check macOS **System Settings** → **Notifications** → **Claude Usage** and ensure alerts are allowed
3. Notifications fire when usage crosses 75%, 90%, or 95% — they won't re-fire until usage drops and rises again

## Auto-start session not triggering

Auto-start sends a minimal message to begin a new session when usage resets to 0%. If it isn't triggering:

1. Check **Settings** → **General** → **Auto-Start Sessions** is enabled for the active profile
2. Confirm the profile has a valid session key configured — auto-start requires claude.ai session credentials, not CLI OAuth
3. The feature uses the cheapest available model (Claude Haiku) and deletes the conversation after sending, so no chat history is created

## Statusline issues

See [configure statusline](configure-statusline.md#troubleshooting) for statusline-specific problems.
