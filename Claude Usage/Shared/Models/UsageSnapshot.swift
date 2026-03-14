import Foundation

/// A single point-in-time usage measurement for burn-up chart rendering
nonisolated struct UsageSnapshot: Identifiable, Sendable {
    let date: Date
    let percentage: Double

    /// Unique per-instance ID for SwiftUI ForEach diffing.
    /// Not persisted — regenerated on decode.
    let id = UUID()

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case date, percentage
    }
}

// MARK: - Equatable

nonisolated extension UsageSnapshot: Equatable {
    /// Value equality ignores `id` — two snapshots with the same date and
    /// percentage are equal regardless of their UUID.
    static func == (lhs: UsageSnapshot, rhs: UsageSnapshot) -> Bool {
        lhs.date == rhs.date && lhs.percentage == rhs.percentage
    }
}

// MARK: - Codable

nonisolated extension UsageSnapshot: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(Date.self, forKey: .date)
        self.percentage = try container.decode(Double.self, forKey: .percentage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(percentage, forKey: .percentage)
    }
}

/// Identifies which usage metric a snapshot belongs to
nonisolated enum UsageMetric: String, Codable, CaseIterable, Sendable {
    case session
    case weekly
    case opus
    case sonnet
}
