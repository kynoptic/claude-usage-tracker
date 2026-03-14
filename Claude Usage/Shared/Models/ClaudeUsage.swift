import Foundation

/// Main data model representing Claude Code usage statistics
nonisolated struct ClaudeUsage: Codable, Equatable, Sendable {
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

// MARK: - Pacing Types

/// Five-zone status indicator driven by projected end-of-session utilisation.
nonisolated enum UsageZone: Equatable, Sendable {
    case grey    // Underutilized — projected < 50% (opt-in via Settings)
    case green   // On track — projected 50–90%
    case yellow  // Maximizing — projected 90–110%
    case orange  // Overshooting — projected 110–150%
    case red     // Way over — projected > 150%
}

/// Status produced by UsageStatusCalculator.
nonisolated struct UsageStatus: Equatable, Sendable {
    let zone: UsageZone
    let actionText: String
}
