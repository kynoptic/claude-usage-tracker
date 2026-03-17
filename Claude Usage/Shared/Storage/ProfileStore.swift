//
//  ProfileStore.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation

// MARK: - ProfileStoreError

/// Typed errors thrown by ProfileStore operations.
enum ProfileStoreError: LocalizedError {
    /// No profile with the given identifier exists in the store.
    case profileNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "Profile not found: \(id.uuidString)"
        }
    }
}

/// Manages storage and retrieval of profiles and profile-related data
@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private let defaults: UserDefaults
    /// Keychain service used for credential operations.
    /// Tests swap this via `@testable` to inject an in-memory backend.
    var keychainService: KeychainService = .shared

    private enum Keys {
        static let profiles = "profiles_v3"
        static let activeProfileId = "activeProfileId"
        static let displayMode = "profileDisplayMode"
        static let multiProfileConfig = "multiProfileDisplayConfig"
    }

    private init() {
        // Use standard UserDefaults (app container)
        self.defaults = UserDefaults.standard
        LoggingService.shared.log("ProfileStore: Using standard app container storage")
    }

    // MARK: - Profile Management

    func saveProfiles(_ profiles: [Profile]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            defaults.set(data, forKey: Keys.profiles)
            LoggingService.shared.log("ProfileStore: Saved \(profiles.count) profiles (\(data.count) bytes)")
        } catch {
            LoggingService.shared.logStorageError("saveProfiles", error: error)
        }
    }

    func loadProfiles() -> [Profile] {
        guard let data = defaults.data(forKey: Keys.profiles) else {
            LoggingService.shared.log("ProfileStore: No profiles found in storage")
            return []
        }

        do {
            let profiles = try JSONDecoder().decode([Profile].self, from: data)
            LoggingService.shared.log("ProfileStore: Loaded \(profiles.count) profiles from storage")
            return profiles
        } catch {
            LoggingService.shared.logStorageError("loadProfiles", error: error)
            LoggingService.shared.logError("ProfileStore: Failed to decode profiles, returning empty array")
            return []
        }
    }

    func saveActiveProfileId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: Keys.activeProfileId)
    }

    func loadActiveProfileId() -> UUID? {
        guard let uuidString = defaults.string(forKey: Keys.activeProfileId) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func saveDisplayMode(_ mode: ProfileDisplayMode) {
        defaults.set(mode.rawValue, forKey: Keys.displayMode)
    }

    func loadDisplayMode() -> ProfileDisplayMode {
        guard let rawValue = defaults.string(forKey: Keys.displayMode),
              let mode = ProfileDisplayMode(rawValue: rawValue) else {
            return .single
        }
        return mode
    }

    // MARK: - Multi-Profile Display Config

    func saveMultiProfileConfig(_ config: MultiProfileDisplayConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: Keys.multiProfileConfig)
        } catch {
            LoggingService.shared.logStorageError("saveMultiProfileConfig", error: error)
        }
    }

    func loadMultiProfileConfig() -> MultiProfileDisplayConfig {
        guard let data = defaults.data(forKey: Keys.multiProfileConfig) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(MultiProfileDisplayConfig.self, from: data)
        } catch {
            LoggingService.shared.logStorageError("loadMultiProfileConfig", error: error)
            return .default
        }
    }

    // MARK: - Credential Helpers (ADR-008: Keychain-backed)

    /// Saves credentials for a profile to the Keychain.
    /// Credential fields are NOT written to the `profiles_v3` UserDefaults blob.
    func saveProfileCredentials(_ profileId: UUID, credentials: ProfileCredentials) throws {
        let keychain = keychainService
        // Save each non-nil credential; delete the item when the value is nil.
        try saveOrDelete(credentials.claudeSessionKey,
                         profileId: profileId, type: .claudeSessionKey, keychain: keychain)
        try saveOrDelete(credentials.organizationId,
                         profileId: profileId, type: .organizationId, keychain: keychain)
        try saveOrDelete(credentials.apiSessionKey,
                         profileId: profileId, type: .apiSessionKey, keychain: keychain)
        try saveOrDelete(credentials.apiOrganizationId,
                         profileId: profileId, type: .apiOrganizationId, keychain: keychain)
        try saveOrDelete(credentials.cliCredentialsJSON,
                         profileId: profileId, type: .cliCredentialsJSON, keychain: keychain)

        // Keep hasValidOAuthCredentials in sync on the in-memory + persisted profile struct
        var profiles = loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            throw ProfileStoreError.profileNotFound(profileId)
        }
        if let json = credentials.cliCredentialsJSON {
            profiles[index].hasValidOAuthCredentials = Profile.isValidOAuthJSON(json)
        } else {
            profiles[index].hasValidOAuthCredentials = false
        }
        saveProfiles(profiles)

        LoggingService.shared.log("ProfileStore: Saved credentials for profile \(profileId) to Keychain")
    }

    /// Loads credentials for a profile from the Keychain.
    func loadProfileCredentials(_ profileId: UUID) throws -> ProfileCredentials {
        let profiles = loadProfiles()
        guard profiles.first(where: { $0.id == profileId }) != nil else {
            throw ProfileStoreError.profileNotFound(profileId)
        }
        let keychain = keychainService
        return ProfileCredentials(
            claudeSessionKey: try keychain.loadPerProfile(profileId: profileId, credentialType: .claudeSessionKey),
            organizationId: try keychain.loadPerProfile(profileId: profileId, credentialType: .organizationId),
            apiSessionKey: try keychain.loadPerProfile(profileId: profileId, credentialType: .apiSessionKey),
            apiOrganizationId: try keychain.loadPerProfile(profileId: profileId, credentialType: .apiOrganizationId),
            cliCredentialsJSON: try keychain.loadPerProfile(profileId: profileId, credentialType: .cliCredentialsJSON)
        )
    }

    // MARK: - Private Helpers

    private func saveOrDelete(_ value: String?,
                              profileId: UUID,
                              type: KeychainService.PerProfileCredentialType,
                              keychain: KeychainService) throws {
        if let value {
            try keychain.savePerProfile(value, profileId: profileId, credentialType: type)
        } else {
            try keychain.deletePerProfile(profileId: profileId, credentialType: type)
        }
    }
}
