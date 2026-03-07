# Pacing-aware colour logic

The app colours usage indicators green, orange, or red. The colour reflects not just how much you've used, but whether your current pace will exhaust the session before it resets.

## The problem with absolute thresholds

A simple threshold — say, red above 80% — is misleading early in a session. If you're at 40% used after 10 minutes of a 5-hour window, a naive system shows orange. But at that pace you'd finish the session around 60%, well within limits. Conversely, 40% used after 4.5 hours means you're running hot — you're on track to hit 100% before reset.

Pacing solves this by asking: *at your current burn rate, where will you be at the end of the session?*

## The formula

```
projected = usedFraction ÷ elapsedFraction
```

`usedFraction` is current usage (0–1). `elapsedFraction` is how far through the session window you are (0–1). `projected` is the fraction you'll have consumed by the end of the session if you continue at this rate.

Example: 30% used, 40% through the session → projected = 0.30 ÷ 0.40 = **0.75** (on track to hit exactly 75%).

## Severity bands

| Projected end-of-session | Status | Colour |
|--------------------------|--------|--------|
| < 75% | Safe | Green |
| 75–95% | Moderate | Orange |
| ≥ 95% | Critical | Red |

These thresholds apply regardless of whether the app is in used-percentage or remaining-percentage display mode.

## Warmup period

Pacing only activates after **15% of the session has elapsed** (`elapsedFraction ≥ 0.15`, roughly 45 minutes into a 5-hour session). Before that, the elapsed fraction is too small to produce a reliable projection — a single burst of messages early on would spike the projected value far above the actual risk.

During warmup, and whenever timing data is unavailable, the app falls back to absolute thresholds (see below).

## Absolute fallback thresholds

Used when pacing is inactive (< 15% elapsed, session expired, or usage is zero).

**Used-percentage mode** (default):

| Used | Status |
|------|--------|
| < 50% | Safe |
| 50–80% | Moderate |
| ≥ 80% | Critical |

**Remaining-percentage mode** (when the user has toggled "show remaining" in Appearance settings):

| Remaining | Status |
|-----------|--------|
| > 20% | Safe |
| 10–20% | Moderate |
| < 10% | Critical |

The remaining-mode thresholds mirror macOS battery conventions — green means you have comfortable headroom, red means you're nearly out.

## Where this logic runs

The same thresholds apply in three places:

| Location | Implementation |
|----------|---------------|
| Menu bar icon colour | `UsageStatusCalculator.calculateStatus()` in Swift |
| Popover progress bars | `UsageStatusCalculator.calculateStatus()` in Swift |
| Terminal statusline | `UsageStatusCalculator.colorLevel()` in Swift → replicated in bash in `statusline-command.sh` |

The statusline uses a 1–10 ANSI colour level rather than three named states, but the severity bands map identically: levels 1–3 are green, 4–7 orange, 8–10 red.

## Bash/Swift sync contract

The bash script in `statusline-command.sh` replicates the pacing algorithm in shell integer arithmetic. The comment in that file reads:

> "Logic mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync."

If you change any threshold value in `UsageStatusCalculator.swift`, the corresponding branch in the bash script must be updated to match. The two implementations are not linked at runtime — they can silently diverge.

## Related docs

- [Statusline integration](statusline.md) — how the 1–10 colour levels map to ANSI colours in the terminal
- [Architecture overview](architecture.md) — `UsageStatusCalculator` in the component map
