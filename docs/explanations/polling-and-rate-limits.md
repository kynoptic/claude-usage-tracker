# Adaptive polling and rate limits

The app doesn't poll the API at a fixed cadence. `PollingScheduler` adjusts the interval dynamically based on two signals: rate-limit pressure from the server, and stability of the usage data.

## PollingScheduler

`PollingScheduler` is a value-type (`struct`) owned and mutated by `MenuBarManager`. It has no timers of its own — it only computes `currentInterval`. The actual `Timer` is held by `MenuBarManager`, which re-schedules it after each refresh cycle.

### Interval computation

```
currentInterval =
  if rate-limited:
    Retry-After header value  (if server provided one, floored at baseInterval)
    OR baseInterval × 2^consecutiveFailures  (exponential backoff, capped at maxBackoffInterval)
  else if stabilityStreak ≥ idleThreshold:
    baseInterval × idleMultiplier      (usage hasn't changed in a long time)
  else if stabilityStreak ≥ stableThreshold:
    baseInterval × stableMultiplier    (usage has been steady)
  else:
    baseInterval                       (normal cadence)
```

`baseInterval` comes from the active profile's `refreshInterval` setting (default 30 s). Constants for multipliers and thresholds are in `Constants.AdaptivePolling`.

### Stability streak

After each successful fetch, `PollingScheduler.recordSuccess(usage:)` compares the new session and weekly percentages to the previous values. If both are within `similarityTolerance`, the streak increments. Any change resets it to zero.

The stability streak is **preserved through rate-limit backoff recovery**. An idle user whose poll was temporarily suppressed returns to the slower (idle) tier immediately once the backoff clears, rather than stepping back through normal cadence first.

### Rate-limit backoff

On HTTP 429, `MenuBarManager` calls `pollingScheduler.recordRateLimitError(retryAfter:)` with the parsed `Retry-After` header value. The scheduler caps `consecutiveRateLimitFailures` at 20 to bound the maximum backoff interval. A subsequent success resets the failure counter and clears the server-specified retry value.

## Staleness indicator

When the app is rate-limited, it can't fetch fresh data, but it still shows the last known values rather than zeros. To signal that the displayed data may be outdated, `MenuBarManager` publishes `isStale: Bool`.

`isStale` is `true` when either:
- The scheduler is in backoff mode (`pollingScheduler.isBackingOff`)
- The last successful fetch is older than `Constants.RefreshIntervals.stalenessThreshold` (5 minutes)

Views and icon renderers read `isStale` to add a visual indicator — a dimmed icon and a tilde prefix on the percentage (e.g. `~47%`).

## Retry-After header parsing

`ClaudeAPIService.parseRetryAfter(from:)` reads the `Retry-After` header. Anthropic uses integer seconds, so the parser converts the string to a `TimeInterval` directly. The value is passed through `AppError.retryAfter` up to `MenuBarManager`, which forwards it to the scheduler.

## Related docs

- [Architecture overview](architecture.md) — where PollingScheduler sits in the data flow
- [ADR-001](../decisions/ADR-001-mvvm-profile-manager.md) — MenuBarManager as orchestrator
