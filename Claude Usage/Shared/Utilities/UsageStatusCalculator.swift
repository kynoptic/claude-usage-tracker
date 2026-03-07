import Foundation
import Cocoa

/// Centralized utility for calculating usage status with adaptive pacing.
///
/// The primary API produces a continuous `UsageStatus` (severity 0–1, zone, action text)
/// from which HSB colours and 10-level statusline levels are derived.
/// Deprecated forwarders preserve backward compatibility with call sites that
/// still use `UsageStatusLevel`.
final class UsageStatusCalculator {

    // MARK: - Primary API

    /// Compute adaptive pacing status.
    ///
    /// When `context.elapsedFraction` ≥ 0.15, severity is derived from the
    /// *projected* end-of-session utilisation (`used / elapsed`), personalised
    /// by historical session data. Below 0.15, raw used fraction is compared
    /// against fixed zone boundaries.
    ///
    /// - Parameters:
    ///   - usedPercentage: Current usage 0–100 (can exceed 100 on overage).
    ///   - showRemaining: Ignored for status computation; kept for API compatibility.
    ///   - context: Historical and timing data for adaptive thresholds.
    /// - Returns: `UsageStatus` with zone, severity, and action text.
    static func calculateStatus(
        usedPercentage: Double,
        showRemaining: Bool,
        context: PacingContext
    ) -> UsageStatus {
        let u = usedPercentage / 100.0
        let t = context.elapsedFraction

        // Projected utilisation — pacing fires when ≥ 15% elapsed, non-zero usage
        let projected: Double
        if let t = t, t >= 0.15, t < 1.0, u > 0 {
            projected = u / t
        } else {
            projected = u
        }

        // Adaptive threshold computation
        let approach = approachStart(weeklyProjected: context.weeklyProjected)
        let avgRate   = blendedAvgRate(actual: context.avgSessionUtilization,
                                       count: context.sessionCount)
        let mod       = weeklyModulator(weeklyProjected: context.weeklyProjected)
        let effRate   = avgRate * mod
        let redThr: Double
        if let t = t, t >= 0.15, t < 1.0 {
            redThr = redThreshold(t: t, effectiveAvgRate: effRate)
        } else {
            redThr = 1.5  // Fallback: effectively unreachable via normal API
        }

        // Severity score
        let sev = severityScore(projected: projected, t: t, approachStart: approach, redThreshold: redThr)

        // Zone
        let zone: UsageZone
        if sev >= 1.0 {
            zone = .critical
        } else if projected >= 1.0 {
            zone = .warning
        } else if projected >= approach {
            zone = .approach
        } else {
            zone = .green
        }

        return UsageStatus(zone: zone, severity: sev, actionText: actionText(zone: zone, severity: sev))
    }

    /// Continuous severity (0–1) to 10-level ANSI colour level.
    ///
    /// ```
    /// severity 0.0–0.4 → levels 1–3  (green)
    /// severity 0.4–0.5 → levels 4–5  (approach / yellow-green)
    /// severity 0.5–1.0 → levels 6–9  (warning / orange-red)
    /// severity 1.0     → level  10   (critical)
    /// ```
    static func colorLevel(utilization: Int, context: PacingContext) -> Int {
        let status = calculateStatus(
            usedPercentage: Double(utilization),
            showRemaining: false,
            context: context
        )
        return severityToColorLevel(status.severity)
    }

    /// HSB-interpolated NSColor for a UsageStatus.
    ///
    /// ```
    /// severity 0.0–0.4: hue 120° (green), saturation ramps 10%→100%
    /// severity 0.4–0.5: hue 120°→60° (green→yellow)
    /// severity 0.5–1.0: hue  60°→ 0° (yellow→red)
    /// ```
    static func color(for status: UsageStatus) -> NSColor {
        let s = status.severity
        let hue: CGFloat
        let saturation: CGFloat

        if s <= 0.4 {
            hue        = 120.0 / 360.0
            saturation = CGFloat(cgLerp(0.10, 1.00, s / 0.4))
        } else if s <= 0.5 {
            let f      = (s - 0.4) / 0.1
            hue        = CGFloat(cgLerp(120.0, 60.0, f)) / 360.0
            saturation = 1.0
        } else {
            let f      = (s - 0.5) / 0.5
            hue        = CGFloat(cgLerp(60.0, 0.0, f)) / 360.0
            saturation = 1.0
        }

        return NSColor(hue: hue, saturation: saturation, brightness: 1.0, alpha: 1.0)
    }

    // MARK: - Fraction Helpers (unchanged)

    /// Fraction (0…1) of elapsed time within a period, adjusted for display mode.
    static func elapsedFraction(
        resetTime: Date?,
        duration: TimeInterval,
        showRemaining: Bool
    ) -> Double? {
        guard let reset = resetTime, duration > 0 else { return nil }
        guard reset > Date() else { return showRemaining ? 0.0 : 1.0 }
        let remaining = reset.timeIntervalSince(Date())
        let elapsed   = duration - remaining
        let fraction  = min(max(elapsed / duration, 0), 1)
        return showRemaining ? 1.0 - fraction : fraction
    }

    /// Display percentage based on mode.
    static func getDisplayPercentage(usedPercentage: Double, showRemaining: Bool) -> Double {
        showRemaining ? max(0, 100 - usedPercentage) : usedPercentage
    }

    // MARK: - Deprecated Forwarders

