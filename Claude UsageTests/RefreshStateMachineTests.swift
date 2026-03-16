import XCTest
@testable import Claude_Usage

final class RefreshStateMachineTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeUsage(sessionPercentage: Double = 50.0, weeklyPercentage: Double = 30.0) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: 500,
            sessionLimit: 1000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(5 * 60 * 60),
            weeklyTokensUsed: 300,
            weeklyLimit: 1_000_000,
            weeklyPercentage: weeklyPercentage,
            weeklyResetTime: Date().addingTimeInterval(7 * 24 * 60 * 60),
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

    private func makeRateLimitError(retryAfter: TimeInterval? = nil) -> AppError {
        AppError(
            code: .apiRateLimited,
            message: "Rate limited",
            isRecoverable: true,
            retryAfter: retryAfter
        )
    }

    private func makeUnauthorizedError() -> AppError {
        AppError(code: .apiUnauthorized, message: "Unauthorized", isRecoverable: true)
    }

    private func makeNetworkError() -> AppError {
        AppError(code: .networkUnavailable, message: "Network unavailable", isRecoverable: true)
    }

    private func makeSessionKeyNotFoundError() -> AppError {
        AppError(code: .sessionKeyNotFound, message: "No session key", isRecoverable: true)
    }

    // MARK: - Initial State

    func testInitialState() {
        let sm = RefreshStateMachine()

        XCTAssertFalse(sm.isRefreshing)
        XCTAssertNil(sm.lastSuccessfulFetch)
        XCTAssertFalse(sm.isStale)
        XCTAssertNil(sm.lastRefreshError)
        XCTAssertNil(sm.nextRetryDate)
    }

    // MARK: - Begin Refresh

    func testBeginRefreshSetsIsRefreshing() {
        var sm = RefreshStateMachine()

        sm.beginRefresh()

        XCTAssertTrue(sm.isRefreshing)
    }

    // MARK: - Record Success

    func testRecordSuccessSetsLastSuccessfulFetch() {
        var sm = RefreshStateMachine()
        let now = Date()

        sm.recordSuccess(usage: makeUsage(), now: now)

        XCTAssertEqual(sm.lastSuccessfulFetch, now)
    }

    func testRecordSuccessClearsError() {
        var sm = RefreshStateMachine()
        let now = Date()

        sm.recordError(makeRateLimitError(), now: now)
        XCTAssertNotNil(sm.lastRefreshError)

        sm.recordSuccess(usage: makeUsage(), now: now)
        XCTAssertNil(sm.lastRefreshError)
        XCTAssertNil(sm.nextRetryDate)
    }

    func testRecordSuccessUpdatesPollingScheduler() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )

        // Rate limit to put scheduler in backoff
        sm.recordError(makeRateLimitError(), now: Date())
        XCTAssertTrue(sm.isBackingOff)

        sm.recordSuccess(usage: makeUsage(), now: Date())
        XCTAssertFalse(sm.isBackingOff)
        XCTAssertEqual(sm.currentInterval, 30)
    }

    // MARK: - Record Error (Rate Limited)

    func testRecordRateLimitErrorSetsNextRetryDate() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        sm.recordError(makeRateLimitError(), now: now)

        XCTAssertNotNil(sm.lastRefreshError)
        XCTAssertEqual(sm.lastRefreshError?.code, .apiRateLimited)
        XCTAssertNotNil(sm.nextRetryDate)
        XCTAssertTrue(sm.isBackingOff)
    }

    func testRecordRateLimitErrorWithRetryAfter() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        sm.recordError(makeRateLimitError(retryAfter: 120), now: now)

        let expectedRetry = now.addingTimeInterval(120)
        XCTAssertEqual(
            sm.nextRetryDate!.timeIntervalSince1970,
            expectedRetry.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testRecordRateLimitErrorWithoutRetryAfterUsesPollingInterval() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        sm.recordError(makeRateLimitError(), now: now)

        // After one rate limit error, polling interval is 60 (30 * 2^1)
        let expectedRetry = now.addingTimeInterval(60)
        XCTAssertEqual(
            sm.nextRetryDate!.timeIntervalSince1970,
            expectedRetry.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Record Error (Unauthorized / Session Key Not Found)

    func testUnauthorizedErrorSetsNilRetryDate() {
        var sm = RefreshStateMachine()
        let now = Date()

        sm.recordError(makeUnauthorizedError(), now: now)

        XCTAssertNotNil(sm.lastRefreshError)
        XCTAssertNil(sm.nextRetryDate, "Unauthorized errors require user action, no auto-retry")
    }

    func testSessionKeyNotFoundSetsNilRetryDate() {
        var sm = RefreshStateMachine()
        let now = Date()

        sm.recordError(makeSessionKeyNotFoundError(), now: now)

        XCTAssertNil(sm.nextRetryDate, "Session key errors require user action, no auto-retry")
    }

    // MARK: - Record Error (Recoverable Network Error)

    func testNetworkErrorSetsRetryDate() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        sm.recordError(makeNetworkError(), now: now)

        XCTAssertNotNil(sm.nextRetryDate)
        XCTAssertFalse(sm.isBackingOff, "Network errors should not trigger backoff")
    }

    // MARK: - End Refresh

    func testEndRefreshClearsIsRefreshing() {
        var sm = RefreshStateMachine()

        sm.beginRefresh()
        XCTAssertTrue(sm.isRefreshing)

        sm.endRefresh()
        XCTAssertFalse(sm.isRefreshing)
    }

    // MARK: - Staleness

    func testFreshDataIsNotStale() {
        var sm = RefreshStateMachine()
        let now = Date()

        sm.recordSuccess(usage: makeUsage(), now: now)
        sm.updateStaleness(now: now)

        XCTAssertFalse(sm.isStale)
    }

    func testOldDataIsStale() {
        var sm = RefreshStateMachine()
        let fetchTime = Date()

        sm.recordSuccess(usage: makeUsage(), now: fetchTime)

        // 6 minutes later (threshold is 5 minutes / 300s)
        let later = fetchTime.addingTimeInterval(360)
        sm.updateStaleness(now: later, stalenessThreshold: 300)

        XCTAssertTrue(sm.isStale)
    }

    func testBackingOffIsAlwaysStale() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        sm.recordSuccess(usage: makeUsage(), now: now)
        sm.recordError(makeRateLimitError(), now: now)
        sm.updateStaleness(now: now)

        XCTAssertTrue(sm.isStale, "Backing off should always be considered stale")
    }

    func testNoFetchIsNotStale() {
        var sm = RefreshStateMachine()

        sm.updateStaleness(now: Date())

        XCTAssertFalse(sm.isStale, "No fetch yet should not be stale")
    }

    func testEndRefreshUpdatesStaleness() {
        var sm = RefreshStateMachine()
        let fetchTime = Date()

        sm.recordSuccess(usage: makeUsage(), now: fetchTime)

        // 6 minutes later
        let later = fetchTime.addingTimeInterval(360)
        sm.beginRefresh()
        sm.endRefresh(now: later, stalenessThreshold: 300)

        XCTAssertTrue(sm.isStale)
    }

    // MARK: - Polling Scheduler Delegation

    func testCurrentIntervalDelegatesToScheduler() {
        let sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 45)
        )

        XCTAssertEqual(sm.currentInterval, 45)
    }

    func testIsBackingOffDelegatesToScheduler() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )

        XCTAssertFalse(sm.isBackingOff)

        sm.recordError(makeRateLimitError(), now: Date())
        XCTAssertTrue(sm.isBackingOff)
    }

    // MARK: - Reset Polling Scheduler

    func testResetPollingScheduler() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )

        sm.resetPollingScheduler(baseInterval: 60)

        XCTAssertEqual(sm.currentInterval, 60)
    }

    // MARK: - Full Cycle

    func testFullRefreshCycle() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        // Start refresh
        sm.beginRefresh()
        XCTAssertTrue(sm.isRefreshing)

        // Success
        sm.recordSuccess(usage: makeUsage(), now: now)
        XCTAssertEqual(sm.lastSuccessfulFetch, now)
        XCTAssertNil(sm.lastRefreshError)

        // End refresh
        sm.endRefresh(now: now)
        XCTAssertFalse(sm.isRefreshing)
        XCTAssertFalse(sm.isStale)
    }

    func testFullErrorRecoveryCycle() {
        var sm = RefreshStateMachine(
            pollingScheduler: PollingScheduler(baseInterval: 30)
        )
        let now = Date()

        // First refresh fails with rate limit
        sm.beginRefresh()
        sm.recordError(makeRateLimitError(), now: now)
        sm.endRefresh(now: now)

        XCTAssertFalse(sm.isRefreshing)
        XCTAssertTrue(sm.isStale)
        XCTAssertNotNil(sm.nextRetryDate)
        XCTAssertTrue(sm.isBackingOff)

        // Retry succeeds
        sm.beginRefresh()
        sm.recordSuccess(usage: makeUsage(), now: now)
        sm.endRefresh(now: now)

        XCTAssertFalse(sm.isRefreshing)
        XCTAssertFalse(sm.isStale)
        XCTAssertNil(sm.lastRefreshError)
        XCTAssertNil(sm.nextRetryDate)
        XCTAssertFalse(sm.isBackingOff)
    }

    // MARK: - Should Notify Success

    func testShouldNotifySuccessWithinWindow() {
        let sm = RefreshStateMachine()
        let trigger = Date().addingTimeInterval(-3)

        XCTAssertTrue(sm.shouldNotifySuccess(lastTriggerTime: trigger, window: 5))
    }

    func testShouldNotNotifySuccessOutsideWindow() {
        let sm = RefreshStateMachine()
        let trigger = Date().addingTimeInterval(-10)

        XCTAssertFalse(sm.shouldNotifySuccess(lastTriggerTime: trigger, window: 5))
    }
}
