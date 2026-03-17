//
//  ProfileManager.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation
import Combine

/// Single source of truth for the profile list and active profile.
/// Views and services read profiles through this manager, never via `ProfileStore` directly.
///
/// Credential operations are delegated to `ProfileCredentialService`.
/// Settings mutations are delegated to `ProfileSettingsService`.
/// Usage data persistence is delegated to `ProfileUsageDataService`.
@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [Profile] = []
    @Published var activeProfile: Profile?
    @Published var displayMode: ProfileDisplayMode = .single
    @Published var multiProfileConfig: MultiProfileDisplayConfig = .default
    @Published var isSwitchingProfile: Bool = false

    private let profileStore = ProfileStore.shared

    private init() {}

    // MARK: - Initialization

    func loadProfiles() {
        profiles = profileStore.loadProfiles()

        // Ensure minimum 1 profile
        if profiles.isEmpty {
            let defaultProfile = createDefaultProfile()
            profiles = [defaultProfile]
            profileStore.saveProfiles(profiles)

            // On first launch, try to sync CLI credentials to the new default profile
            Task {
                await syncCLICredentialsToDefaultProfile(defaultProfile.id)
            }
        }

        // Load active profile
        if let activeId = profileStore.loadActiveProfileId(),
           let profile = profiles.first(where: { $0.id == activeId }) {
            activeProfile = profile
        } else {
            activeProfile = profiles.first
            if let first = profiles.first {
                profileStore.saveActiveProfileId(first.id)
            }
        }

        displayMode = profileStore.loadDisplayMode()
        multiProfileConfig = profileStore.loadMultiProfileConfig()

        LoggingService.shared.log("ProfileManager: Loaded \(profiles.count) profile(s), active: \(activeProfile?.name ?? "none")")
    }

    // MARK: - Profile Operations

    func createProfile(name: String? = nil, copySettingsFrom: Profile? = nil) -> Profile {
        let usedNames = profiles.map { $0.name }
        let profileName = name ?? FunnyNameGenerator.getRandomName(excluding: usedNames)

        let newProfile = Profile(
            id: UUID(),
            name: profileName,
            hasCliAccount: false,
            iconConfig: copySettingsFrom?.iconConfig ?? .default,
            refreshInterval: copySettingsFrom?.refreshInterval ?? 30.0,
            autoStartSessionEnabled: copySettingsFrom?.autoStartSessionEnabled ?? false,
            checkOverageLimitEnabled: copySettingsFrom?.checkOverageLimitEnabled ?? true,
            notificationSettings: copySettingsFrom?.notificationSettings ?? NotificationSettings(),
            isSelectedForDisplay: true
        )

        profiles.append(newProfile)
        profileStore.saveProfiles(profiles)

        LoggingService.shared.log("Created new profile: \(newProfile.name)")
        return newProfile
    }

    func updateProfile(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile

            if activeProfile?.id == profile.id {
                activeProfile = profile

                // Detailed logging for credential state
                LoggingService.shared.log("ProfileManager.updateProfile: Updated ACTIVE profile '\(profile.name)'")
                LoggingService.shared.log("  - claudeSessionKey: \(profile.claudeSessionKey == nil ? "NIL" : "EXISTS (len: \(profile.claudeSessionKey!.count))")")
                LoggingService.shared.log("  - organizationId: \(profile.organizationId == nil ? "NIL" : "EXISTS")")
                LoggingService.shared.log("  - hasClaudeAI: \(profile.hasClaudeAI)")
                LoggingService.shared.log("  - hasAnyCredentials: \(profile.hasAnyCredentials)")
                LoggingService.shared.log("  - claudeUsage: \(profile.claudeUsage == nil ? "NIL" : "EXISTS")")
            } else {
                LoggingService.shared.log("Updated profile: \(profile.name) (not active)")
            }

            profileStore.saveProfiles(profiles)
        }
    }

    func deleteProfile(_ id: UUID) async throws {
        guard profiles.count > 1 else {
            throw ProfileError.cannotDeleteLastProfile
        }

        let profileName = profiles.first(where: { $0.id == id })?.name ?? "unknown"
        let wasActive = activeProfile?.id == id

        profiles.removeAll { $0.id == id }

        // Delete credentials from Keychain before removing the profile (ADR-008)
        KeychainService.shared.deleteCredentials(for: id)

        // Switch to first remaining profile if deleted the active one
        if wasActive, let first = profiles.first {
            await activateProfile(first.id)
        }

        profileStore.saveProfiles(profiles)
        LoggingService.shared.log("Deleted profile: \(profileName)")
    }

    func toggleProfileSelection(_ id: UUID) {
        // Defer mutation to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            if let index = self.profiles.firstIndex(where: { $0.id == id }) {
                self.profiles[index].isSelectedForDisplay.toggle()
                self.profileStore.saveProfiles(self.profiles)
            }
        }
    }

    func getSelectedProfiles() -> [Profile] {
        displayMode == .single
            ? [activeProfile].compactMap { $0 }
            : profiles.filter { $0.isSelectedForDisplay }
    }

    func updateDisplayMode(_ mode: ProfileDisplayMode) {
        // Defer mutation to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            self.displayMode = mode
            self.profileStore.saveDisplayMode(mode)
            LoggingService.shared.log("Updated display mode to: \(mode.rawValue)")
        }
    }

    func updateMultiProfileConfig(_ config: MultiProfileDisplayConfig) {
        // Defer mutation to avoid "Publishing changes from within view updates" warning
        Task { @MainActor in
            self.multiProfileConfig = config
            self.profileStore.saveMultiProfileConfig(config)
            LoggingService.shared.log("Updated multi-profile config: style=\(config.iconStyle.rawValue), showWeek=\(config.showWeek)")
        }
    }

    // MARK: - Profile Activation (Centralized)

    func activateProfile(_ id: UUID) async {
        guard !isSwitchingProfile else {
            LoggingService.shared.log("Profile switch already in progress, ignoring")
            return
        }
        isSwitchingProfile = true
        defer { isSwitchingProfile = false }

        guard let profile = profiles.first(where: { $0.id == id }) else {
            LoggingService.shared.log("Profile not found: \(id)")
            return
        }

        if activeProfile?.id == id {
            LoggingService.shared.log("Profile already active: \(profile.name)")
            return
        }

        LoggingService.shared.log("Switching to profile: \(profile.name)")

        let credentialService = ProfileCredentialService.shared

        // Re-sync current profile before leaving (if CLI credentials exist)
        if let currentProfile = activeProfile, currentProfile.cliCredentialsJSON != nil {
            do {
                try await credentialService.resyncCLICredentials(forProfile: currentProfile.id)
                LoggingService.shared.log("Re-synced current profile before switching")
            } catch {
                LoggingService.shared.logError("Failed to re-sync current profile (non-fatal)", error: error)
            }
        }

        // Get the target profile from in-memory state
        guard let updatedProfile = profiles.first(where: { $0.id == id }) else {
            LoggingService.shared.log("Profile not found: \(id)")
            return
        }

        // Apply new profile's CLI credentials (if available)
        LoggingService.shared.log("Checking CLI credentials for profile '\(updatedProfile.name)': hasJSON=\(updatedProfile.cliCredentialsJSON != nil)")

        if updatedProfile.cliCredentialsJSON != nil {
            do {
                try await credentialService.applyCLICredentials(forProfile: updatedProfile.id)
                LoggingService.shared.log("Applied CLI credentials for: \(updatedProfile.name)")
            } catch {
                LoggingService.shared.logError("Failed to apply CLI credentials (non-fatal)", error: error)
            }
        } else {
            LoggingService.shared.log("Profile '\(updatedProfile.name)' has no CLI credentials JSON")
        }

        // Update last used timestamp
        var updated = updatedProfile
        updated.lastUsedAt = Date()

        if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
            profiles[index] = updated
        }

        activeProfile = updated
        profileStore.saveActiveProfileId(id)
        profileStore.saveProfiles(profiles)

        // Update statusline script if the new profile has credentials
        if updated.claudeSessionKey != nil && updated.organizationId != nil {
            do {
                try StatuslineService.shared.updateScriptsIfInstalled()
                LoggingService.shared.log("Updated statusline for profile: \(updated.name)")
            } catch {
                LoggingService.shared.logError("Failed to update statusline (non-fatal)", error: error)
            }
        }

        LoggingService.shared.log("Successfully activated profile: \(updatedProfile.name)")
    }

    // MARK: - Internal Methods

    /// Encapsulates the repeated firstIndex -> mutate -> syncActiveProfile -> save pattern.
    /// Internal visibility so extracted services can reuse the canonical mutation path.
    func updateProfile(_ id: UUID, mutate: (inout Profile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        mutate(&profiles[index])
        if activeProfile?.id == id { activeProfile = profiles[index] }
        profileStore.saveProfiles(profiles)
    }

    // MARK: - Private Methods

    /// Syncs CLI credentials to default profile on first launch only
    private func syncCLICredentialsToDefaultProfile(_ profileId: UUID) async {
        let cliSyncService = ClaudeCodeSyncService.shared
        do {
            // Attempt to read credentials from system Keychain
            guard let jsonData = try await cliSyncService.readSystemCredentials() else {
                LoggingService.shared.log("ProfileManager: No CLI credentials found in system Keychain")
                return
            }

            // Validate: not expired
            if cliSyncService.isTokenExpired(jsonData) {
                LoggingService.shared.log("ProfileManager: CLI credentials found but expired")
                return
            }

            // Validate: has valid access token
            guard cliSyncService.extractAccessToken(from: jsonData) != nil else {
                LoggingService.shared.log("ProfileManager: CLI credentials found but missing access token")
                return
            }

            // Sync to the newly created default profile
            try await ProfileCredentialService.shared.syncCLICredentials(toProfile: profileId)

            LoggingService.shared.log("ProfileManager: Successfully synced CLI credentials to default profile on first launch")

        } catch {
            LoggingService.shared.logError("ProfileManager: Failed to sync CLI credentials on first launch (non-fatal)", error: error)
            // Non-fatal: profile will be created without credentials
            // User can manually sync in settings
        }
    }

    private func createDefaultProfile() -> Profile {
        Profile(
            name: FunnyNameGenerator.getRandomName(excluding: []),
            iconConfig: .default,
            refreshInterval: 30.0,
            autoStartSessionEnabled: false,
            checkOverageLimitEnabled: true,
            notificationSettings: NotificationSettings()
        )
    }

}

// MARK: - ProfileError

enum ProfileError: LocalizedError {
    case cannotDeleteLastProfile

    var errorDescription: String? {
        switch self {
        case .cannotDeleteLastProfile:
            return "Cannot delete the last profile. At least one profile is required."
        }
    }
}
