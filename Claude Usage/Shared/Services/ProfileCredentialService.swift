//
//  ProfileCredentialService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-16.
//

import Foundation

/// Manages credential operations for profiles: load, save, remove, and CLI sync.
///
/// Extracted from `ProfileManager` to reduce god-object complexity.
/// Reads and mutates profile state through `ProfileManager.shared`.
@MainActor
final class ProfileCredentialService {
    static let shared = ProfileCredentialService()

    private let profileStore = ProfileStore.shared
    private let cliSyncService = ClaudeCodeSyncService.shared

    /// Keychain service used for direct credential deletion.
    /// Tests swap this via `@testable` to inject an in-memory backend.
    var keychainService: KeychainService = .shared

    private init() {}

    // MARK: - Credential CRUD

    /// Loads credentials for a profile from the Keychain.
    func loadCredentials(for profileId: UUID) throws -> ProfileCredentials {
        try profileStore.loadProfileCredentials(profileId)
    }

    /// Saves credentials for a profile and updates in-memory profile state.
    ///
    /// Note: This triggers two disk writes — one from `ProfileStore.saveProfileCredentials`
    /// (which persists the Keychain entries and calls `saveProfiles`), and one from
    /// `updateProfile` (which saves the in-memory mutation). The double write is acceptable
    /// because correctness requires both the Keychain and in-memory state to stay in sync.
    func saveCredentials(for profileId: UUID, credentials: ProfileCredentials) throws {
        try profileStore.saveProfileCredentials(profileId, credentials: credentials)

        let manager = ProfileManager.shared
        manager.updateProfile(profileId) { profile in
            profile.claudeSessionKey = credentials.claudeSessionKey
            profile.organizationId = credentials.organizationId
            profile.apiSessionKey = credentials.apiSessionKey
            profile.apiOrganizationId = credentials.apiOrganizationId
            profile.cliCredentialsJSON = credentials.cliCredentialsJSON
            profile.hasValidOAuthCredentials = credentials.cliCredentialsJSON.map {
                Profile.isValidOAuthJSON($0)
            } ?? false
        }
    }

    /// Removes Claude.ai credentials for a profile.
    ///
    /// Deliberate behaviour change from original `ProfileManager` implementation:
    /// deletes Keychain items directly instead of the old load-mutate-save round-trip.
    func removeClaudeAICredentials(for profileId: UUID) throws {
        // Delete Keychain items directly — avoids disk round-trip through ProfileStore
        let keychain = keychainService
        try keychain.deletePerProfile(profileId: profileId, credentialType: .claudeSessionKey)
        try keychain.deletePerProfile(profileId: profileId, credentialType: .organizationId)

        let manager = ProfileManager.shared
        manager.updateProfile(profileId) { profile in
            profile.claudeSessionKey = nil
            profile.organizationId = nil
            profile.claudeUsage = nil
        }

        LoggingService.shared.log("ProfileCredentialService: Removed Claude.ai credentials for profile \(profileId)")

        NotificationCenter.default.post(name: .credentialsChanged, object: nil)
    }

    /// Removes API Console credentials for a profile.
    ///
    /// Deliberate behaviour change from original `ProfileManager` implementation:
    /// deletes Keychain items directly instead of the old load-mutate-save round-trip.
    func removeAPICredentials(for profileId: UUID) throws {
        // Delete Keychain items directly — avoids disk round-trip through ProfileStore
        let keychain = keychainService
        try keychain.deletePerProfile(profileId: profileId, credentialType: .apiSessionKey)
        try keychain.deletePerProfile(profileId: profileId, credentialType: .apiOrganizationId)

        let manager = ProfileManager.shared
        manager.updateProfile(profileId) { profile in
            profile.apiSessionKey = nil
            profile.apiOrganizationId = nil
            profile.apiUsage = nil
        }

        LoggingService.shared.log("ProfileCredentialService: Removed API credentials for profile \(profileId)")

        NotificationCenter.default.post(name: .credentialsChanged, object: nil)
    }

    // MARK: - CLI Sync Operations

    /// Syncs CLI credentials from system Keychain to a profile (one-time copy).
    func syncCLICredentials(toProfile profileId: UUID) async throws {
        let jsonData = try await cliSyncService.readAndValidateSystemCredentials()

        guard ProfileManager.shared.profiles.contains(where: { $0.id == profileId }) else {
            throw ClaudeCodeError.noProfileCredentials
        }

        ProfileManager.shared.updateProfile(profileId) { profile in
            profile.cliCredentialsJSON = jsonData
            profile.hasValidOAuthCredentials = Profile.isValidOAuthJSON(jsonData)
        }

        LoggingService.shared.log("Synced CLI credentials to profile: \(profileId)")
    }

    /// Applies a profile's CLI credentials to the system Keychain.
    func applyCLICredentials(forProfile profileId: UUID) async throws {
        LoggingService.shared.log("Applying CLI credentials for profile: \(profileId)")

        guard let profile = ProfileManager.shared.profiles.first(where: { $0.id == profileId }),
              let jsonData = profile.cliCredentialsJSON else {
            LoggingService.shared.log("No CLI credentials found for profile: \(profileId)")
            throw ClaudeCodeError.noProfileCredentials
        }

        LoggingService.shared.log("Found CLI credentials, writing to keychain...")
        try await cliSyncService.writeSystemCredentials(jsonData)

        LoggingService.shared.log("Applied profile CLI credentials to system: \(profileId)")
    }

    /// Removes CLI credentials from a profile (doesn't affect system Keychain).
    func removeCLICredentials(fromProfile profileId: UUID) throws {
        guard ProfileManager.shared.profiles.contains(where: { $0.id == profileId }) else {
            throw ClaudeCodeError.noProfileCredentials
        }

        ProfileManager.shared.updateProfile(profileId) { profile in
            profile.cliCredentialsJSON = nil
            profile.hasValidOAuthCredentials = false
        }

        LoggingService.shared.log("Removed CLI credentials from profile: \(profileId)")
    }

    /// Re-syncs fresh credentials from system Keychain into a profile before switching.
    func resyncCLICredentials(forProfile profileId: UUID) async throws {
        LoggingService.shared.log("Re-syncing CLI credentials before profile switch: \(profileId)")

        guard let freshJSON = try await cliSyncService.readFreshSystemCredentials() else {
            LoggingService.shared.log("No system credentials found - skipping re-sync")
            return
        }

        guard ProfileManager.shared.profiles.contains(where: { $0.id == profileId }) else {
            return
        }

        ProfileManager.shared.updateProfile(profileId) { profile in
            profile.cliCredentialsJSON = freshJSON
            profile.hasValidOAuthCredentials = Profile.isValidOAuthJSON(freshJSON)
            profile.cliAccountSyncedAt = Date()
        }

        LoggingService.shared.log("Re-synced CLI credentials from system and updated timestamp")
    }
}
