# Pacing-aware colour logic

The app colours usage indicators using five discrete zones. The colour reflects not just how much you've used, but whether your current pace will exhaust the session before it resets.

## Projected utilisation

The icon colour is driven by **projected end-of-session utilisation**:

```
projected = usedPercentage / elapsedFraction
```

`usedPercentage` is current usage (0–100). `elapsedFraction` is how far through the session window you are (0–1). `projected` is the percentage you'll have consumed by the end of the session if you continue at this rate.

Example: 30% used, 40% through the session → projected = 30 / 0.40 = **75%** (on track to use exactly 75%).

When `elapsedFraction` is nil, zero, or ≥ 1 (session expired or timing unavailable), the app falls back to the raw `usedPercentage`.

## Five colour zones

| Projected utilisation | Zone | Colour | Apple colour constant |
|----------------------|------|--------|-----------------------|
| < 50% | Underutilized | Grey | `NSColor.systemGray` |
| 50–90% | On track | Green | `NSColor.systemGreen` |
| 90–110% | Maximizing | Yellow | `NSColor.systemYellow` |
| 110–150% | Overshooting | Orange | `NSColor.systemOrange` |
| > 150% | Way over | Red | `NSColor.systemRed` |

The grey zone is **opt-in** — it is off by default. Enable it with the **"Show grey for underutilized sessions"** toggle in **Appearance** settings. When disabled, sessions below 50% projected use show green instead.

## Where this logic runs

The same zone boundaries apply in three places:

| Location | Implementation |
|----------|---------------|
| Menu bar icon colour | `UsageStatusCalculator.calculateStatus()` in Swift |
| Popover progress bars | `UsageStatusCalculator.calculateStatus()` in Swift |
| Terminal statusline | `UsageStatusCalculator.colorLevel()` in Swift, replicated in bash in `statusline-command.sh` |

## Statusline colour levels

The statusline uses a 1–10 ANSI colour level. The five zones map to specific levels:

| Zone | Colour level |
|------|-------------|
| Grey | 3 |
| Green | 3 |
| Yellow | 5 |
| Orange | 7 |
| Red | 10 |

## Bash/Swift sync contract

The bash script in `statusline-command.sh` replicates the zone logic in shell arithmetic. The comment in that file reads:

> "Logic mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync."

If you change any threshold in `UsageStatusCalculator.swift`, the corresponding branch in the bash script must be updated to match. The two implementations are not linked at runtime — they can silently diverge.

## Dormant components

`SessionHistoryStore` and `BoundaryDetector` exist in the codebase but are not wired to the UI. They are kept for possible future session-history display.

## Related docs

- [Statusline integration](statusline.md) — how colour levels map to ANSI colours in the terminal
- [Architecture overview](architecture.md) — `UsageStatusCalculator` in the component map
