import Foundation

/// Timing context for pacing status calculations.
nonisolated struct PacingContext: Equatable, Sendable {
    /// Fraction (0…1) of the current session that has elapsed.
    let elapsedFraction: Double?

    /// No timing data available.
    static let none = PacingContext(elapsedFraction: nil)
}

// MARK: - Boundary Records (dormant — reserved for future history display)

/// A completed session boundary snapshot.
nonisolated struct SessionRecord: Codable, Sendable {
    let endedAt: Date
    let finalPercentage: Double
    let sessionLimit: Int
}

/// A completed weekly period boundary snapshot.
nonisolated struct WeeklyRecord: Codable, Sendable {
    let endedAt: Date
    let finalPercentage: Double
    let weeklyLimit: Int
    /// Reserved for future use.
    let planChangedDuringPeriod: Bool
}
