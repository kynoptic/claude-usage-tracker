import Combine
import Foundation

// MARK: - SmartUsageDashboardViewModel

/// ViewModel for SmartUsageDashboard. Owns all DataStore reads and exposes
/// display settings as @Published properties so the view stays display-only.
@MainActor
final class SmartUsageDashboardViewModel: ObservableObject {

    // MARK: - Properties

    /// Whether API usage tracking is enabled globally.
    @Published private(set) var isAPITrackingEnabled: Bool = false

    /// Whether the grey zone is shown on usage cards.
    @Published private(set) var showGreyZone: Bool = false

    /// Threshold (0.1...0.8) below which usage is shown in grey.
    @Published private(set) var greyThreshold: Double = Constants.greyThresholdDefault

    // MARK: - Initialization

    init() {
        reload()
    }

    // MARK: - Public Methods

    /// Refreshes all settings from DataStore.
    func reload() {
        isAPITrackingEnabled = DataStore.shared.loadAPITrackingEnabled()
        showGreyZone = AppearanceStore.shared.loadShowGreyZone()
        greyThreshold = AppearanceStore.shared.loadGreyThreshold()
    }

    // MARK: - Display String Derivations

    /// Formatted staleness label: explains how long ago data was fetched.
    /// Pure function — depends only on its arguments, no instance state.
    nonisolated static func stalenessLabel(lastSuccessfulFetch: Date?, at now: Date) -> String {
        guard let lastFetch = lastSuccessfulFetch else { return "No data yet" }
        let elapsed = now.timeIntervalSince(lastFetch)
        if elapsed < 60 {
            return "Updated just now"
        } else if elapsed < 3600 {
            return "Updated \(Int(elapsed / 60))m ago"
        } else {
            return "Updated \(Int(elapsed / 3600))h ago"
        }
    }

    /// Actionable error message for non-rate-limit errors.
    /// Returns nil when there is no error or when the error is rate-limited
    /// (handled separately by the countdown banner).
    nonisolated static func errorBannerText(for error: AppError?) -> String? {
        guard let error = error else { return nil }
        switch error.code {
        case .apiRateLimited:
            return nil  // Handled by countdown banner
        case .apiUnauthorized:
            return "Auth expired — re-sync in Settings"
        case .sessionKeyNotFound:
            return "No credentials — configure in Settings"
        default:
            return error.message
        }
    }

    /// Formats remaining seconds as a compact countdown string.
    nonisolated static func countdownText(until date: Date, now: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        if remaining == 0 {
            return "Rate limited — retrying now…"
        }
        if remaining >= 60 {
            return "Rate limited — retrying in \(remaining / 60)m \(remaining % 60)s"
        }
        return "Rate limited — retrying in \(remaining)s"
    }
}
