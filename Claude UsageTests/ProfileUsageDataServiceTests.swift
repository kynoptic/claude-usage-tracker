import XCTest
@testable import Claude_Usage

/// Unit tests for ProfileUsageDataService.
///
/// Tests verify that usage data operations correctly mutate ProfileManager's
/// in-memory state through the canonical mutation path.
@MainActor
final class ProfileUsageDataServiceTests: XCTestCase {

    private var manager: ProfileManager!
    private var usageService: ProfileUsageDataService!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        manager = ProfileManager.shared
        usageService = ProfileUsageDataService.shared

        let seed = Profile(name: "Usage Test Profile")
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

    // MARK: - Helpers

    private func makeProfile(name: String = "Profile") -> Profile {
        Profile(name: name)
    }

    // MARK: - saveClaudeUsage / loadClaudeUsage

    func testSaveAndLoadClaudeUsage_RoundTrip() throws {
        let profile = manager.profiles[0]
        let usage = makeClaudeUsage(sessionPercentage: 55.0)

        usageService.saveClaudeUsage(usage, for: profile.id)
        let loaded = try XCTUnwrap(usageService.loadClaudeUsage(for: profile.id))

        XCTAssertEqual(loaded.sessionPercentage, 55.0)
    }

    func testSaveClaudeUsage_UpdatesActiveProfileReference() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        let usage = makeClaudeUsage(sessionPercentage: 75.0)
        usageService.saveClaudeUsage(usage, for: profile.id)

        XCTAssertEqual(manager.activeProfile?.claudeUsage?.sessionPercentage, 75.0)
    }

    func testSaveClaudeUsage_DoesNotUpdateActiveProfile_WhenDifferentProfile() {
        let profileA = manager.profiles[0]
        let profileB = makeProfile(name: "B")
        manager.profiles = [profileA, profileB]
        manager.activeProfile = profileA

        let usage = makeClaudeUsage(sessionPercentage: 80.0)
        usageService.saveClaudeUsage(usage, for: profileB.id)

        XCTAssertNil(manager.activeProfile?.claudeUsage)
    }

    func testSaveClaudeUsage_UnknownProfileId_DoesNothing() {
        let unknown = UUID()
        let usage = makeClaudeUsage(sessionPercentage: 50.0)

        // Should not throw or crash
        usageService.saveClaudeUsage(usage, for: unknown)
    }

    func testLoadClaudeUsage_UnknownProfileId_ReturnsNil() {
        let result = usageService.loadClaudeUsage(for: UUID())
        XCTAssertNil(result)
    }

    func testSaveClaudeUsage_OverwritesPreviousUsage() {
        let profile = manager.profiles[0]
        usageService.saveClaudeUsage(makeClaudeUsage(sessionPercentage: 40.0), for: profile.id)
        usageService.saveClaudeUsage(makeClaudeUsage(sessionPercentage: 80.0), for: profile.id)

        XCTAssertEqual(usageService.loadClaudeUsage(for: profile.id)?.sessionPercentage, 80.0)
    }

    // MARK: - saveAPIUsage / loadAPIUsage

    func testSaveAndLoadAPIUsage_RoundTrip() throws {
        let profile = manager.profiles[0]
        let usage = makeAPIUsage()

        usageService.saveAPIUsage(usage, for: profile.id)
        _ = try XCTUnwrap(usageService.loadAPIUsage(for: profile.id))
    }

    func testSaveAPIUsage_UpdatesActiveProfileReference() {
        let profile = manager.profiles[0]
        manager.activeProfile = profile

        usageService.saveAPIUsage(makeAPIUsage(), for: profile.id)

        XCTAssertNotNil(manager.activeProfile?.apiUsage)
    }

    func testLoadAPIUsage_UnknownProfileId_ReturnsNil() {
        let result = usageService.loadAPIUsage(for: UUID())
        XCTAssertNil(result)
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
