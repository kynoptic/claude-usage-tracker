import Combine
import Foundation

/// ViewModel for PersonalUsageView. Routes credential load/save/remove operations
/// and notification posting through domain-layer methods.
@MainActor
final class PersonalUsageViewModel: ObservableObject {

    // MARK: - Properties

    private let profileManager = ProfileManager.shared

    // MARK: - Credential Loading

    /// Loads existing credentials for comparison during the wizard flow.
    func loadOriginalCredentials(into wizardState: inout WizardState) {
        guard let profile = profileManager.activeProfile else { return }
        if let creds = try? ProfileStore.shared.loadProfileCredentials(profile.id) {
            wizardState.originalOrgId = creds.organizationId
            wizardState.originalSessionKey = creds.claudeSessionKey
        }
    }

    /// Loads the current credential state for display.
    func loadCurrentCredentials() -> ProfileCredentials? {
        guard let profile = profileManager.activeProfile else { return nil }
        return try? ProfileStore.shared.loadProfileCredentials(profile.id)
    }

    // MARK: - Credential Removal

    /// Removes Claude.ai credentials for the active profile and updates statusline scripts.
    func removeCredentials() throws {
        guard let profileId = profileManager.activeProfile?.id else {
            LoggingService.shared.logError("PersonalUsageView: No active profile for removal")
            return
        }

        LoggingService.shared.log("PersonalUsageView: Starting credential removal for profile \(profileId)")

        do {
            try profileManager.removeClaudeAICredentials(for: profileId)
            try? StatuslineService.shared.updateScriptsIfInstalled()
            LoggingService.shared.log("PersonalUsageView: Successfully removed Claude.ai credentials")
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .error)
            ErrorPresenter.shared.showAlert(for: appError)
            LoggingService.shared.logError("PersonalUsageView: Failed to remove credentials - \(appError.message)")
            throw error
        }
    }

    // MARK: - Credential Saving (ConfirmStep)

    /// Saves Claude.ai credentials for the active profile, posts notification if changed.
    func saveCredentials(
        sessionKey: String,
        organizationId: String?,
        originalSessionKey: String?,
        originalOrgId: String?
    ) async throws {
        guard let profileId = profileManager.activeProfile?.id else { return }

        var creds = try ProfileStore.shared.loadProfileCredentials(profileId)
        creds.claudeSessionKey = sessionKey
        creds.organizationId = organizationId
        try ProfileStore.shared.saveProfileCredentials(profileId, credentials: creds)

        if var profile = profileManager.activeProfile {
            profile.claudeSessionKey = sessionKey
            profile.organizationId = organizationId
            profileManager.updateProfile(profile)
            LoggingService.shared.log("PersonalUsageView: Updated profile model with new credentials")
        }

        let keyChanged = originalSessionKey == nil || originalSessionKey != sessionKey
        let orgChanged = organizationId != originalOrgId
        if keyChanged || orgChanged {
            try? StatuslineService.shared.updateScriptsIfInstalled()
        }

        await MainActor.run {
            ErrorRecovery.shared.recordSuccess(for: .api)
            if keyChanged || orgChanged {
                NotificationCenter.default.post(name: .credentialsChanged, object: nil)
            }
        }
    }
}
