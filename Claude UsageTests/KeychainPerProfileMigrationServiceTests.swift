//
//  KeychainPerProfileMigrationServiceTests.swift
//  Claude UsageTests
//
//  Tests for KeychainPerProfileMigrationService (ADR-008).
//
//  Strategy: the migration service is @MainActor and calls KeychainService
//  internally. Keychain I/O is gated behind `keychainIsAccessible`; tests
//  that touch actual Keychain items call XCTSkipUnless so they stay green
//  in unsigned CI environments. Pure-logic tests (flag semantics, no-op on
//  already-migrated state) always run.

import XCTest
import Security
@testable import Claude_Usage

@MainActor
final class KeychainPerProfileMigrationServiceTests: XCTestCase {

    // MARK: - Properties

    private var service: KeychainPerProfileMigrationService!
    private let defaults = UserDefaults.standard
    private let migrationFlagKey = "didMigrateCredentialsToKeychainPerProfile"

    // MARK: - Keychain accessibility probe (mirrors KeychainServiceTests)

    private var keychainIsAccessible: Bool {
        let probeService = "com.claudeusagetracker.test.probe.migration"
        let probeAccount = "probe"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlocked,
            [],
            &accessControlError
        ) else {
            return false
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount,
            kSecValueData as String: Data("x".utf8),
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: false
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        SecItemDelete(deleteQuery as CFDictionary)
        return status == errSecSuccess
    }

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        service = KeychainPerProfileMigrationService.shared
        // Always reset the migration flag so tests start clean
        defaults.removeObject(forKey: migrationFlagKey)

