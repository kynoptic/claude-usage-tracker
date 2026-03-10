# Pacing-aware colour logic

The icon and progress bars change colour based on **whether your current pace will exhaust your session before it resets** — not just how much you've used so far.

## What the colours mean

| Colour | Projected range | Status | Meaning |
| ------ | --------------- | ------ | ------- |
| ⚫ Grey | < 50% | Underutilized 💤 | Well under the limit. (Opt-in — see below.) |
| 🟢 Green | 50–90% | On track ✅ | Comfortable headroom. |
| 🟡 Yellow | 90–110% | Maximizing 🔥 | Close to the limit; consider slowing down. |
| 🟠 Orange | 110–150% | Overshooting ⚠️ | Will exceed your limit before the session resets. |
| 🔴 Red | > 150% | Way over 🛑 | Burning through the session very fast. |

## Why "projected" instead of raw usage

Raw usage can be misleading. If you've used 80% of your limit but you're 95% through the session window, you're fine — you'll reset before running out. If you've only used 40% but you're just 20% into the session, you're on pace to use 200%.

The app calculates:

```
projected = usedPercentage / elapsedFraction
```

**Example:** 30% used, 40% into the session → projected = 30 ÷ 0.40 = **75%** (green, on track).

When timing information is unavailable (session expired or no reset time), the app falls back to raw `usedPercentage`.

## The grey zone (opt-in)

Grey is disabled by default — low-usage sessions show green. To enable it:

Go to Settings → Appearance → "Show grey for underutilized sessions".

When enabled, projected usage below 50% shows grey instead of green. The 50% threshold is the default; you can adjust it in Appearance settings (range: 10–80%).

## Where colours appear

The same zone logic applies in three places:

- **Menu bar icon** — tinted dot or percentage label
- **Popover progress bars** — each profile's usage bar
- **Terminal statusline** — colour level 3 (green/grey), 5 (yellow), 7 (orange), or 10 (red)

---

## Technical details

### Projection formula

`UsageStatusCalculator.calculateStatus()` in `Claude Usage/Shared/Utilities/UsageStatusCalculator.swift`:

```swift
projected = usedPercentage / 100.0 / elapsedFraction   // when elapsedFraction ∈ (0, 1)
// fallback to usedPercentage / 100.0 otherwise
```

### Statusline colour levels

The terminal statusline maps zones to ANSI colour levels (1–10):

| Zone | Colour level |
| ---- | ------------ |
| Grey or Green | 3 |
| Yellow | 5 |
| Orange | 7 |
| Red | 10 |

### Bash/Swift sync contract

`statusline-command.sh` replicates the zone logic in shell arithmetic. The comment in that file reads:

> "Logic mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync."

If you change any threshold in `UsageStatusCalculator.swift`, update the corresponding branch in the bash script. The two implementations are not linked at runtime and can silently diverge.

## Related docs

- [Statusline integration](statusline.md) — how colour levels map to ANSI colours in the terminal
- [Architecture overview](architecture.md) — `UsageStatusCalculator` in the component map
