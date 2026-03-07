import Foundation

/// Pure, testable detector for session and weekly boundary crossings.
///
/// A boundary is detected when:
/// 1. (Primary) The reset timestamp advances — the API returned a new period.
/// 2. (Fallback) The usage percentage drops by more than 25 percentage points
///    without a reset-time change — indicative of a silent reset.
///
/// On detection the *previous* snapshot's values are recorded (not the current).
struct BoundaryDetector {

    /// Returns a SessionRecord if a session boundary is detected between `previous` and `current`.
    /// Returns nil when `previous` is nil or no boundary is detected.
    static func detectSession(previous: ClaudeUsage?, current: ClaudeUsage) -> SessionRecord? {
        guard let prev = previous else { return nil }

        // Primary: reset time advanced → new session started
        if current.sessionResetTime > prev.sessionResetTime {
            return SessionRecord(
                endedAt: prev.sessionResetTime,
                finalPercentage: prev.sessionPercentage,
                sessionLimit: prev.sessionLimit
            )
        }

        // Fallback: usage dropped > 25pp without a visible reset-time change
        if prev.sessionPercentage - current.sessionPercentage > 25.0 {
            return SessionRecord(
                endedAt: prev.lastUpdated,
                finalPercentage: prev.sessionPercentage,
                sessionLimit: prev.sessionLimit
            )
        }

        return nil
    }

    /// Returns a WeeklyRecord if a weekly boundary is detected between `previous` and `current`.
    /// Returns nil when `previous` is nil or no boundary is detected.
    static func detectWeekly(previous: ClaudeUsage?, current: ClaudeUsage) -> WeeklyRecord? {
        guard let prev = previous else { return nil }

        // Primary: reset time advanced → new weekly period started
        if current.weeklyResetTime > prev.weeklyResetTime {
            return WeeklyRecord(
                endedAt: prev.weeklyResetTime,
                finalPercentage: prev.weeklyPercentage,
                weeklyLimit: prev.weeklyLimit,
                planChangedDuringPeriod: false
            )
        }

        // Fallback: usage dropped > 25pp without a visible reset-time change
        if prev.weeklyPercentage - current.weeklyPercentage > 25.0 {
            return WeeklyRecord(
                endedAt: prev.lastUpdated,
                finalPercentage: prev.weeklyPercentage,
                weeklyLimit: prev.weeklyLimit,
                planChangedDuringPeriod: false
            )
        }

        return nil
    }
}
