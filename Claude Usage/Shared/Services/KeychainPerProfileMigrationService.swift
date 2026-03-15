//
//  KeychainPerProfileMigrationService.swift
//  Claude Usage
//
//  Implements ADR-008: migrates per-profile credentials from the
//  `profiles_v3` UserDefaults blob to dedicated per-profile Keychain items.
//

import Foundation

/// Migrates credentials from `profiles_v3` UserDefaults fields to per-profile
/// Keychain items as specified in ADR-008.
///
/// Run after `ProfileMigrationService.migrateIfNeeded()` at app launch so that
/// the v2 → v3 profile upgrade always precedes this pass.
@MainActor
final class KeychainPerProfileMigrationService {
    static let shared = KeychainPerProfileMigrationService()

    private let migrationKey = "didMigrateCredentialsToKeychainPerProfile"

    private init() {}

    // MARK: - Public

    /// Runs the migration once. Subsequent calls are no-ops.
    ///
    /// For each profile that has at least one non-nil credential field in
    /// `profiles_v3`, each credential is written to its per-profile Keychain
    /// item and then the field is set to `nil` on the profile struct. The
    /// updated profiles array is saved back to `profiles_v3`.
    ///
    /// If every profile migrates successfully the flag
    /// `didMigrateCredentialsToKeychainPerProfile` is set in `UserDefaults`.
    /// A per-profile failure is logged and skipped; the flag remains unset so
    /// the next launch retries.
    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            LoggingService.shared.log("KeychainPerProfileMigration: already completed, skipping")
            return
        }

        LoggingService.shared.log("KeychainPerProfileMigration: starting credential migration")

        var profiles = ProfileStore.shared.loadProfiles()
        var allSucceeded = true

        for index in profiles.indices {
            let profile = profiles[index]
            guard profile.hasAnyCredentials else { continue }

            do {
                try migrateCredentials(of: profile)
                // Nil-out credential fields on success
                profiles[index].claudeSessionKey   = nil
                profiles[index].organizationId     = nil
                profiles[index].apiSessionKey      = nil
                profiles[index].apiOrganizationId  = nil
                profiles[index].cliCredentialsJSON = nil
                LoggingService.shared.log("KeychainPerProfileMigration: migrated profile '\(profile.name)'")
            } catch {
                LoggingService.shared.logError(
                    "KeychainPerProfileMigration: failed for profile '\(profile.name)' (will retry next launch)",
                    error: error
                )
                allSucceeded = false
            }
        }

        // Persist the profiles with credential fields cleared
        ProfileStore.shared.saveProfiles(profiles)

        if allSucceeded {
            UserDefaults.standard.set(true, forKey: migrationKey)
            LoggingService.shared.log("KeychainPerProfileMigration: completed successfully")
        } else {
            LoggingService.shared.log("KeychainPerProfileMigration: completed with errors — will retry on next launch")
        }
    }

    /// Resets the migration flag (for testing and developer rollback).
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        LoggingService.shared.log("KeychainPerProfileMigration: reset migration flag")
    }

    // MARK: - Private

    private func migrateCredentials(of profile: Profile) throws {
        let keychain = KeychainService.shared
        let id = profile.id

        if let value = profile.claudeSessionKey {
            try keychain.savePerProfile(value, profileId: id, credentialType: .claudeSessionKey)
        }
        if let value = profile.organizationId {
            try keychain.savePerProfile(value, profileId: id, credentialType: .organizationId)
        }
        if let value = profile.apiSessionKey {
            try keychain.savePerProfile(value, profileId: id, credentialType: .apiSessionKey)
        }
        if let value = profile.apiOrganizationId {
            try keychain.savePerProfile(value, profileId: id, credentialType: .apiOrganizationId)
        }
        if let value = profile.cliCredentialsJSON {
            try keychain.savePerProfile(value, profileId: id, credentialType: .cliCredentialsJSON)
        }
    }
}
