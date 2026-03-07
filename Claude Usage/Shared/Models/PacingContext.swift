import Foundation

/// Timing context for pacing status calculations.
struct PacingContext: Equatable {
    /// Fraction (0…1) of the current session that has elapsed.
    let elapsedFraction: Double?

    /// No timing data available.
    static let none = PacingContext(elapsedFraction: nil)
}

// MARK: - Boundary Records (dormant — reserved for future history display)

/// A completed session boundary snapshot.
struct SessionRecord: Codable {
    let endedAt: Date
    let finalPercentage: Double
    let sessionLimit: Int
}

/// A completed weekly period boundary snapshot.
struct WeeklyRecord: Codable {
    let endedAt: Date
    let finalPercentage: Double
    let weeklyLimit: Int
    /// Reserved for future use.
    let planChangedDuringPeriod: Bool
}
