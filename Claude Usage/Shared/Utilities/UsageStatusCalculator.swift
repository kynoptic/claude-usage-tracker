import Foundation
import Cocoa

/// Calculates five-zone pacing status from projected end-of-session utilisation.
///
/// Projection = `usedPercentage / elapsedFraction` when elapsed ∈ (0, 1).
/// Falls back to raw `usedPercentage` when elapsed is nil, 0, or ≥ 1.
///
/// Zone thresholds (projected %):
/// ```
///   grey   < greyThreshold (opt-in via showGrey; default threshold 50%)
///   green  greyThreshold–90%
///   yellow 90–110%
///   orange 110–150%
///   red    > 150%
/// ```
final class UsageStatusCalculator {

    // MARK: - Primary API

    /// Compute the five-zone pacing status.
    ///
    /// - Parameters:
    ///   - usedPercentage: Current usage 0–100+ (overage allowed).
    ///   - showRemaining: Unused for status; retained for API consistency.
    ///   - elapsedFraction: Fraction of session elapsed (0–1), or nil.
    ///   - showGrey: When true, projected below `greyThreshold` maps to `.grey`; otherwise `.green`.
    ///   - greyThreshold: Fraction (0–1) below which usage is considered underutilized. Default `0.5`.
    static func calculateStatus(
        usedPercentage: Double,
        showRemaining: Bool,
        elapsedFraction: Double?,
        showGrey: Bool = false,
        greyThreshold: Double = Constants.greyThresholdDefault
    ) -> UsageStatus {
        let u = usedPercentage / 100.0

        let projected: Double
        if let t = elapsedFraction, t > 0, t < 1.0 {
            projected = u / t
        } else {
            projected = u
        }

        let zone: UsageZone
        switch projected {
        case ..<greyThreshold:
            zone = showGrey ? .grey : .green
        case greyThreshold..<0.9:
            zone = .green
        case 0.9..<1.1:
            zone = .yellow
        case 1.1...1.5:
            zone = .orange
        default:
            zone = .red
        }

        return UsageStatus(zone: zone, actionText: actionText(for: zone))
    }

    /// Maps zone to a 1–10 ANSI colour level for the statusline bash script.
    ///
    /// ```
    ///   grey / green → 3
    ///   yellow       → 5
    ///   orange       → 7
    ///   red          → 10
    /// ```
    // showGrey/greyThreshold not forwarded — colorLevel always treats grey as green
    static func colorLevel(utilization: Int, elapsedFraction: Double?) -> Int {
        let status = calculateStatus(
            usedPercentage: Double(utilization),
            showRemaining: false,
            elapsedFraction: elapsedFraction
        )
        switch status.zone {
        case .grey, .green: return 3
        case .yellow:       return 5
        case .orange:       return 7
        case .red:          return 10
        }
    }

    /// Flat NSColor using Apple system colours for a UsageStatus.
    static func color(for status: UsageStatus) -> NSColor {
        switch status.zone {
        case .grey:   return .systemGray
        case .green:  return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .red:    return .systemRed
        }
    }

    // MARK: - Fraction Helpers

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

    // MARK: - Private

    private static func actionText(for zone: UsageZone) -> String {
        switch zone {
        case .grey:   return "Underutilized 💤"
        case .green:  return "On track ✅"
        case .yellow: return "Maximizing 🔥"
        case .orange: return "Overshooting ⚠️"
        case .red:    return "Way over 🛑"
        }
    }
}
