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
        showGreyZone = DataStore.shared.loadShowGreyZone()
        greyThreshold = DataStore.shared.loadGreyThreshold()
    }
}
