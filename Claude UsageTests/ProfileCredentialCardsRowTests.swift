import XCTest
@testable import Claude_Usage

/// Tests for sidebar credential status dot reactivity.
///
/// Verifies that `ProfileCredentialCardsRow` reflects credential changes
/// immediately through ProfileManager's published activeProfile, rather than
/// requiring the view to reappear or the profile ID to change.
@MainActor
final class ProfileCredentialCardsRowTests: XCTestCase {

    private var manager: ProfileManager!
    private var seedProfile: Profile!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        manager = ProfileManager.shared

        // Seed a clean profile with no credentials
        seedProfile = Profile(name: "Sidebar Test Profile")
        manager.profiles = [seedProfile]
        manager.activeProfile = seedProfile
        ProfileStore.shared.saveProfiles([seedProfile])
        ProfileStore.shared.saveActiveProfileId(seedProfile.id)
    }

    override func tearDown() async throws {
        let cleanup = Profile(name: "Cleanup Profile")
        manager.profiles = [cleanup]
        manager.activeProfile = cleanup
        ProfileStore.shared.saveProfiles([cleanup])
        ProfileStore.shared.saveActiveProfileId(cleanup.id)
        try await super.tearDown()
    }

    // MARK: - Reactivity Tests

    /// GIVEN: A profile with no Claude.ai credentials
    /// WHEN: claudeSessionKey and organizationId are set via updateProfile
    /// THEN: activeProfile.hasClaudeAI becomes true immediately
    func testActiveProfile_ReflectsClaudeAICredentials_AfterUpdate() {
        // Pre-condition: no credentials
        XCTAssertFalse(manager.activeProfile?.hasClaudeAI ?? true,
                       "Profile should start without Claude.ai credentials")

        // Simulate what PersonalUsageViewModel.saveCredentials does
        var profile = manager.activeProfile!
        profile.claudeSessionKey = "sk-ant-sid01-test-key"
        profile.organizationId = "org-test-id"
        manager.updateProfile(profile)

        // The sidebar reads from activeProfile — should be updated immediately
        XCTAssertTrue(manager.activeProfile?.hasClaudeAI ?? false,
                      "activeProfile.hasClaudeAI should be true after setting credentials")
        XCTAssertEqual(manager.activeProfile?.claudeSessionKey, "sk-ant-sid01-test-key")
        XCTAssertEqual(manager.activeProfile?.organizationId, "org-test-id")
    }

    /// GIVEN: A profile with existing Claude.ai credentials
    /// WHEN: credentials are cleared via updateProfile
    /// THEN: activeProfile.hasClaudeAI becomes false immediately
    func testActiveProfile_ReflectsClaudeAIRemoval_AfterUpdate() {
        // Set up credentials first
        var profile = manager.activeProfile!
        profile.claudeSessionKey = "sk-ant-sid01-test-key"
        profile.organizationId = "org-test-id"
        manager.updateProfile(profile)
        XCTAssertTrue(manager.activeProfile?.hasClaudeAI ?? false)

        // Clear credentials
        var cleared = manager.activeProfile!
        cleared.claudeSessionKey = nil
        cleared.organizationId = nil
        manager.updateProfile(cleared)

        XCTAssertFalse(manager.activeProfile?.hasClaudeAI ?? true,
                       "activeProfile.hasClaudeAI should be false after clearing credentials")
    }

    /// GIVEN: A profile with no API credentials
    /// WHEN: apiSessionKey is set via updateProfile
    /// THEN: activeProfile reflects the new API key immediately
    func testActiveProfile_ReflectsAPICredentials_AfterUpdate() {
        XCTAssertNil(manager.activeProfile?.apiSessionKey,
                     "Profile should start without API credentials")

        var profile = manager.activeProfile!
        profile.apiSessionKey = "sk-ant-api-test"
        profile.apiOrganizationId = "org-api-test"
        manager.updateProfile(profile)

        XCTAssertEqual(manager.activeProfile?.apiSessionKey, "sk-ant-api-test")
        XCTAssertEqual(manager.activeProfile?.apiOrganizationId, "org-api-test")
    }

    /// GIVEN: A profile with no CLI account
    /// WHEN: hasCliAccount is set to true
    /// THEN: activeProfile.hasCliAccount is true immediately
    func testActiveProfile_ReflectsCLIAccount_AfterUpdate() {
        XCTAssertFalse(manager.activeProfile?.hasCliAccount ?? true,
                       "Profile should start without CLI account")

        var profile = manager.activeProfile!
        profile.hasCliAccount = true
        manager.updateProfile(profile)

        XCTAssertTrue(manager.activeProfile?.hasCliAccount ?? false,
                      "activeProfile.hasCliAccount should be true after update")
    }
}
