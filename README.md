# Claude Usage Tracker

Native macOS menu bar app that monitors your Claude AI usage limits in real time.

- **Five-zone pacing colours** – grey/green/yellow/orange/red based on projected end-of-session utilisation, with a configurable grey threshold
- **Burn-up charts** – flip any usage card in the popover to see a live burn-up chart with a pace line and current-time marker
- **Time-elapsed marker** – shows current position within the session window on progress bars and the menu bar icon
- **Adaptive polling** – exponential backoff on rate limits, honouring server `Retry-After` headers
- **Terminal statusline** – live usage in your Claude Code prompt via a generated shell script, with pacing-aware colour levels
- **Privacy-first** – local storage, no telemetry, no cloud sync

## Getting started

**Requirements:** macOS 14.0 (Sonoma) or later, an active Claude AI account.

### Download (recommended)

1. Download `Claude-Usage.zip` from the [latest release](https://github.com/kynoptic/Claude-Usage-Tracker/releases/latest)
2. Unzip and drag **Claude Usage.app** to `/Applications`
3. Open it — macOS will block it on first launch because the app is not notarized
4. Go to **System Settings → Privacy & Security** and click **Open Anyway**

> [!NOTE]
> The app is open source and unsigned. The Gatekeeper prompt is expected — you only need to approve it once.

### Build from source

**Additional requirement:** Xcode 16+

```bash
git clone https://github.com/kynoptic/Claude-Usage-Tracker.git
cd Claude-Usage-Tracker
open "Claude Usage.xcodeproj"
# Press ⌘R to build and run
```

On first launch the app auto-detects your Claude Code credentials. Click the menu bar icon to confirm your usage is showing.

**No Claude Code?** Click the icon → **Settings** → **Claude.ai** and follow the 3-step wizard to configure a session key.

> [!TIP]
> To extract your session key: open `claude.ai` in a browser, open DevTools → **Application** → **Cookies**, and copy the `sessionKey` value (`sk-ant-sid01-...`).

## Documentation

Architecture guides and decision records live in [`docs/`](docs/). Start with the [architecture overview](docs/explanations/architecture.md).

For contribution guidelines, build commands, and commit conventions see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Attribution

This project is a fork of [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker). The original established the core architecture and API integration — full credit to [Hamed Elfayome](https://github.com/hamed-elfayome) and the [upstream contributors](https://github.com/hamed-elfayome/Claude-Usage-Tracker/graphs/contributors).

## License

MIT — see [`LICENSE`](LICENSE).