    /// - Warning: Deprecated. Use `calculateStatus(usedPercentage:showRemaining:context:)`.
    @available(*, deprecated, message: "Use calculateStatus(usedPercentage:showRemaining:context:) → UsageStatus")
    static func calculateStatus(
        usedPercentage: Double,
        showRemaining: Bool,
        elapsedFraction: Double? = nil
    ) -> UsageStatusLevel {
        let ctx = PacingContext(
            elapsedFraction: elapsedFraction,
            weeklyProjected: nil,
            avgSessionUtilization: nil,
            sessionCount: 0
        )
        let status = calculateStatus(usedPercentage: usedPercentage, showRemaining: showRemaining, context: ctx)
        return status.zone.asLegacyLevel()
    }

    /// - Warning: Deprecated. Use `colorLevel(utilization:context:)`.
    @available(*, deprecated, message: "Use colorLevel(utilization:context:) → Int")
    static func colorLevel(utilization: Int, elapsedFraction: Double?) -> Int {
        let ctx = PacingContext(
            elapsedFraction: elapsedFraction,
            weeklyProjected: nil,
            avgSessionUtilization: nil,
            sessionCount: 0
        )
        return colorLevel(utilization: utilization, context: ctx)
    }

    // MARK: - Private: Adaptive Threshold Helpers

    /// Starting point of the approach zone (fraction, 0–1).
    /// Modulated by the most recent weekly utilisation fraction.
    private static func approachStart(weeklyProjected wp: Double?) -> Double {
        guard let wp = wp else { return 0.90 }
        if wp <= 0.80 { return 0.94 }
        if wp <= 1.00 { return 0.90 }
        if wp <= 1.30 { return 0.87 }
        return 0.85
    }

    /// Weekly modulator scales effectiveAvgRate based on weekly pace.
    private static func weeklyModulator(weeklyProjected wp: Double?) -> Double {
        guard let wp = wp else { return 1.0 }
        if wp <= 0.80 { return 0.85 }
        if wp <= 1.00 { return 1.0 }
        if wp <= 1.30 { return 1.10 }
        return 1.20
    }

    /// Blend historical average with the 0.80 default, weighted by session count.
    /// Weight ramps from 0 (count ≤ 4) to 1 (count ≥ 20).
    private static func blendedAvgRate(actual: Double?, count: Int) -> Double {
        let defaultRate = 0.80
        guard let h = actual else { return defaultRate }
        let weight = clamp((Double(count) - 4.0) / 16.0, 0.0, 1.0)
        return weight * h + (1.0 - weight) * defaultRate
    }

    /// Projected utilisation fraction at which a typical user would finish the session.
    /// The value above which we consider the session over-consumed (critical).
    ///
    /// Formula: `(1 − effectiveAvgRate × (1 − t)) / t`
    ///
    /// Guard: only call when t ∈ [0.15, 1.0).
    private static func redThreshold(t: Double, effectiveAvgRate rate: Double) -> Double {
        let r = clamp(rate, 0.0, 1.0)
        return (1.0 - r * (1.0 - t)) / t
    }

    // MARK: - Private: Severity Scoring

    /// Map projected utilisation to a continuous severity in 0.0–1.0.
    ///
    /// Zones:
    /// - Green   (0 → approachStart): severity 0.0 → 0.4
    /// - Approach (approachStart → 1.0): severity 0.4 → 0.5, steeper when elapsed LOW
    /// - Warning  (1.0 → redThreshold): severity 0.5 → 0.9, steeper when elapsed HIGH
    /// - Critical (> redThreshold):     severity = 1.0
    private static func severityScore(projected u: Double, t: Double?, approachStart as_: Double, redThreshold: Double) -> Double {
        if u > redThreshold {
            // Critical
            return 1.0
        } else if u >= 1.0 {
            // Warning: 0.5 → 0.9
            let span = max(redThreshold - 1.0, 0.001)
            let f    = clamp((u - 1.0) / span, 0.0, 1.0)
            // Steepen when elapsed HIGH: exponent → 0.3 at t≈1.0, 1.0 at t=0.5
            let exp: Double = t.map { t in max(0.3, (1.0 - t) * 2.0) } ?? 1.0
            return 0.5 + 0.4 * pow(f, exp)
        } else if u >= as_ {
            // Approach: 0.4 → 0.5
            let span = max(1.0 - as_, 0.001)
            let f    = clamp((u - as_) / span, 0.0, 1.0)
            // Steepen when elapsed LOW: exponent → 0.3 at t≈0, 1.0 at t=0.5
            let exp: Double = t.map { t in max(0.3, t * 2.0) } ?? 1.0
            return 0.4 + 0.1 * pow(f, exp)
        } else {
            // Green: 0.0 → 0.4
            let f = clamp(u / max(as_, 0.001), 0.0, 1.0)
            return lerp(0.0, 0.4, f)
        }
    }

    // MARK: - Private: colorLevel from severity

    private static func severityToColorLevel(_ severity: Double) -> Int {
        if severity >= 1.0 { return 10 }
        if severity >= 0.5 {
            // [0.5, 1.0) → levels 6–9
            let f = (severity - 0.5) / 0.5
            return 6 + Int(f * 4.0)
        } else if severity >= 0.4 {
            // [0.4, 0.5) → levels 4–5
            let f = (severity - 0.4) / 0.1
            return 4 + Int(f * 2.0)
        } else {
            // [0.0, 0.4) → levels 1–3
            let f = severity / 0.4
            return 1 + Int(f * 3.0)
        }
    }

    // MARK: - Private: Action Text

    private static func actionText(zone: UsageZone, severity: Double) -> String {
        switch zone {
        case .green:
            return severity < 0.2 ? "Underutilized 💤" : "On track ✅"
        case .approach:
            return "Maximizing usage 🔥"
        case .warning:
            return "Overshooting ⚠️"
        case .critical:
            return "Way over 🛑"
        }
    }

    // MARK: - Private: Math Utilities

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func cgLerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * clamp(t, 0, 1)
    }

    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(value, lo), hi)
    }
}
