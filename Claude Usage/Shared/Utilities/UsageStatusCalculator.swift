import Foundation

/// Centralized utility for calculating usage status levels with configurable display modes
final class UsageStatusCalculator {

    /// Calculate status level based on percentage, display mode, and optional session pacing.
    /// - Parameters:
    ///   - usedPercentage: The percentage used (0-100)
    ///   - showRemaining: If true, use remaining-based fallback thresholds; if false, use used-based fallback
    ///   - elapsedFraction: Fraction of the session that has elapsed (0-1). When provided and ≥ 0.15,
    ///     pacing logic fires: status is derived from the projected end-of-session usage
    ///     (`usedFraction / elapsedFraction`), independent of display mode.
    ///     Pass `nil` (default) to fall back to absolute thresholds.
    /// - Returns: The appropriate status level
    static func calculateStatus(
        usedPercentage: Double,
        showRemaining: Bool,
        elapsedFraction: Double? = nil
    ) -> UsageStatusLevel {
        let u = usedPercentage / 100.0

        // Pacing mode: only when enough of the session has elapsed and usage is non-zero.
        // Projected = fraction we'll have consumed by the end of the session at the current rate.
        // Thresholds: green < 0.75, yellow 0.75–0.95, red ≥ 0.95
        if let t = elapsedFraction, t >= 0.15, t < 1.0, u > 0 {
            let projected = u / t
            switch projected {
            case ..<0.75:     return .safe
            case 0.75..<0.95: return .moderate
            default:          return .critical
            }
        }

        // Fallback: absolute thresholds (no timing data, or session too early/complete)
        if showRemaining {
            // Based on remaining percentage (like Mac battery)
            // > 20% remaining: safe (green)
            // 10-20% remaining: moderate (yellow)
            // < 10% remaining: critical (red)
            let remainingPercentage = max(0, 100 - usedPercentage)
            switch remainingPercentage {
            case 20...:   return .safe
            case 10..<20: return .moderate
            default:      return .critical
            }
        } else {
            // Based on used percentage
            // 0-50% used: safe (green)
            // 50-80% used: moderate (yellow)
            // 80-100% used: critical (red)
            switch usedPercentage {
            case 0..<50: return .safe
            case 50..<80: return .moderate
            default:     return .critical
            }
        }
    }

    /// Fraction (0...1) of elapsed time within a period, adjusted for display mode.
    /// Returns nil when the reset time or duration is unavailable.
    /// When the reset time is in the past (period fully elapsed), returns 1.0 (or 0.0 in remaining mode).
    static func elapsedFraction(
        resetTime: Date?,
        duration: TimeInterval,
        showRemaining: Bool
    ) -> Double? {
        guard let reset = resetTime, duration > 0 else { return nil }
        guard reset > Date() else { return showRemaining ? 0.0 : 1.0 }
        let remaining = reset.timeIntervalSince(Date())
        let elapsed = duration - remaining
        let fraction = min(max(elapsed / duration, 0), 1)
        return showRemaining ? 1.0 - fraction : fraction
    }

    /// Get the display percentage based on mode
    /// - Parameters:
    ///   - usedPercentage: The percentage used (0-100)
    ///   - showRemaining: If true, return remaining percentage; if false, return used percentage
    /// - Returns: The percentage to display
    static func getDisplayPercentage(
        usedPercentage: Double,
        showRemaining: Bool
    ) -> Double {
        if showRemaining {
            return max(0, 100 - usedPercentage)
        } else {
            return usedPercentage
        }
    }

    /// Map utilization + optional session pacing to a 1–10 ANSI color level for the statusline.
    ///
    /// Color band contract (mirrors `calculateStatus` severity):
    ///   - green  (safe)     → levels 1–3:  projected < 75%
    ///   - yellow (moderate) → levels 4–7:  projected 75–95%
    ///   - red    (critical) → levels 8–10: projected ≥ 95%
    ///
    /// Pacing fires when `elapsedFraction` ≥ 0.15 and < 1.0 and utilization > 0.
    /// Otherwise falls back to absolute thresholds that match `calculateStatus` (used-based).
    ///
    /// - Parameters:
    ///   - utilization: Integer usage percentage (0–100)
    ///   - elapsedFraction: Fraction of the session elapsed (0–1), or nil if unavailable
    /// - Returns: A level in the range 1–10
    static func colorLevel(utilization: Int, elapsedFraction: Double?) -> Int {
        let u = Double(utilization) / 100.0

        // Pacing mode: same guard conditions as calculateStatus
        if let t = elapsedFraction, t >= 0.15, t < 1.0, u > 0 {
            let projected = u / t  // fraction of full capacity consumed by end of session

            if projected < 0.75 {
                // Green range: sub-divide 0–75% into thirds
                if projected < 0.25 { return 1 }
                if projected < 0.50 { return 2 }
                return 3
            } else if projected < 0.95 {
                // Yellow range: sub-divide 75–95% into quarters
                if projected < 0.80 { return 4 }
                if projected < 0.85 { return 5 }
                if projected < 0.90 { return 6 }
                return 7
            } else {
                // Red range: sub-divide ≥95% by 20-point bands
                if projected < 1.15 { return 8 }
                if projected < 1.35 { return 9 }
                return 10
            }
        }

        // Fallback: absolute thresholds matching calculateStatus (used-based)
        if utilization < 50 {
            // Green range: levels 1–3
            if utilization < 17 { return 1 }
            if utilization < 34 { return 2 }
            return 3
        } else if utilization < 80 {
            // Yellow range: levels 4–7
            if utilization < 60 { return 4 }
            if utilization < 67 { return 5 }
            if utilization < 73 { return 6 }
            return 7
        } else {
            // Red range: levels 8–10
            if utilization < 87 { return 8 }
            if utilization < 93 { return 9 }
            return 10
        }
    }
}