        // Seed a single known profile in ProfileStore
        let seed = Profile(name: "Migration Test Profile")
        ProfileStore.shared.saveProfiles([seed])
        ProfileStore.shared.saveActiveProfileId(seed.id)
    }

    override func tearDown() async throws {
        // Reset flag so subsequent test suites are not affected
        defaults.removeObject(forKey: migrationFlagKey)
        try await super.tearDown()
    }

    // MARK: - Flag: not yet migrated

    func testMigrateIfNeeded_WhenFlagNotSet_FlagIsSetAfterMigration() {
        XCTAssertFalse(defaults.bool(forKey: migrationFlagKey),
                       "Flag must be absent before migration")

        service.migrateIfNeeded()

        XCTAssertTrue(defaults.bool(forKey: migrationFlagKey),
                      "Flag must be set after migration completes")
    }

    // MARK: - Flag: already migrated (no-op)

    func testMigrateIfNeeded_WhenFlagAlreadySet_IsNoOp() {
        defaults.set(true, forKey: migrationFlagKey)

        // Overwrite profiles with a profile that has credentials —
        // a second migration run must not touch them.
        var profile = Profile(name: "Already Migrated")
        profile.claudeSessionKey = "session-key-that-should-stay"
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        // Profile on disk must still have credentials untouched
        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertEqual(reloaded.first?.claudeSessionKey, "session-key-that-should-stay",
                       "Credentials must not be cleared if migration already ran")
    }

    // MARK: - Profiles with no credentials

    func testMigrateIfNeeded_ProfileWithNoCredentials_StillSetsFlagAndCleansup() {
        // Profile has no credentials — migration should be a no-op per profile
        // but still sets the flag.
        let profile = Profile(name: "Empty Profile")
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        XCTAssertTrue(defaults.bool(forKey: migrationFlagKey))
        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first?.claudeSessionKey)
        XCTAssertNil(reloaded.first?.organizationId)
        XCTAssertNil(reloaded.first?.apiSessionKey)
        XCTAssertNil(reloaded.first?.apiOrganizationId)
        XCTAssertNil(reloaded.first?.cliCredentialsJSON)
    }

    // MARK: - Credentials migrated to Keychain and removed from profile

    func testMigrateIfNeeded_ProfileWithClaudeSessionKey_WritesToKeychainAndNilsField() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let profileId = UUID()
        var profile = Profile(id: profileId, name: "Has Claude Key")
        profile.claudeSessionKey = "test-claude-session-key"
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        // Credential must be in Keychain
        let stored = try KeychainService.shared.loadPerProfile(
            profileId: profileId,
            credentialType: .claudeSessionKey
        )
        XCTAssertEqual(stored, "test-claude-session-key",
                       "claudeSessionKey must be written to Keychain")

        // Field must be nil on disk
        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == profileId })?.claudeSessionKey,
                     "claudeSessionKey must be nil in profiles_v3 after migration")

        // Cleanup
        try? KeychainService.shared.deletePerProfile(
            profileId: profileId,
            credentialType: .claudeSessionKey
        )
    }

    func testMigrateIfNeeded_ProfileWithAPISessionKey_WritesToKeychainAndNilsField() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let profileId = UUID()
        var profile = Profile(id: profileId, name: "Has API Key")
        profile.apiSessionKey = "test-api-session-key"
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        let stored = try KeychainService.shared.loadPerProfile(
            profileId: profileId,
            credentialType: .apiSessionKey
        )
        XCTAssertEqual(stored, "test-api-session-key")

        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == profileId })?.apiSessionKey)

        // Cleanup
        try? KeychainService.shared.deletePerProfile(
            profileId: profileId,
            credentialType: .apiSessionKey
        )
    }

    func testMigrateIfNeeded_ProfileWithCLICredentials_WritesToKeychainAndNilsField() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let profileId = UUID()
        var profile = Profile(id: profileId, name: "Has CLI Creds")
        profile.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"test-oauth-token"}}
        """
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        let stored = try KeychainService.shared.loadPerProfile(
            profileId: profileId,
            credentialType: .cliCredentialsJSON
        )
        XCTAssertNotNil(stored)

        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == profileId })?.cliCredentialsJSON)

        // Cleanup
        try? KeychainService.shared.deletePerProfile(
            profileId: profileId,
            credentialType: .cliCredentialsJSON
        )
    }

    // MARK: - Multiple profiles

    func testMigrateIfNeeded_TwoProfiles_BothMigrated() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let idA = UUID()
        let idB = UUID()
        var profA = Profile(id: idA, name: "A")
        var profB = Profile(id: idB, name: "B")
        profA.claudeSessionKey = "key-A"
        profB.claudeSessionKey = "key-B"
        ProfileStore.shared.saveProfiles([profA, profB])

        service.migrateIfNeeded()

        let storedA = try KeychainService.shared.loadPerProfile(
            profileId: idA, credentialType: .claudeSessionKey
        )
        let storedB = try KeychainService.shared.loadPerProfile(
            profileId: idB, credentialType: .claudeSessionKey
        )
        XCTAssertEqual(storedA, "key-A")
        XCTAssertEqual(storedB, "key-B")

        // Fields nil on disk for both
        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == idA })?.claudeSessionKey)
        XCTAssertNil(reloaded.first(where: { $0.id == idB })?.claudeSessionKey)

        // Cleanup
        try? KeychainService.shared.deletePerProfile(profileId: idA, credentialType: .claudeSessionKey)
        try? KeychainService.shared.deletePerProfile(profileId: idB, credentialType: .claudeSessionKey)
    }

    // MARK: - Organization IDs also migrated

    func testMigrateIfNeeded_OrganizationId_WritesToKeychainAndNilsField() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let profileId = UUID()
        var profile = Profile(id: profileId, name: "Has Org ID")
        profile.organizationId = "org-abc123"
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        let stored = try KeychainService.shared.loadPerProfile(
            profileId: profileId,
            credentialType: .organizationId
        )
        XCTAssertEqual(stored, "org-abc123")

        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == profileId })?.organizationId)

        try? KeychainService.shared.deletePerProfile(profileId: profileId, credentialType: .organizationId)
    }

    func testMigrateIfNeeded_APIOrganizationId_WritesToKeychainAndNilsField() throws {
        try XCTSkipUnless(keychainIsAccessible,
                          "Keychain not accessible without code-signing entitlement")

        let profileId = UUID()
        var profile = Profile(id: profileId, name: "Has API Org ID")
        profile.apiOrganizationId = "api-org-xyz"
        ProfileStore.shared.saveProfiles([profile])

        service.migrateIfNeeded()

        let stored = try KeychainService.shared.loadPerProfile(
            profileId: profileId,
            credentialType: .apiOrganizationId
        )
        XCTAssertEqual(stored, "api-org-xyz")

        let reloaded = ProfileStore.shared.loadProfiles()
        XCTAssertNil(reloaded.first(where: { $0.id == profileId })?.apiOrganizationId)

        try? KeychainService.shared.deletePerProfile(profileId: profileId, credentialType: .apiOrganizationId)
    }

    // MARK: - resetMigration helper

    func testResetMigration_ClearsMigrationFlag() {
        defaults.set(true, forKey: migrationFlagKey)
        XCTAssertTrue(defaults.bool(forKey: migrationFlagKey))

        service.resetMigration()

        XCTAssertFalse(defaults.bool(forKey: migrationFlagKey))
    }
}
