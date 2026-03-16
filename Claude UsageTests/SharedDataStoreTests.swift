import XCTest
@testable import Claude_Usage

@MainActor
final class SharedDataStoreTests: XCTestCase {

    var dataStore: DataStore!
    var statuslineConfigStore: StatuslineConfigStore!
    var setupPromptStore: SetupPromptStore!

    override func setUp() {
        super.setUp()
        dataStore = DataStore.shared
        statuslineConfigStore = StatuslineConfigStore.shared
        setupPromptStore = SetupPromptStore.shared
    }

    override func tearDown() {
        // Clean up test data
        super.tearDown()
    }

    // MARK: - Language Settings Tests

    func testLanguageCode() {
        dataStore.saveLanguageCode("en")
        XCTAssertEqual(dataStore.loadLanguageCode(), "en")

        dataStore.saveLanguageCode("ko")
        XCTAssertEqual(dataStore.loadLanguageCode(), "ko")

        dataStore.saveLanguageCode("ja")
        XCTAssertEqual(dataStore.loadLanguageCode(), "ja")
    }

    func testLanguageCodeNil() {
        // Should return nil when not set (fresh state)
        // Note: Can't easily test this without clearing UserDefaults entirely
        // but we can test saving and loading works
        dataStore.saveLanguageCode("fr")
        XCTAssertNotNil(dataStore.loadLanguageCode())
    }

    // MARK: - Statusline Configuration Tests

    func testStatuslineShowDirectory() {
        statuslineConfigStore.saveStatuslineShowDirectory(false)
        XCTAssertFalse(statuslineConfigStore.loadStatuslineShowDirectory())

        statuslineConfigStore.saveStatuslineShowDirectory(true)
        XCTAssertTrue(statuslineConfigStore.loadStatuslineShowDirectory())
    }

    func testStatuslineShowBranch() {
        statuslineConfigStore.saveStatuslineShowBranch(false)
        XCTAssertFalse(statuslineConfigStore.loadStatuslineShowBranch())

        statuslineConfigStore.saveStatuslineShowBranch(true)
        XCTAssertTrue(statuslineConfigStore.loadStatuslineShowBranch())
    }

    func testStatuslineShowUsage() {
        statuslineConfigStore.saveStatuslineShowUsage(false)
        XCTAssertFalse(statuslineConfigStore.loadStatuslineShowUsage())

        statuslineConfigStore.saveStatuslineShowUsage(true)
        XCTAssertTrue(statuslineConfigStore.loadStatuslineShowUsage())
    }

    func testStatuslineShowProgressBar() {
        statuslineConfigStore.saveStatuslineShowProgressBar(false)
        XCTAssertFalse(statuslineConfigStore.loadStatuslineShowProgressBar())

        statuslineConfigStore.saveStatuslineShowProgressBar(true)
        XCTAssertTrue(statuslineConfigStore.loadStatuslineShowProgressBar())
    }

    func testStatuslineShowResetTime() {
        statuslineConfigStore.saveStatuslineShowResetTime(false)
        XCTAssertFalse(statuslineConfigStore.loadStatuslineShowResetTime())

        statuslineConfigStore.saveStatuslineShowResetTime(true)
        XCTAssertTrue(statuslineConfigStore.loadStatuslineShowResetTime())
    }

    // MARK: - Setup Status Tests

    func testHasCompletedSetup() {
        setupPromptStore.saveHasCompletedSetup(false)
        XCTAssertFalse(setupPromptStore.hasCompletedSetup())

        setupPromptStore.saveHasCompletedSetup(true)
        XCTAssertTrue(setupPromptStore.hasCompletedSetup())
    }

    // MARK: - GitHub Star Prompt Tests

    func testFirstLaunchDate() {
        let testDate = Date()
        setupPromptStore.saveFirstLaunchDate(testDate)

        let loaded = setupPromptStore.loadFirstLaunchDate()
        XCTAssertNotNil(loaded)

        // Compare timestamps (allow 1 second difference for encoding/decoding)
        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testLastGitHubStarPromptDate() {
        let testDate = Date()
        setupPromptStore.saveLastGitHubStarPromptDate(testDate)

        let loaded = setupPromptStore.loadLastGitHubStarPromptDate()
        XCTAssertNotNil(loaded)

        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testHasStarredGitHub() {
        setupPromptStore.saveHasStarredGitHub(false)
        XCTAssertFalse(setupPromptStore.loadHasStarredGitHub())

        setupPromptStore.saveHasStarredGitHub(true)
        XCTAssertTrue(setupPromptStore.loadHasStarredGitHub())
    }

    func testNeverShowGitHubPrompt() {
        setupPromptStore.saveNeverShowGitHubPrompt(false)
        XCTAssertFalse(setupPromptStore.loadNeverShowGitHubPrompt())

        setupPromptStore.saveNeverShowGitHubPrompt(true)
        XCTAssertTrue(setupPromptStore.loadNeverShowGitHubPrompt())
    }

    func testShouldShowGitHubStarPrompt() {
        // Reset state
        setupPromptStore.saveHasStarredGitHub(false)
        setupPromptStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 3 days ago
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        setupPromptStore.saveFirstLaunchDate(threeDaysAgo)

        // GitHubStarPromptManager.shared uses SetupPromptStore.shared (same instance as setupPromptStore)
        // so state set above is visible to the manager
        XCTAssertTrue(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())

        // Mark as starred - should no longer show
        setupPromptStore.saveHasStarredGitHub(true)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())

        // Reset starred, set never show - should not show
        setupPromptStore.saveHasStarredGitHub(false)
        setupPromptStore.saveNeverShowGitHubPrompt(true)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())
    }

    func testShouldNotShowGitHubPromptWhenTooEarly() {
        // Reset state
        setupPromptStore.saveHasStarredGitHub(false)
        setupPromptStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 12 hours ago (less than 1 day threshold)
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 60 * 60)
        setupPromptStore.saveFirstLaunchDate(twelveHoursAgo)

        // GitHubStarPromptManager.shared uses SetupPromptStore.shared (same instance as setupPromptStore)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())
    }

    func testResetGitHubStarPromptForTesting() {
        // Set some state
        setupPromptStore.saveHasStarredGitHub(true)
        setupPromptStore.saveNeverShowGitHubPrompt(true)
        setupPromptStore.saveLastGitHubStarPromptDate(Date())

        // Reset for testing
        setupPromptStore.resetGitHubStarPromptForTesting()

        // Should be reset
        XCTAssertFalse(setupPromptStore.loadHasStarredGitHub())
        XCTAssertFalse(setupPromptStore.loadNeverShowGitHubPrompt())
        XCTAssertNil(setupPromptStore.loadLastGitHubStarPromptDate())
    }
}
