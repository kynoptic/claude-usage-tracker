import Foundation

/// Main data model representing Claude Code usage statistics
struct ClaudeUsage: Codable, Equatable {
    // Session data (5-hour rolling window)
    var sessionTokensUsed: Int
    var sessionLimit: Int
    var sessionPercentage: Double
    var sessionResetTime: Date

    // Weekly data (all models)
    var weeklyTokensUsed: Int
    var weeklyLimit: Int
    var weeklyPercentage: Double
    var weeklyResetTime: Date

    // Weekly data (Opus only)
    var opusWeeklyTokensUsed: Int
    var opusWeeklyPercentage: Double

    // Weekly data (Sonnet only)
    var sonnetWeeklyTokensUsed: Int
    var sonnetWeeklyPercentage: Double
    var sonnetWeeklyResetTime: Date?

    // Extra usage data
    var costUsed: Double?
    var costLimit: Double?
    var costCurrency: String?

    // Metadata
    var lastUpdated: Date
    var userTimezone: TimeZone

    /// Remaining percentage (100 - used percentage)
    var remainingPercentage: Double {
        max(0, 100 - sessionPercentage)
    }

    /// Returns the status level based on remaining percentage (like Mac battery indicator)
    /// DEPRECATED: Use UsageStatusCalculator.calculateStatus() instead for display-aware logic
    /// This property remains for backwards compatibility only
    /// - > 20% remaining: safe (green)
    /// - 10-20% remaining: moderate (yellow)
    /// - < 10% remaining: critical (red)
    @available(*, deprecated, message: "Use UsageStatusCalculator.calculateStatus() with showRemaining parameter")
    var statusLevel: UsageStatusLevel {
        switch remainingPercentage {
        case 20...:
            return .safe
        case 10..<20:
            return .moderate
        default:
            return .critical
        }
    }

    /// Empty usage data (used when no data is available)
    static var empty: ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: 0,
            sessionLimit: 0,
            sessionPercentage: 0,
            sessionResetTime: Date().addingTimeInterval(5 * 60 * 60),
            weeklyTokensUsed: 0,
            weeklyLimit: 1_000_000,
            weeklyPercentage: 0,
            weeklyResetTime: Date().nextMonday1259pm(),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )
    }

}

/// Usage status level for color coding
/// Thresholds depend on display mode (used vs remaining percentage)
/// - Note: Deprecated — use `UsageZone` / `UsageStatus` from the adaptive pacing system.
@available(*, deprecated, message: "Use UsageZone / UsageStatus from UsageStatusCalculator.calculateStatus(usedPercentage:showRemaining:context:)")
enum UsageStatusLevel: Equatable {
    case safe       // Used mode: 0-50% used | Remaining mode: >20% remaining
    case moderate   // Used mode: 50-80% used | Remaining mode: 10-20% remaining
    case critical   // Used mode: 80-100% used | Remaining mode: <10% remaining
}

// MARK: - Adaptive Pacing Types

/// Coarse zone for the adaptive pacing indicator.
enum UsageZone: Equatable {
    case green      // Under approach threshold — healthy utilisation
    case approach   // Approaching 100% projected — maximising
    case warning    // Projected to exceed 100% — overshooting
    case critical   // Well over limit — way over

    /// Maps to the legacy three-level system for deprecated call sites.
    func asLegacyLevel() -> UsageStatusLevel {
        switch self {
        case .green, .approach: return .safe
        case .warning:          return .moderate
        case .critical:         return .critical
        }
    }
}

/// Rich status produced by the adaptive pacing calculator.
struct UsageStatus: Equatable {
    /// Coarse zone for icon selection and action keywords.
    let zone: UsageZone
    /// Continuous severity in 0.0–1.0 driving HSB colour interpolation.
    let severity: Double
    /// Short keyword + emoji shown in the popover.
    let actionText: String
}
