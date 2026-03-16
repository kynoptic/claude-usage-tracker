import Foundation

/// Pure value type that manages the refresh/retry/staleness state machine.
///
/// Does not own timers or call services — the caller (MenuBarManager) owns the timer
/// and queries state after each transition. Follows the same pattern as `PollingScheduler`.
struct RefreshStateMachine {

    // MARK: - Properties

    /// `true` while a refresh network request is in flight.
    private(set) var isRefreshing: Bool = false

    /// Timestamp of the last successfully completed usage fetch.
    private(set) var lastSuccessfulFetch: Date?

    /// `true` when the cached usage data has exceeded the staleness threshold or the scheduler is backing off.
    private(set) var isStale: Bool = false

    /// The most recent error that caused a refresh to fail, or `nil` when the last refresh succeeded.
    private(set) var lastRefreshError: AppError?

    /// The earliest date at which an automatic retry will be attempted after an error.
    private(set) var nextRetryDate: Date?

    private var pollingScheduler: PollingScheduler

    /// Computed interval incorporating both backoff and adaptive multipliers.
    var currentInterval: TimeInterval {
        pollingScheduler.currentInterval
    }

    /// Whether the scheduler is currently in rate-limit backoff mode.
    var isBackingOff: Bool {
        pollingScheduler.isBackingOff
    }

    // MARK: - Initialization

    init(pollingScheduler: PollingScheduler = PollingScheduler()) {
        self.pollingScheduler = pollingScheduler
    }

    // MARK: - Public Methods

    /// Mark the beginning of a refresh cycle.
    mutating func beginRefresh() {
        isRefreshing = true
    }

    /// Record a successful API response. Resets error state and updates the polling scheduler.
    mutating func recordSuccess(usage: ClaudeUsage, now: Date = Date()) {
        pollingScheduler.recordSuccess(usage: usage)
        lastSuccessfulFetch = now
        lastRefreshError = nil
        nextRetryDate = nil
    }

    /// Record a failed API response. Categorizes the error and computes the next retry date.
    ///
    /// - Rate-limit errors trigger exponential backoff via the polling scheduler.
    /// - Unauthorized and session-key-not-found errors require user action (no auto-retry).
    /// - Other recoverable errors schedule a retry at the current polling interval.
    mutating func recordError(_ error: AppError, now: Date = Date()) {
        if error.code == .apiRateLimited {
            pollingScheduler.recordRateLimitError(retryAfter: error.retryAfter)
            nextRetryDate = now.addingTimeInterval(
                error.retryAfter ?? pollingScheduler.currentInterval
            )
        } else {
            pollingScheduler.recordOtherError()
            let requiresAction = error.code == .apiUnauthorized
                || error.code == .sessionKeyNotFound
            nextRetryDate = requiresAction
                ? nil
                : now.addingTimeInterval(pollingScheduler.currentInterval)
        }
        lastRefreshError = error
    }

    /// Mark the end of a refresh cycle. Clears `isRefreshing` and recomputes staleness.
    mutating func endRefresh(
        now: Date = Date(),
        stalenessThreshold: TimeInterval = Constants.RefreshIntervals.stalenessThreshold
    ) {
        updateStaleness(now: now, stalenessThreshold: stalenessThreshold)
        isRefreshing = false
    }

    /// Recomputes `isStale` based on the time since the last successful fetch and whether
    /// the polling scheduler is currently in back-off.
    mutating func updateStaleness(
        now: Date = Date(),
        stalenessThreshold: TimeInterval = Constants.RefreshIntervals.stalenessThreshold
    ) {
        let stale: Bool
        if pollingScheduler.isBackingOff {
            stale = true
        } else if let lastFetch = lastSuccessfulFetch {
            stale = now.timeIntervalSince(lastFetch) > stalenessThreshold
        } else {
            stale = false
        }
        if isStale != stale { isStale = stale }
    }

    /// Whether a user-triggered success notification should fire.
    ///
    /// Returns `true` when the last manual refresh trigger was within `window` seconds.
    func shouldNotifySuccess(lastTriggerTime: Date, window: TimeInterval = 5) -> Bool {
        abs(lastTriggerTime.timeIntervalSinceNow) < window
    }

    /// Replace the polling scheduler (e.g. when the user switches profiles or changes refresh interval).
    mutating func resetPollingScheduler(baseInterval: TimeInterval) {
        pollingScheduler = PollingScheduler(baseInterval: baseInterval)
    }
}
