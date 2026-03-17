import Combine
import Foundation

/// ViewModel for APIBillingView. Routes credential load/save/remove operations
/// and notification posting through domain-layer methods.
@MainActor
final class APIBillingViewModel: ObservableObject {

    // MARK: - Properties

    private let profileManager = ProfileManager.shared

    // MARK: - Credential Loading

    /// Loads existing API credentials for comparison during the wizard flow.
    func loadOriginalCredentials(into wizardState: inout APIWizardState) {
        guard let profile = profileManager.activeProfile else { return }
        if let creds = try? ProfileStore.shared.loadProfileCredentials(profile.id) {
            wizardState.originalOrgId = creds.apiOrganizationId
            wizardState.originalApiSessionKey = creds.apiSessionKey
        }
    }

    /// Loads the current credential state for display.
    func loadCurrentCredentials() -> ProfileCredentials? {
        guard let profile = profileManager.activeProfile else { return nil }
        return try? ProfileStore.shared.loadProfileCredentials(profile.id)
    }

    // MARK: - Credential Removal

    /// Removes API Console credentials for the active profile.
    func removeCredentials() throws {
        guard let profileId = profileManager.activeProfile?.id else {
            LoggingService.shared.logError("APIBillingView: No active profile for removal")
            return
        }

        LoggingService.shared.log("APIBillingView: Starting credential removal for profile \(profileId)")

        do {
            try ProfileCredentialService.shared.removeAPICredentials(for: profileId)
            LoggingService.shared.log("APIBillingView: Successfully removed API Console credentials")
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .error)
            ErrorPresenter.shared.showAlert(for: appError)
            LoggingService.shared.logError("APIBillingView: Failed to remove credentials - \(appError.message)")
            throw error
        }
    }

    // MARK: - Credential Saving (APIConfirmStep)

    /// Saves API Console credentials for the active profile, posts notification if changed.
    func saveCredentials(
        apiSessionKey: String,
        organizationId: String?,
        originalApiSessionKey: String?,
        originalOrgId: String?
    ) async throws {
        guard let profileId = profileManager.activeProfile?.id else { return }

        var creds = try ProfileStore.shared.loadProfileCredentials(profileId)
        creds.apiSessionKey = apiSessionKey
        creds.apiOrganizationId = organizationId
        try ProfileStore.shared.saveProfileCredentials(profileId, credentials: creds)

        if var profile = profileManager.activeProfile {
            profile.apiSessionKey = apiSessionKey
            profile.apiOrganizationId = organizationId
            profileManager.updateProfile(profile)
            LoggingService.shared.log("APIBillingView: Updated profile model with new credentials")
        }

        await MainActor.run {
            ErrorRecovery.shared.recordSuccess(for: .api)
            let keyChanged = originalApiSessionKey == nil || originalApiSessionKey != apiSessionKey
            let orgChanged = organizationId != originalOrgId
            if keyChanged || orgChanged {
                NotificationCenter.default.post(name: .credentialsChanged, object: nil)
            }
        }
    }
}
