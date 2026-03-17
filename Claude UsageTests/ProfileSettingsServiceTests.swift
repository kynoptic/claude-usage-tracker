import XCTest
@testable import Claude_Usage

/// Unit tests for ProfileSettingsService.
///
/// Tests verify that settings mutations correctly update ProfileManager's
/// in-memory state and active profile reference.
@MainActor
final class ProfileSettingsServiceTests: XCTestCase {

    private var manager: ProfileManager!
    private var settingsService: ProfileSettingsService!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        manager = ProfileManager.shared
        settingsService = ProfileSettingsService.shared

        let seed = Profile(name: "Settings Test Profile")
        manager.profiles = [seed]
        manager.activeProfile = seed
        ProfileStore.shared.saveProfiles([seed])
        ProfileStore.shared.saveActiveProfileId(seed.id)
    }

    override func tearDown() async throws {
        let cleanup = Profile(name: "Cleanup Profile")
        manager.profiles = [cleanup]
        manager.activeProfile = cleanup
        ProfileStore.shared.saveProfiles([cleanup])
        ProfileStore.shared.saveActiveProfileId(cleanup.id)
        try await super.tearDown()
    }

    // MARK: - updateIconConfig

    func testUpdateIconConfig_ChangesStoredConfig() {
        let profile = manager.profiles[0]
        var config = MenuBarIconConfiguration.default
        config.monochromeMode = true
        settingsService.updateIconConfig(config, for: profile.id)

        XCTAssertTrue(manager.profiles[0].iconConfig.monochromeMode)
    }

    func testUpdateIconConfig_UpdatesActiveProfile_WhenActive() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        var config = MenuBarIconConfiguration.default
        config.monochromeMode = true
        settingsService.updateIconConfig(config, for: profile.id)

        XCTAssertTrue(manager.activeProfile?.iconConfig.monochromeMode ?? false)
    }

    // MARK: - updateRefreshInterval

    func testUpdateRefreshInterval_ChangesValue() {
        let profile = manager.profiles[0]
        settingsService.updateRefreshInterval(120.0, for: profile.id)
        XCTAssertEqual(manager.profiles[0].refreshInterval, 120.0)
    }

    func testUpdateRefreshInterval_UpdatesActiveProfile_WhenActive() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        settingsService.updateRefreshInterval(90.0, for: profile.id)

        XCTAssertEqual(manager.activeProfile?.refreshInterval, 90.0)
    }

    // MARK: - updateAutoStartSessionEnabled

    func testUpdateAutoStartSessionEnabled_ToTrue() {
        let profile = manager.profiles[0]
        settingsService.updateAutoStartSessionEnabled(true, for: profile.id)
        XCTAssertTrue(manager.profiles[0].autoStartSessionEnabled)
    }

    func testUpdateAutoStartSessionEnabled_ToFalse() {
        var profile = manager.profiles[0]
        profile.autoStartSessionEnabled = true
        manager.profiles = [profile]

        settingsService.updateAutoStartSessionEnabled(false, for: profile.id)

        XCTAssertFalse(manager.profiles[0].autoStartSessionEnabled)
    }

    // MARK: - updateCheckOverageLimitEnabled

    func testUpdateCheckOverageLimitEnabled_ToFalse() {
        let profile = manager.profiles[0]
        settingsService.updateCheckOverageLimitEnabled(false, for: profile.id)
        XCTAssertFalse(manager.profiles[0].checkOverageLimitEnabled)
    }

    func testUpdateCheckOverageLimitEnabled_ToTrue() {
        var profile = manager.profiles[0]
        profile.checkOverageLimitEnabled = false
        manager.profiles = [profile]

        settingsService.updateCheckOverageLimitEnabled(true, for: profile.id)

        XCTAssertTrue(manager.profiles[0].checkOverageLimitEnabled)
    }

    // MARK: - updateNotificationSettings

    func testUpdateNotificationSettings_AppliesNewSettings() {
        let profile = manager.profiles[0]
        let settings = NotificationSettings(enabled: false)
        settingsService.updateNotificationSettings(settings, for: profile.id)
        XCTAssertFalse(manager.profiles[0].notificationSettings.enabled)
    }

    // MARK: - updateOrganizationId

    func testUpdateOrganizationId_SetsValue() {
        let profile = manager.profiles[0]
        settingsService.updateOrganizationId("org-abc123", for: profile.id)
        XCTAssertEqual(manager.profiles[0].organizationId, "org-abc123")
    }

    func testUpdateOrganizationId_ToNil_ClearsValue() {
        var profile = manager.profiles[0]
        profile.organizationId = "org-abc123"
        manager.profiles = [profile]

        settingsService.updateOrganizationId(nil, for: profile.id)

        XCTAssertNil(manager.profiles[0].organizationId)
    }

    // MARK: - updateAPIOrganizationId

    func testUpdateAPIOrganizationId_SetsValue() {
        let profile = manager.profiles[0]
        settingsService.updateAPIOrganizationId("api-org-xyz", for: profile.id)
        XCTAssertEqual(manager.profiles[0].apiOrganizationId, "api-org-xyz")
    }
}
