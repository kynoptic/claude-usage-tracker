import XCTest
@testable import Claude_Usage

/// Tests for `AutoStartSessionService` session-reset detection logic.
///
/// `AutoStartSessionService` is a singleton with private internals, so we test
/// the session-reset detection pattern by simulating the same logic it uses:
/// fetch usage via `APIServiceProtocol`, check if `sessionPercentage == 0.0`,
/// and decide whether to auto-start.
///
/// This validates that:
/// 1. The mock `APIServiceProtocol` correctly returns usage data
/// 2. Session-reset detection fires when `sessionPercentage` drops to 0
/// 3. Active sessions (percentage > 0) do not trigger auto-start
@MainActor
final class AutoStartSessionServiceTests: XCTestCase {

    // MARK: - Mock APIService

    /// Mock that returns configurable usage data via `APIServiceProtocol`.
    private final class MockAPIService: APIServiceProtocol {
        var stubbedSessionPercentage: Double = 0.0
        var fetchCallCount = 0
        var initMessageCallCount = 0
        var lastInitSessionKey: String?
        var lastInitOrgId: String?

        func fetchOrganizationId(sessionKey: String, storedOrgId: String?) async throws -> (orgId: String, isNewlyFetched: Bool) {
            if let stored = storedOrgId {
                return (stored, false)
            }
            return ("mock-org-id", true)
        }

        func fetchUsageData(sessionKey: String, organizationId: String) async throws -> ClaudeUsage {
            fetchCallCount += 1
            return makeUsage(sessionPercentage: stubbedSessionPercentage)
        }

        func fetchUsageData(oauthAccessToken: String) async throws -> ClaudeUsage {
            fetchCallCount += 1
            return makeUsage(sessionPercentage: stubbedSessionPercentage)
        }

        func fetchUsageData(
            auth: ClaudeAPIService.AuthenticationType,
            storedOrgId: String?,
            checkOverageLimitEnabled: Bool,
            sessionKeyFallback: String?
        ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?) {
            fetchCallCount += 1
            return (makeUsage(sessionPercentage: stubbedSessionPercentage), nil)
        }

        func sendInitializationMessage(sessionKey: String, organizationId: String) async throws {
            initMessageCallCount += 1
            lastInitSessionKey = sessionKey
            lastInitOrgId = organizationId
        }

        func fetchConsoleOrganizations(apiSessionKey: String) async throws -> [APIOrganization] {
            return []
        }

        func fetchAPIUsageData(organizationId: String, apiSessionKey: String) async throws -> APIUsage {
            throw AppError(code: .apiGenericError, message: "Not implemented", isRecoverable: false)
        }

