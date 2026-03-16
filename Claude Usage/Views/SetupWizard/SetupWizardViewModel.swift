import Combine
import Foundation

/// ViewModel for the setup wizard's confirm step. Routes credential persistence,
/// statusline updates, and notification posting through domain-layer methods.
@MainActor
final class SetupWizardViewModel: ObservableObject {

    // MARK: - Properties

    @Published private(set) var isSaving = false

    // MARK: - Public Methods

    /// Saves wizard credentials to the active profile, updates statusline scripts,
    /// marks setup as complete, and posts a credentials-changed notification.
    ///
    /// - Parameters:
    ///   - sessionKey: The Claude session key entered by the user.
    ///   - organizationId: The selected organization UUID.
    ///   - autoStartEnabled: Whether auto-start session is enabled.
    /// - Returns: `nil` on success, or an error message on failure.
    func saveConfiguration(
        sessionKey: String,
        organizationId: String?,
        autoStartEnabled: Bool
    ) async -> String? {
        isSaving = true
        defer { isSaving = false }

        do {
            guard var profile = ProfileManager.shared.activeProfile else {
                throw NSError(domain: "SetupWizard", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "No active profile found"
                ])
            }

            profile.claudeSessionKey = sessionKey
            profile.organizationId = organizationId
            profile.autoStartSessionEnabled = autoStartEnabled
            ProfileManager.shared.updateProfile(profile)
            LoggingService.shared.log("SetupWizard: Saved credentials through ProfileManager")

            try? StatuslineService.shared.updateScriptsIfInstalled()
            DataStore.shared.saveHasCompletedSetup(true)

            ErrorRecovery.shared.recordSuccess(for: .api)
            NotificationCenter.default.post(name: .credentialsChanged, object: nil)

            return nil
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .error)
            return "\(appError.message)\n\nError Code: \(appError.code.rawValue)"
        }
    }
}
