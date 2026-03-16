import Combine
import Foundation

/// ViewModel for ManageProfilesView. Routes all profile display-mode changes
/// through domain-layer methods that include notification posting, keeping the
/// view display-only.
@MainActor
final class ManageProfilesViewModel: ObservableObject {

    // MARK: - Properties

    private let profileManager = ProfileManager.shared

    // MARK: - Public Methods

    /// Switches between single and multi-profile display mode and notifies the menu bar.
    func updateDisplayMode(enabled: Bool) {
        profileManager.updateDisplayMode(enabled ? .multi : .single)
        NotificationCenter.default.post(name: .displayModeChanged, object: nil)
    }

    /// Toggles a profile's selection state for multi-profile display and notifies the menu bar.
    func toggleProfileSelection(_ profileId: UUID) {
        profileManager.toggleProfileSelection(profileId)
        NotificationCenter.default.post(name: .displayModeChanged, object: nil)
    }

    /// Applies a multi-profile configuration change and notifies the menu bar.
    func updateMultiProfileConfig(_ config: MultiProfileDisplayConfig) {
        profileManager.updateMultiProfileConfig(config)
        NotificationCenter.default.post(name: .displayModeChanged, object: nil)
    }

    /// Creates a new profile with the given name.
    func createProfile(name: String?) {
        _ = profileManager.createProfile(name: name)
    }
}
