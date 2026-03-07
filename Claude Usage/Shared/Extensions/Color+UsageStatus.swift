import SwiftUI
import Cocoa

extension Color {
    /// Returns the pacing colour for the given `UsageStatus`.
    ///
    /// Delegates to `UsageStatusCalculator.color(for:)` which returns flat
    /// Apple system colours. `Color(nsColor:)` bridges correctly on macOS 12+.
    static func usageStatus(_ status: UsageStatus) -> Color {
        Color(UsageStatusCalculator.color(for: status))
    }
}
