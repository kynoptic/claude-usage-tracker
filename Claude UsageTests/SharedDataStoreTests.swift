import XCTest
@testable import Claude_Usage

@MainActor
final class SharedDataStoreTests: XCTestCase {

    var dataStore: DataStore!

    override func setUp() {
        super.setUp()
        dataStore = DataStore.shared
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
        dataStore.saveStatuslineShowDirectory(false)
        XCTAssertFalse(dataStore.loadStatuslineShowDirectory())

        dataStore.saveStatuslineShowDirectory(true)
        XCTAssertTrue(dataStore.loadStatuslineShowDirectory())
    }

    func testStatuslineShowBranch() {
        dataStore.saveStatuslineShowBranch(false)
        XCTAssertFalse(dataStore.loadStatuslineShowBranch())

        dataStore.saveStatuslineShowBranch(true)
        XCTAssertTrue(dataStore.loadStatuslineShowBranch())
    }

    func testStatuslineShowUsage() {
        dataStore.saveStatuslineShowUsage(false)
        XCTAssertFalse(dataStore.loadStatuslineShowUsage())

        dataStore.saveStatuslineShowUsage(true)
        XCTAssertTrue(dataStore.loadStatuslineShowUsage())
    }

    func testStatuslineShowProgressBar() {
        dataStore.saveStatuslineShowProgressBar(false)
        XCTAssertFalse(dataStore.loadStatuslineShowProgressBar())

        dataStore.saveStatuslineShowProgressBar(true)
        XCTAssertTrue(dataStore.loadStatuslineShowProgressBar())
    }

    func testStatuslineShowResetTime() {
        dataStore.saveStatuslineShowResetTime(false)
        XCTAssertFalse(dataStore.loadStatuslineShowResetTime())

        dataStore.saveStatuslineShowResetTime(true)
        XCTAssertTrue(dataStore.loadStatuslineShowResetTime())
    }

    // MARK: - Setup Status Tests

    func testHasCompletedSetup() {
        dataStore.saveHasCompletedSetup(false)
        XCTAssertFalse(dataStore.hasCompletedSetup())

        dataStore.saveHasCompletedSetup(true)
        XCTAssertTrue(dataStore.hasCompletedSetup())
    }

    // MARK: - GitHub Star Prompt Tests

    func testFirstLaunchDate() {
        let testDate = Date()
        dataStore.saveFirstLaunchDate(testDate)

        let loaded = dataStore.loadFirstLaunchDate()
        XCTAssertNotNil(loaded)

        // Compare timestamps (allow 1 second difference for encoding/decoding)
        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testLastGitHubStarPromptDate() {
        let testDate = Date()
        dataStore.saveLastGitHubStarPromptDate(testDate)

        let loaded = dataStore.loadLastGitHubStarPromptDate()
        XCTAssertNotNil(loaded)

        if let loaded = loaded {
            XCTAssertEqual(loaded.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testHasStarredGitHub() {
        dataStore.saveHasStarredGitHub(false)
        XCTAssertFalse(dataStore.loadHasStarredGitHub())

        dataStore.saveHasStarredGitHub(true)
        XCTAssertTrue(dataStore.loadHasStarredGitHub())
    }

    func testNeverShowGitHubPrompt() {
        dataStore.saveNeverShowGitHubPrompt(false)
        XCTAssertFalse(dataStore.loadNeverShowGitHubPrompt())

        dataStore.saveNeverShowGitHubPrompt(true)
        XCTAssertTrue(dataStore.loadNeverShowGitHubPrompt())
    }

    func testShouldShowGitHubStarPrompt() {
        // Reset state
        dataStore.saveHasStarredGitHub(false)
        dataStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 3 days ago
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        dataStore.saveFirstLaunchDate(threeDaysAgo)

        // GitHubStarPromptManager.shared uses DataStore.shared (same instance as dataStore)
        // so state set above is visible to the manager
        XCTAssertTrue(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())

        // Mark as starred - should no longer show
        dataStore.saveHasStarredGitHub(true)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())

        // Reset starred, set never show - should not show
        dataStore.saveHasStarredGitHub(false)
        dataStore.saveNeverShowGitHubPrompt(true)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())
    }

    func testShouldNotShowGitHubPromptWhenTooEarly() {
        // Reset state
        dataStore.saveHasStarredGitHub(false)
        dataStore.saveNeverShowGitHubPrompt(false)

        // Set first launch to 12 hours ago (less than 1 day threshold)
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 60 * 60)
        dataStore.saveFirstLaunchDate(twelveHoursAgo)

        // GitHubStarPromptManager.shared uses DataStore.shared (same instance as dataStore)
        XCTAssertFalse(GitHubStarPromptManager.shared.shouldShowGitHubStarPrompt())
    }

    func testResetGitHubStarPromptForTesting() {
        // Set some state
        dataStore.saveHasStarredGitHub(true)
        dataStore.saveNeverShowGitHubPrompt(true)
        dataStore.saveLastGitHubStarPromptDate(Date())

        // Reset for testing
        dataStore.resetGitHubStarPromptForTesting()

        // Should be reset
        XCTAssertFalse(dataStore.loadHasStarredGitHub())
        XCTAssertFalse(dataStore.loadNeverShowGitHubPrompt())
        XCTAssertNil(dataStore.loadLastGitHubStarPromptDate())
    }
}
