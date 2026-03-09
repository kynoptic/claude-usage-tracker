# Claude Usage Tracker

Native macOS menu bar app that monitors your Claude AI usage limits in real time.

- **Multi-profile support** – manage multiple Claude accounts with isolated credentials
- **Multi-display mode** – show all profiles simultaneously in the menu bar
- **Pace-aware status colours** – five discrete zones (grey/green/yellow/orange/red) driven by projected end-of-session utilisation
- **Time-elapsed marker** – shows current position within the session window on the progress bar
- **Terminal statusline** – live usage in your Claude Code prompt
- **Privacy-first** – local storage, no telemetry, no cloud sync

## Getting started

**Requirements:** macOS 14.0 (Sonoma) or later, Xcode 16+, an active Claude AI account.

```bash
git clone https://github.com/kynoptic/Claude-Usage-Tracker.git
cd Claude-Usage-Tracker
open "Claude Usage.xcodeproj"
# Press ⌘R to build and run
```

On first launch the app auto-detects your Claude Code credentials. Click the menu bar icon to confirm your usage is showing.

**No Claude Code?** Click the icon → **Settings** → **Claude.AI** and follow the 3-step wizard to configure a session key.

> [!TIP]
> To extract your session key: open `claude.ai` in a browser, open DevTools → **Application** → **Cookies**, and copy the `sessionKey` value (`sk-ant-sid01-...`).

## Documentation

Architecture guides and decision records live in [`docs/`](docs/). Start with the [architecture overview](docs/explanations/architecture.md).

For contribution guidelines, build commands, and commit conventions see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Attribution

This project is a hard fork of [hamed-elfayome/Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker). The original project established the core architecture, API integration, and foundation. All credit for that foundation belongs to [Hamed Elfayome](https://github.com/hamed-elfayome) and the [upstream contributors](https://github.com/hamed-elfayome/Claude-Usage-Tracker/graphs/contributors).

This fork has diverged significantly and is developed independently. Issues, PRs, and releases are tracked here.

## License

MIT — see [`LICENSE`](LICENSE).