        private func makeUsage(sessionPercentage: Double) -> ClaudeUsage {
            ClaudeUsage(
                sessionTokensUsed: 0,
                sessionLimit: 0,
                sessionPercentage: sessionPercentage,
                sessionResetTime: Date().addingTimeInterval(5 * 3600),
                weeklyTokensUsed: 0,
                weeklyLimit: 1_000_000,
                weeklyPercentage: 0,
                weeklyResetTime: Date().addingTimeInterval(7 * 86400),
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
    }

    // MARK: - Session Reset Detection Simulator

    /// Reproduces the core detection logic from `AutoStartSessionService.checkProfile`.
    /// Returns `true` if auto-start should fire (session reset detected).
    private func shouldAutoStart(
        usage: ClaudeUsage,
        lastCapturedResetTime: Date? = nil
    ) -> Bool {
        guard usage.sessionPercentage == 0.0 else {
            return false
        }

        // Check if we recently auto-started and should wait
        if let lastResetTime = lastCapturedResetTime,
           Date() < lastResetTime {
            return false
        }

        return true
    }

    // MARK: - Properties

    private var mockService: MockAPIService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockService = MockAPIService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    // MARK: - Session Reset Detection Tests

    /// When session percentage is 0, reset is detected and auto-start should fire.
    func testSessionResetDetectedWhenPercentageIsZero() async throws {
        mockService.stubbedSessionPercentage = 0.0

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        XCTAssertTrue(shouldAutoStart(usage: usage),
                      "Auto-start should fire when session percentage is 0%")
    }

    /// When session percentage is above 0, no reset is detected.
    func testNoResetDetectedWhenPercentageAboveZero() async throws {
        mockService.stubbedSessionPercentage = 42.5

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        XCTAssertFalse(shouldAutoStart(usage: usage),
                       "Auto-start should NOT fire when session percentage is above 0%")
    }

    /// Even a tiny percentage above 0 prevents auto-start.
    func testNoResetDetectedForSmallPercentage() async throws {
        mockService.stubbedSessionPercentage = 0.1

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        XCTAssertFalse(shouldAutoStart(usage: usage),
                       "Auto-start should NOT fire for 0.1% usage")
    }

    /// A recently captured reset time prevents duplicate auto-starts.
    func testRecentResetTimePreventsAutoStart() async throws {
        mockService.stubbedSessionPercentage = 0.0

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        // Simulate a future reset time (session was just started)
        let futureResetTime = Date().addingTimeInterval(3600)

        XCTAssertFalse(shouldAutoStart(usage: usage, lastCapturedResetTime: futureResetTime),
                       "Auto-start should NOT fire when last reset time is in the future")
    }

    /// An expired reset time allows auto-start.
    func testExpiredResetTimeAllowsAutoStart() async throws {
        mockService.stubbedSessionPercentage = 0.0

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        // Simulate a past reset time (session has reset)
        let pastResetTime = Date().addingTimeInterval(-3600)

        XCTAssertTrue(shouldAutoStart(usage: usage, lastCapturedResetTime: pastResetTime),
                      "Auto-start should fire when last reset time is in the past")
    }

    // MARK: - Mock Protocol Usage Tests

    /// Verifies that the mock correctly implements the protocol for session key auth.
    func testMockFetchViaSessionKey() async throws {
        mockService.stubbedSessionPercentage = 75.0

        let usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        XCTAssertEqual(usage.sessionPercentage, 75.0)
        XCTAssertEqual(mockService.fetchCallCount, 1)
    }

    /// Verifies that the mock correctly implements the protocol for OAuth auth.
    func testMockFetchViaOAuth() async throws {
        mockService.stubbedSessionPercentage = 50.0

        let usage = try await mockService.fetchUsageData(oauthAccessToken: "test-token")

        XCTAssertEqual(usage.sessionPercentage, 50.0)
        XCTAssertEqual(mockService.fetchCallCount, 1)
    }

    /// Verifies that the mock correctly implements sendInitializationMessage.
    func testMockSendInitializationMessage() async throws {
        try await mockService.sendInitializationMessage(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )

        XCTAssertEqual(mockService.initMessageCallCount, 1)
        XCTAssertEqual(mockService.lastInitSessionKey, "sk-ant-sid01-test-key-12345678")
        XCTAssertEqual(mockService.lastInitOrgId, "org-123")
    }

    // MARK: - Session Reset Sequence Tests

    /// Simulates a full session lifecycle: active -> reset -> auto-start -> active.
    func testFullSessionResetCycle() async throws {
        // Phase 1: Session is active (42% used)
        mockService.stubbedSessionPercentage = 42.0
        var usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )
        XCTAssertFalse(shouldAutoStart(usage: usage), "Phase 1: Should not auto-start")

        // Phase 2: Session resets (0%)
        mockService.stubbedSessionPercentage = 0.0
        usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )
        XCTAssertTrue(shouldAutoStart(usage: usage), "Phase 2: Should auto-start")

        // Phase 3: Auto-start fires, session becomes active again
        try await mockService.sendInitializationMessage(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )
        XCTAssertEqual(mockService.initMessageCallCount, 1, "Phase 3: Init message sent")

        // Phase 4: Next check shows active session
        mockService.stubbedSessionPercentage = 1.5
        usage = try await mockService.fetchUsageData(
            sessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )
        XCTAssertFalse(shouldAutoStart(usage: usage), "Phase 4: Should not auto-start again")
    }

    /// Verifies that fetchUsageData with auth parameter works through the protocol.
    func testFetchUsageDataWithAuthParam() async throws {
        mockService.stubbedSessionPercentage = 30.0

        let (usage, newOrgId) = try await mockService.fetchUsageData(
            auth: .claudeAISession("sk-ant-sid01-test-key-12345678"),
            storedOrgId: "org-123",
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 30.0)
        XCTAssertNil(newOrgId)
        XCTAssertEqual(mockService.fetchCallCount, 1)
    }

    /// Profile without Claude.ai credentials should be skipped.
    func testProfileWithoutCredentialsIsSkipped() {
        let profile = Profile(name: "No Credentials")
        XCTAssertFalse(profile.hasClaudeAI,
                       "Profile without session key and org ID should not have Claude.ai")
    }

    /// Profile with Claude.ai credentials should be checked.
    func testProfileWithCredentialsIsChecked() {
        let profile = Profile(
            name: "With Credentials",
            claudeSessionKey: "sk-ant-sid01-test-key-12345678",
            organizationId: "org-123"
        )
        XCTAssertTrue(profile.hasClaudeAI,
                      "Profile with session key and org ID should have Claude.ai")
    }

    /// Profile with auto-start disabled should not be checked.
    func testProfileAutoStartDisabledByDefault() {
        let profile = Profile(name: "Default")
        XCTAssertFalse(profile.autoStartSessionEnabled,
                       "Auto-start should be disabled by default")
    }
}
