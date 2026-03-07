import SwiftUI
import Cocoa

extension Color {
    /// Returns the adaptive pacing colour for the given `UsageStatus`.
    ///
    /// Delegates to `UsageStatusCalculator.color(for:)` so that HSB interpolation
    /// logic lives in one place. `Color(nsColor:)` bridges correctly on macOS 12+.
    static func usageStatus(_ status: UsageStatus) -> Color {
        Color(UsageStatusCalculator.color(for: status))
    }
}
