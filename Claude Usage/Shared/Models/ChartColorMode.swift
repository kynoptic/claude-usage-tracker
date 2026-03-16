import Foundation

/// Controls how the burn-up chart colors its line and area segments.
///
/// - `uniform`: Entire chart uses the current status color (existing behavior).
/// - `historical`: Each segment is colored based on the usage percentage
///   at that point in time, showing zone transitions visually.
nonisolated enum ChartColorMode: String, Codable, Equatable, Sendable {
    case uniform
    case historical
}
