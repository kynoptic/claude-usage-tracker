import Foundation

/// Context for adaptive pacing calculations.
/// Carries historical and real-time data used by UsageStatusCalculator
/// to personalise zone boundaries and severity scoring.
struct PacingContext: Equatable {
    /// Fraction (0…1) of the current session that has elapsed. Non-inverted (always elapsed direction).
    let elapsedFraction: Double?
    /// Most recent weekly utilisation as a fraction (0…1+), or nil when no history exists.
    let weeklyProjected: Double?
    /// Average final session utilisation fraction from comparable historical sessions, or nil.
    let avgSessionUtilization: Double?
    /// Number of comparable historical sessions used to compute avgSessionUtilization.
    let sessionCount: Int

    /// Null context: no historical or timing data available.
    static let none = PacingContext(
        elapsedFraction: nil,
        weeklyProjected: nil,
        avgSessionUtilization: nil,
        sessionCount: 0
    )
}

// MARK: - Boundary Records

/// A completed session boundary snapshot, recorded when a new session starts.
struct SessionRecord: Codable {
    /// When the session ended (sessionResetTime of the completed session).
    let endedAt: Date
    /// Final usage percentage at session end (0–100+).
    let finalPercentage: Double
    /// The session token limit at the time.
    let sessionLimit: Int
}

/// A completed weekly period boundary snapshot.
struct WeeklyRecord: Codable {
    /// When the weekly period ended.
    let endedAt: Date
    /// Final weekly usage percentage at period end (0–100+).
    let finalPercentage: Double
    /// The weekly token limit at the time.
    let weeklyLimit: Int
    /// Reserved for future use: whether the plan changed during this period.
    let planChangedDuringPeriod: Bool
}
