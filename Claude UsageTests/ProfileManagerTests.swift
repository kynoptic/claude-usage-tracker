import XCTest
import Security
@testable import Claude_Usage

/// Unit tests for ProfileManager.
///
/// ProfileManager is a @MainActor singleton. Tests run on the main actor
/// and seed the manager's in-memory state directly through its public API.
/// Each test calls setUp/tearDown to leave a clean baseline (one profile,
/// first profile active) so tests remain independent.
@MainActor
final class ProfileManagerTests: XCTestCase {

    private var manager: ProfileManager!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        manager = ProfileManager.shared

        // Wipe any profiles that prior tests left behind and seed a clean single profile.
        // We persist to ProfileStore so methods that reload from disk see the correct state.
        let seed = Profile(name: "Test Profile A")
        manager.profiles = [seed]
        manager.activeProfile = seed
        ProfileStore.shared.saveProfiles([seed])
        ProfileStore.shared.saveActiveProfileId(seed.id)
    }

    override func tearDown() async throws {
        // Restore a single profile so that subsequent test suites start clean.
        let cleanup = Profile(name: "Cleanup Profile")
        manager.profiles = [cleanup]
        manager.activeProfile = cleanup
        ProfileStore.shared.saveProfiles([cleanup])
        ProfileStore.shared.saveActiveProfileId(cleanup.id)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(name: String = "Profile") -> Profile {
        Profile(name: name)
    }

    // MARK: - createProfile

    func testCreateProfile_AddsToList() {
        let before = manager.profiles.count
        _ = manager.createProfile(name: "New Profile")
        XCTAssertEqual(manager.profiles.count, before + 1)
    }

    func testCreateProfile_WithExplicitName_UsesGivenName() {
        let profile = manager.createProfile(name: "My Custom Name")
        XCTAssertEqual(profile.name, "My Custom Name")
    }

    func testCreateProfile_WithoutName_AssignsGeneratedName() {
        let profile = manager.createProfile()
        XCTAssertFalse(profile.name.isEmpty, "Auto-generated name should not be empty")
    }

    func testCreateProfile_IsSelectedForDisplayByDefault() {
        let profile = manager.createProfile(name: "Selected")
        XCTAssertTrue(profile.isSelectedForDisplay)
    }

    func testCreateProfile_CopiesSettingsFromSource() {
        var source = makeProfile(name: "Source")
        source.refreshInterval = 60.0
        source.autoStartSessionEnabled = true
        source.checkOverageLimitEnabled = false
        manager.profiles = [source]

        let copy = manager.createProfile(name: "Copy", copySettingsFrom: source)

        XCTAssertEqual(copy.refreshInterval, 60.0)
        XCTAssertTrue(copy.autoStartSessionEnabled)
        XCTAssertFalse(copy.checkOverageLimitEnabled)
    }

    func testCreateProfile_WithoutCopySource_UsesDefaults() {
        let profile = manager.createProfile(name: "Default")
        XCTAssertEqual(profile.refreshInterval, 30.0)
        XCTAssertFalse(profile.autoStartSessionEnabled)
        XCTAssertTrue(profile.checkOverageLimitEnabled)
    }

    func testCreateProfile_NewProfileAppearsInList() {
        let profile = manager.createProfile(name: "Verifiable")
        XCTAssertTrue(manager.profiles.contains(where: { $0.id == profile.id }))
    }

    // MARK: - updateProfile

    func testUpdateProfile_ChangesNameInList() {
        var profile = manager.profiles[0]
        profile.name = "Updated Name"
        manager.updateProfile(profile)
        XCTAssertEqual(manager.profiles[0].name, "Updated Name")
    }

    func testUpdateProfile_UpdatesActiveProfileReference_WhenActive() {
        let active = manager.profiles[0]
        manager.activeProfile = active

        var updated = active
        updated.name = "Active Updated"
        manager.updateProfile(updated)

        XCTAssertEqual(manager.activeProfile?.name, "Active Updated")
    }

    func testUpdateProfile_DoesNotChangeActiveProfile_WhenNotActive() {
        let profileA = manager.profiles[0]
        let profileB = makeProfile(name: "Profile B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA

        var updatedB = profileB
        updatedB.name = "B Updated"
        manager.updateProfile(updatedB)

        // Active profile should be unchanged
        XCTAssertEqual(manager.activeProfile?.name, profileA.name)
    }

    func testUpdateProfile_UnknownId_DoesNothing() {
        let unknown = makeProfile(name: "Ghost")
        let beforeCount = manager.profiles.count

        manager.updateProfile(unknown)

        XCTAssertEqual(manager.profiles.count, beforeCount)
    }

    // MARK: - deleteProfile

    func testDeleteProfile_RemovesProfileFromList() async throws {
        let extra = makeProfile(name: "Extra")
        manager.profiles = [manager.profiles[0], extra]

        try await manager.deleteProfile(extra.id)

        XCTAssertFalse(manager.profiles.contains(where: { $0.id == extra.id }))
    }

    func testDeleteProfile_LastProfile_ThrowsCannotDeleteLastProfile() async {
        do {
            try await manager.deleteProfile(manager.profiles[0].id)
            XCTFail("Expected ProfileError.cannotDeleteLastProfile to be thrown")
        } catch {
            XCTAssertTrue(error is ProfileError)
            if let profileError = error as? ProfileError {
                XCTAssertEqual(profileError, .cannotDeleteLastProfile)
            }
        }
    }

    func testDeleteProfile_ProfileCountDecrements() async throws {
        let extra = makeProfile(name: "Extra")
        manager.profiles = [manager.profiles[0], extra]
        let before = manager.profiles.count

        try await manager.deleteProfile(extra.id)

        XCTAssertEqual(manager.profiles.count, before - 1)
    }

    func testDeleteProfile_WithTwoProfiles_FirstRemainsAfterDeletingSecond() async throws {
        let first = makeProfile(name: "First")
        let second = makeProfile(name: "Second")
        manager.profiles = [first, second]

        try await manager.deleteProfile(second.id)

        XCTAssertEqual(manager.profiles.count, 1)
        XCTAssertEqual(manager.profiles[0].id, first.id)
    }

    func testDeleteProfile_DeletesKeychainCredentials() async throws {
        // This test only validates Keychain cleanup when Keychain is accessible.
        // In unsigned CI the Keychain probe returns false and the test is skipped.
        let keychainProbeService = "com.claudeusagetracker.test.probe.deletecleanup"
        let probeAccount = "probe"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainProbeService,
            kSecAttrAccount as String: probeAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault, kSecAttrAccessibleWhenUnlocked, [], &accessControlError
        ) else {
            return
        }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainProbeService,
            kSecAttrAccount as String: probeAccount,
            kSecValueData as String: Data("x".utf8),
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: false
        ]
        let probeStatus = SecItemAdd(addQuery as CFDictionary, nil)
        SecItemDelete(deleteQuery as CFDictionary)
        try XCTSkipUnless(probeStatus == errSecSuccess,
                          "Keychain not accessible without code-signing entitlement")

        // Seed two profiles so deletion is allowed
        let toKeep = makeProfile(name: "Keep")
        let toDelete = makeProfile(name: "Delete Me")
        manager.profiles = [toKeep, toDelete]
        ProfileStore.shared.saveProfiles([toKeep, toDelete])

        // Write a per-profile credential for the profile we will delete
        try KeychainService.shared.savePerProfile(
            "credentials-to-clean-up",
            profileId: toDelete.id,
            credentialType: .claudeSessionKey
        )

        // Verify credential is present before deletion
        let before = try KeychainService.shared.loadPerProfile(
            profileId: toDelete.id,
            credentialType: .claudeSessionKey
        )
        XCTAssertEqual(before, "credentials-to-clean-up")

        // Delete the profile
        try await manager.deleteProfile(toDelete.id)

        // Credential must be gone from Keychain
        let after = try KeychainService.shared.loadPerProfile(
            profileId: toDelete.id,
            credentialType: .claudeSessionKey
        )
        XCTAssertNil(after, "Keychain credential must be removed when profile is deleted")
    }

    // MARK: - getSelectedProfiles

    func testGetSelectedProfiles_SingleMode_ReturnsActiveProfile() {
        let active = manager.profiles[0]
        manager.activeProfile = active
        manager.displayMode = .single

        let selected = manager.getSelectedProfiles()

        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected[0].id, active.id)
    }

    func testGetSelectedProfiles_SingleMode_NoActiveProfile_ReturnsEmpty() {
        manager.activeProfile = nil
        manager.displayMode = .single

        let selected = manager.getSelectedProfiles()

        XCTAssertTrue(selected.isEmpty)
    }

    func testGetSelectedProfiles_MultiMode_ReturnsOnlySelectedProfiles() {
        var profileA = makeProfile(name: "A")
        var profileB = makeProfile(name: "B")
        profileA.isSelectedForDisplay = true
        profileB.isSelectedForDisplay = false
        manager.profiles = [profileA, profileB]
        manager.displayMode = .multi

        let selected = manager.getSelectedProfiles()

        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected[0].id, profileA.id)
    }

    func testGetSelectedProfiles_MultiMode_AllSelected_ReturnsAll() {
        var profileA = makeProfile(name: "A")
        var profileB = makeProfile(name: "B")
        profileA.isSelectedForDisplay = true
        profileB.isSelectedForDisplay = true
        manager.profiles = [profileA, profileB]
        manager.displayMode = .multi

        let selected = manager.getSelectedProfiles()

        XCTAssertEqual(selected.count, 2)
    }

    func testGetSelectedProfiles_MultiMode_NoneSelected_ReturnsEmpty() {
        var profileA = makeProfile(name: "A")
        var profileB = makeProfile(name: "B")
        profileA.isSelectedForDisplay = false
        profileB.isSelectedForDisplay = false
        manager.profiles = [profileA, profileB]
        manager.displayMode = .multi

        let selected = manager.getSelectedProfiles()

        XCTAssertTrue(selected.isEmpty)
    }

    // MARK: - saveClaudeUsage / loadClaudeUsage

    func testSaveAndLoadClaudeUsage_RoundTrip() throws {
        let profile = manager.profiles[0]
        let usage = makeClaudeUsage(sessionPercentage: 55.0)

        manager.saveClaudeUsage(usage, for: profile.id)
        let loaded = try XCTUnwrap(manager.loadClaudeUsage(for: profile.id))

        XCTAssertEqual(loaded.sessionPercentage, 55.0)
    }

    func testSaveClaudeUsage_UpdatesActiveProfileReference() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        let usage = makeClaudeUsage(sessionPercentage: 75.0)
        manager.saveClaudeUsage(usage, for: profile.id)

        XCTAssertEqual(manager.activeProfile?.claudeUsage?.sessionPercentage, 75.0)
    }

    func testSaveClaudeUsage_DoesNotUpdateActiveProfile_WhenDifferentProfile() {
        let profileA = manager.profiles[0]
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA

        let usage = makeClaudeUsage(sessionPercentage: 80.0)
        manager.saveClaudeUsage(usage, for: profileB.id)

        // Active profile's usage should remain nil
        XCTAssertNil(manager.activeProfile?.claudeUsage)
    }

    func testSaveClaudeUsage_UnknownProfileId_DoesNothing() {
        let unknown = UUID()
        let usage = makeClaudeUsage(sessionPercentage: 50.0)

        // Should not throw or crash
        manager.saveClaudeUsage(usage, for: unknown)
    }

    func testLoadClaudeUsage_UnknownProfileId_ReturnsNil() {
        let result = manager.loadClaudeUsage(for: UUID())
        XCTAssertNil(result)
    }

    // MARK: - saveAPIUsage / loadAPIUsage

    func testSaveAndLoadAPIUsage_RoundTrip() throws {
        let profile = manager.profiles[0]
        let usage = makeAPIUsage()

        manager.saveAPIUsage(usage, for: profile.id)
        _ = try XCTUnwrap(manager.loadAPIUsage(for: profile.id))
    }

    func testSaveAPIUsage_UpdatesActiveProfileReference() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        manager.saveAPIUsage(makeAPIUsage(), for: profile.id)

        XCTAssertNotNil(manager.activeProfile?.apiUsage)
    }

    func testLoadAPIUsage_UnknownProfileId_ReturnsNil() {
        let result = manager.loadAPIUsage(for: UUID())
        XCTAssertNil(result)
    }

    // MARK: - updateIconConfig

    func testUpdateIconConfig_ChangesStoredConfig() {
        let profile = manager.profiles[0]
        var config = MenuBarIconConfiguration.default
        config.monochromeMode = true
        manager.updateIconConfig(config, for: profile.id)

        XCTAssertTrue(manager.profiles[0].iconConfig.monochromeMode)
    }

    func testUpdateIconConfig_UpdatesActiveProfile_WhenActive() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        var config = MenuBarIconConfiguration.default
        config.monochromeMode = true
        manager.updateIconConfig(config, for: profile.id)

        XCTAssertTrue(manager.activeProfile?.iconConfig.monochromeMode ?? false)
    }

    // MARK: - updateRefreshInterval

    func testUpdateRefreshInterval_ChangesValue() {
        let profile = manager.profiles[0]
        manager.updateRefreshInterval(120.0, for: profile.id)
        XCTAssertEqual(manager.profiles[0].refreshInterval, 120.0)
    }

    func testUpdateRefreshInterval_UpdatesActiveProfile_WhenActive() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        manager.updateRefreshInterval(90.0, for: profile.id)

        XCTAssertEqual(manager.activeProfile?.refreshInterval, 90.0)
    }

    // MARK: - updateAutoStartSessionEnabled

    func testUpdateAutoStartSessionEnabled_ToTrue() {
        let profile = manager.profiles[0]
        manager.updateAutoStartSessionEnabled(true, for: profile.id)
        XCTAssertTrue(manager.profiles[0].autoStartSessionEnabled)
    }

    func testUpdateAutoStartSessionEnabled_ToFalse() {
        var profile = manager.profiles[0]
        profile.autoStartSessionEnabled = true
        manager.profiles = [profile]

        manager.updateAutoStartSessionEnabled(false, for: profile.id)

        XCTAssertFalse(manager.profiles[0].autoStartSessionEnabled)
    }

    // MARK: - updateCheckOverageLimitEnabled

    func testUpdateCheckOverageLimitEnabled_ToFalse() {
        let profile = manager.profiles[0]
        manager.updateCheckOverageLimitEnabled(false, for: profile.id)
        XCTAssertFalse(manager.profiles[0].checkOverageLimitEnabled)
    }

    func testUpdateCheckOverageLimitEnabled_ToTrue() {
        var profile = manager.profiles[0]
        profile.checkOverageLimitEnabled = false
        manager.profiles = [profile]

        manager.updateCheckOverageLimitEnabled(true, for: profile.id)

        XCTAssertTrue(manager.profiles[0].checkOverageLimitEnabled)
    }

    // MARK: - updateNotificationSettings

    func testUpdateNotificationSettings_AppliesNewSettings() {
        let profile = manager.profiles[0]
        let settings = NotificationSettings(enabled: false)
        manager.updateNotificationSettings(settings, for: profile.id)
        XCTAssertFalse(manager.profiles[0].notificationSettings.enabled)
    }

    // MARK: - updateOrganizationId

    func testUpdateOrganizationId_SetsValue() {
        let profile = manager.profiles[0]
        manager.updateOrganizationId("org-abc123", for: profile.id)
        XCTAssertEqual(manager.profiles[0].organizationId, "org-abc123")
    }

    func testUpdateOrganizationId_ToNil_ClearsValue() {
        var profile = manager.profiles[0]
        profile.organizationId = "org-abc123"
        manager.profiles = [profile]

        manager.updateOrganizationId(nil, for: profile.id)

        XCTAssertNil(manager.profiles[0].organizationId)
    }

    // MARK: - updateAPIOrganizationId

    func testUpdateAPIOrganizationId_SetsValue() {
        let profile = manager.profiles[0]
        manager.updateAPIOrganizationId("api-org-xyz", for: profile.id)
        XCTAssertEqual(manager.profiles[0].apiOrganizationId, "api-org-xyz")
    }

    // MARK: - activateProfile

    func testActivateProfile_SetsActiveProfile() async {
        let profileA = makeProfile(name: "A")
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA
        // activateProfile reloads from disk, so persist both profiles
        ProfileStore.shared.saveProfiles([profileA, profileB])
        ProfileStore.shared.saveActiveProfileId(profileA.id)

        await manager.activateProfile(profileB.id)

        XCTAssertEqual(manager.activeProfile?.id, profileB.id)
    }

    func testActivateProfile_AlreadyActive_NoChange() async {
        let profile = makeProfile(name: "Already Active")
        manager.profiles = [profile]
        manager.activeProfile = profile
        ProfileStore.shared.saveProfiles([profile])
        ProfileStore.shared.saveActiveProfileId(profile.id)

        await manager.activateProfile(profile.id)

        // Should still be the same profile
        XCTAssertEqual(manager.activeProfile?.id, profile.id)
    }

    func testActivateProfile_UnknownId_NoChange() async {
        let profile = makeProfile(name: "Only Profile")
        manager.profiles = [profile]
        manager.activeProfile = profile
        ProfileStore.shared.saveProfiles([profile])
        ProfileStore.shared.saveActiveProfileId(profile.id)

        await manager.activateProfile(UUID())

        // Active should remain unchanged
        XCTAssertEqual(manager.activeProfile?.id, profile.id)
    }

    func testActivateProfile_NonExistentId_DoesNotDeadlock() async {
        let profileA = makeProfile(name: "A")
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA
        ProfileStore.shared.saveProfiles([profileA, profileB])
        ProfileStore.shared.saveActiveProfileId(profileA.id)

        // Activate a profile ID that does not exist — should not lock the switcher
        await manager.activateProfile(UUID())

        XCTAssertFalse(manager.isSwitchingProfile,
                       "isSwitchingProfile must be false after a failed lookup")

        // A subsequent valid switch must succeed (not be blocked by stale flag)
        await manager.activateProfile(profileB.id)

        XCTAssertEqual(manager.activeProfile?.id, profileB.id,
                       "Valid switch must succeed after a prior failed lookup")
    }

    func testActivateProfile_ProfileDeletedBeforeReload_DoesNotDeadlock() async {
        let profileA = makeProfile(name: "A")
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA
        // Save only profileA to disk — profileB will be missing on reload
        ProfileStore.shared.saveProfiles([profileA])
        ProfileStore.shared.saveActiveProfileId(profileA.id)

        // profileB exists in memory but not on disk; activateProfile reloads
        // from disk mid-flight and should handle the missing profile gracefully
        await manager.activateProfile(profileB.id)

        XCTAssertFalse(manager.isSwitchingProfile,
                       "isSwitchingProfile must reset when profile vanishes on disk reload")

        // Subsequent valid switch must still work
        let profileC = makeProfile(name: "C")
        manager.profiles.append(profileC)
        ProfileStore.shared.saveProfiles(manager.profiles)

        await manager.activateProfile(profileC.id)

        XCTAssertEqual(manager.activeProfile?.id, profileC.id,
                       "Valid switch must succeed after a prior mid-reload failure")
    }

    func testActivateProfile_ClearsSwitchingFlag_WhenDone() async {
        let profileA = makeProfile(name: "A")
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA
        ProfileStore.shared.saveProfiles([profileA, profileB])
        ProfileStore.shared.saveActiveProfileId(profileA.id)

        await manager.activateProfile(profileB.id)

        XCTAssertFalse(manager.isSwitchingProfile)
    }

    // MARK: - removeClaudeAICredentials

    func testRemoveClaudeAICredentials_ClearsSessionKeyAndOrgId() throws {
        var profile = manager.profiles[0]
        profile.claudeSessionKey = "sk-test"
        profile.organizationId = "org-test"
        manager.profiles = [profile]
        // Persist to disk so removeClaudeAICredentials can load/update via ProfileStore
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeClaudeAICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].claudeSessionKey)
        XCTAssertNil(manager.profiles[0].organizationId)
    }

    func testRemoveClaudeAICredentials_ClearsUsageData() throws {
        var profile = manager.profiles[0]
        profile.claudeSessionKey = "sk-test"
        profile.organizationId = "org-test"
        profile.claudeUsage = makeClaudeUsage(sessionPercentage: 50.0)
        manager.profiles = [profile]
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeClaudeAICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].claudeUsage)
    }

    func testRemoveClaudeAICredentials_UpdatesActiveProfileReference() throws {
        var profile = manager.profiles[0]
        profile.claudeSessionKey = "sk-test"
        profile.organizationId = "org-test"
        manager.profiles = [profile]
        manager.activeProfile = manager.profiles[0]
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeClaudeAICredentials(for: profile.id)

        XCTAssertNil(manager.activeProfile?.claudeSessionKey)
        XCTAssertNil(manager.activeProfile?.organizationId)
    }

    // MARK: - removeAPICredentials

    func testRemoveAPICredentials_ClearsAPIKeys() throws {
        var profile = manager.profiles[0]
        profile.apiSessionKey = "api-sk-test"
        profile.apiOrganizationId = "api-org-test"
        manager.profiles = [profile]
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeAPICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].apiSessionKey)
        XCTAssertNil(manager.profiles[0].apiOrganizationId)
    }

    func testRemoveAPICredentials_ClearsAPIUsageData() throws {
        var profile = manager.profiles[0]
        profile.apiSessionKey = "api-sk-test"
        profile.apiOrganizationId = "api-org-test"
        profile.apiUsage = makeAPIUsage()
        manager.profiles = [profile]
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeAPICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].apiUsage)
    }

    // MARK: - displayMode

    func testDisplayMode_DefaultIsSingle() {
        // After setUp, mode should be what it was; verify single mode returns active only
        manager.displayMode = .single
        let selected = manager.getSelectedProfiles()
        XCTAssertEqual(selected.count, 1)
    }

    func testDisplayMode_MultiReturnsSelectedProfiles() {
        var p1 = makeProfile(name: "P1")
        var p2 = makeProfile(name: "P2")
        p1.isSelectedForDisplay = true
        p2.isSelectedForDisplay = true
        manager.profiles = [p1, p2]
        manager.displayMode = .multi

        let selected = manager.getSelectedProfiles()
        XCTAssertEqual(selected.count, 2)
    }

    // MARK: - Edge Cases

    func testProfiles_InitiallySingleProfile_AfterSetup() {
        XCTAssertEqual(manager.profiles.count, 1)
    }

    func testActiveProfile_IsInProfilesList() {
        XCTAssertNotNil(manager.activeProfile)
        if let active = manager.activeProfile {
            XCTAssertTrue(manager.profiles.contains(where: { $0.id == active.id }))
        }
    }

    func testDeleteProfile_ActiveProfile_SwitchesImmediately() async throws {
        let first = makeProfile(name: "First")
        let second = makeProfile(name: "Second")
        manager.profiles = [first, second]
        manager.activeProfile = second
        ProfileStore.shared.saveProfiles([first, second])
        ProfileStore.shared.saveActiveProfileId(second.id)

        // Delete the active profile — activation of the remaining profile
        // must complete before deleteProfile returns (no fire-and-forget Task)
        try await manager.deleteProfile(second.id)

        XCTAssertEqual(manager.activeProfile?.id, first.id,
                        "Active profile must switch to remaining profile immediately")
        XCTAssertFalse(manager.isSwitchingProfile,
                        "Profile switch must be complete, not in-flight")
    }

    func testDeleteProfile_NonExistentId_NoThrow() async {
        // With two profiles, deleting a non-existent ID does nothing (no error)
        let nonExistentId = UUID()
        let extra = makeProfile(name: "Extra")
        manager.profiles = [manager.profiles[0], extra]

        do {
            try await manager.deleteProfile(nonExistentId)
        } catch {
            XCTFail("Deleting a non-existent profile should not throw")
        }
        XCTAssertEqual(manager.profiles.count, 2)
    }

    func testCreateMultipleProfiles_AllAppearInList() {
        let names = ["Alpha", "Beta", "Gamma"]
        for name in names {
            _ = manager.createProfile(name: name)
        }
        for name in names {
            XCTAssertTrue(manager.profiles.contains(where: { $0.name == name }),
                          "Expected profile '\(name)' to be in the list")
        }
    }

    func testSaveClaudeUsage_OverwritesPreviousUsage() {
        let profile = manager.profiles[0]
        manager.saveClaudeUsage(makeClaudeUsage(sessionPercentage: 40.0), for: profile.id)
        manager.saveClaudeUsage(makeClaudeUsage(sessionPercentage: 80.0), for: profile.id)

        XCTAssertEqual(manager.loadClaudeUsage(for: profile.id)?.sessionPercentage, 80.0)
    }

    // MARK: - CLI Sync Operations

    func testRemoveCLICredentials_ClearsCredentialsInMemory() throws {
        var profile = manager.profiles[0]
        profile.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"test-token"}}
        """
        profile.hasValidOAuthCredentials = true
        manager.profiles = [profile]
        manager.activeProfile = profile
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeCLICredentials(fromProfile: profile.id)

        XCTAssertNil(manager.profiles[0].cliCredentialsJSON,
                     "cliCredentialsJSON must be nil after removal")
        XCTAssertFalse(manager.profiles[0].hasValidOAuthCredentials,
                       "hasValidOAuthCredentials must be false after removal")
    }

    func testRemoveCLICredentials_UpdatesActiveProfileReference() throws {
        var profile = manager.profiles[0]
        profile.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"test-token"}}
        """
        profile.hasValidOAuthCredentials = true
        manager.profiles = [profile]
        manager.activeProfile = profile
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeCLICredentials(fromProfile: profile.id)

        XCTAssertNil(manager.activeProfile?.cliCredentialsJSON,
                     "activeProfile.cliCredentialsJSON must be nil after removal")
        XCTAssertFalse(manager.activeProfile?.hasValidOAuthCredentials ?? true,
                       "activeProfile.hasValidOAuthCredentials must be false after removal")
    }

    func testRemoveCLICredentials_PersistsToDisk() throws {
        var profile = manager.profiles[0]
        profile.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"test-token"}}
        """
        profile.hasValidOAuthCredentials = true
        manager.profiles = [profile]
        ProfileStore.shared.saveProfiles([profile])

        try manager.removeCLICredentials(fromProfile: profile.id)

        // Reload from disk and verify persistence
        let diskProfiles = ProfileStore.shared.loadProfiles()
        let diskProfile = diskProfiles.first(where: { $0.id == profile.id })
        XCTAssertNil(diskProfile?.cliCredentialsJSON,
                     "Disk profile must have nil cliCredentialsJSON after removal")
    }

    func testRemoveCLICredentials_UnknownId_Throws() {
        XCTAssertThrowsError(try manager.removeCLICredentials(fromProfile: UUID())) { error in
            XCTAssertTrue(error is ClaudeCodeError)
        }
    }

    func testApplyCLICredentials_NoCreds_Throws() async {
        let profile = manager.profiles[0]
        // Profile has no cliCredentialsJSON

        do {
            try await manager.applyCLICredentials(forProfile: profile.id)
            XCTFail("Expected ClaudeCodeError.noProfileCredentials")
        } catch {
            XCTAssertTrue(error is ClaudeCodeError)
        }
    }

    func testApplyCLICredentials_UnknownId_Throws() async {
        do {
            try await manager.applyCLICredentials(forProfile: UUID())
            XCTFail("Expected ClaudeCodeError.noProfileCredentials")
        } catch {
            XCTAssertTrue(error is ClaudeCodeError)
        }
    }

    func testRemoveCLICredentials_DoesNotAffectOtherProfiles() throws {
        var profileA = manager.profiles[0]
        profileA.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"token-a"}}
        """
        profileA.hasValidOAuthCredentials = true

        var profileB = makeProfile(name: "Profile B")
        profileB.cliCredentialsJSON = """
        {"claudeAiOauth":{"accessToken":"token-b"}}
        """
        profileB.hasValidOAuthCredentials = true

        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA
        ProfileStore.shared.saveProfiles([profileA, profileB])

        try manager.removeCLICredentials(fromProfile: profileA.id)

        // Profile B should be unaffected
        XCTAssertNotNil(manager.profiles[1].cliCredentialsJSON,
                        "Other profile's cliCredentialsJSON must not be affected")
        XCTAssertTrue(manager.profiles[1].hasValidOAuthCredentials,
                      "Other profile's hasValidOAuthCredentials must not be affected")
    }

    // MARK: - Private Helpers

    private func makeClaudeUsage(sessionPercentage: Double) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPercentage * 1000),
            sessionLimit: 100_000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 500_000,
            weeklyLimit: 1_000_000,
            weeklyPercentage: 50.0,
            weeklyResetTime: Date().addingTimeInterval(86_400),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )
    }

    private func makeAPIUsage() -> APIUsage {
        APIUsage(
            currentSpendCents: 123,
            resetsAt: Date().addingTimeInterval(86_400),
            prepaidCreditsCents: 10_000,
            currency: "USD"
        )
    }
}
