import XCTest
import Security
@testable import Claude_Usage

/// Unit tests for ProfileCredentialService.
///
/// Tests verify that credential operations correctly mutate ProfileManager's
/// in-memory state and persist through the canonical write path.
@MainActor
final class ProfileCredentialServiceTests: XCTestCase {

    private var manager: ProfileManager!
    private var credentialService: ProfileCredentialService!
    private var mockBackend: InMemoryKeychainBackend!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "ProfileCredentialServiceTests-\(UUID().uuidString)"

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        manager = ProfileManager.shared
        credentialService = ProfileCredentialService.shared

        // Inject isolated UserDefaults suite so parallel tests don't race
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        ProfileStore.shared.defaults = testDefaults

        // Inject in-memory Keychain backend so tests don't hit the real Keychain
        mockBackend = InMemoryKeychainBackend()
        let testKeychain = KeychainService(backend: mockBackend)
        ProfileStore.shared.keychainService = testKeychain
        credentialService.keychainService = testKeychain

        let seed = Profile(name: "Credential Test Profile")
        manager.profiles = [seed]
        manager.activeProfile = seed
        ProfileStore.shared.saveProfiles([seed])
        ProfileStore.shared.saveActiveProfileId(seed.id)
    }

    override func tearDown() async throws {
        // Restore real Keychain backend and UserDefaults
        ProfileStore.shared.keychainService = .shared
        ProfileStore.shared.defaults = UserDefaults.standard
        credentialService.keychainService = .shared
        mockBackend?.reset()

        // Clean up isolated suite
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil

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

    // MARK: - saveCredentials

    func testSaveCredentials_UpdatesInMemoryProfileFields() throws {
        let profile = manager.profiles[0]
        let credentials = ProfileCredentials(
            claudeSessionKey: "sk-saved",
            organizationId: "org-saved",
            apiSessionKey: "api-sk-saved",
            apiOrganizationId: "api-org-saved",
            cliCredentialsJSON: nil
        )

        try credentialService.saveCredentials(for: profile.id, credentials: credentials)

        XCTAssertEqual(manager.profiles[0].claudeSessionKey, "sk-saved")
        XCTAssertEqual(manager.profiles[0].organizationId, "org-saved")
        XCTAssertEqual(manager.profiles[0].apiSessionKey, "api-sk-saved")
        XCTAssertEqual(manager.profiles[0].apiOrganizationId, "api-org-saved")
    }

    // MARK: - removeClaudeAICredentials

    func testRemoveClaudeAICredentials_ClearsSessionKeyAndOrgId() throws {
        var profile = manager.profiles[0]
        profile.claudeSessionKey = "sk-test"
        profile.organizationId = "org-test"
        manager.profiles = [profile]
        ProfileStore.shared.saveProfiles([profile])

        try credentialService.removeClaudeAICredentials(for: profile.id)

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

        try credentialService.removeClaudeAICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].claudeUsage)
    }

    func testRemoveClaudeAICredentials_UpdatesActiveProfileReference() throws {
        var profile = manager.profiles[0]
        profile.claudeSessionKey = "sk-test"
        profile.organizationId = "org-test"
        manager.profiles = [profile]
        manager.activeProfile = manager.profiles[0]
        ProfileStore.shared.saveProfiles([profile])

        try credentialService.removeClaudeAICredentials(for: profile.id)

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

        try credentialService.removeAPICredentials(for: profile.id)

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

        try credentialService.removeAPICredentials(for: profile.id)

        XCTAssertNil(manager.profiles[0].apiUsage)
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

        try credentialService.removeCLICredentials(fromProfile: profile.id)

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

        try credentialService.removeCLICredentials(fromProfile: profile.id)

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

        try credentialService.removeCLICredentials(fromProfile: profile.id)

        let diskProfiles = ProfileStore.shared.loadProfiles()
        let diskProfile = diskProfiles.first(where: { $0.id == profile.id })
        XCTAssertNil(diskProfile?.cliCredentialsJSON,
                     "Disk profile must have nil cliCredentialsJSON after removal")
    }

    func testRemoveCLICredentials_UnknownId_Throws() {
        XCTAssertThrowsError(try credentialService.removeCLICredentials(fromProfile: UUID())) { error in
            XCTAssertTrue(error is ClaudeCodeError)
        }
    }

    func testApplyCLICredentials_NoCreds_Throws() async {
        let profile = manager.profiles[0]

        do {
            try await credentialService.applyCLICredentials(forProfile: profile.id)
            XCTFail("Expected ClaudeCodeError.noProfileCredentials")
        } catch {
            XCTAssertTrue(error is ClaudeCodeError)
        }
    }

    func testApplyCLICredentials_UnknownId_Throws() async {
        do {
            try await credentialService.applyCLICredentials(forProfile: UUID())
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

        try credentialService.removeCLICredentials(fromProfile: profileA.id)

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
