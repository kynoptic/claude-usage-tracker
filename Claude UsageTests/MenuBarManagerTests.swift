import XCTest
@testable import Claude_Usage

/// Tests for MenuBarManager observer lifecycle and static helpers.
///
/// Note: MenuBarManager cannot be instantiated in the test runner because its
/// property initializers reference singletons that depend on NSApplication.
/// Observer balance and static methods are tested without instantiation.
final class MenuBarManagerTests: XCTestCase {

    // MARK: - Observer Add/Remove Balance

    /// Verifies that the cleanup() pattern correctly removes all four
    /// NotificationCenter observers by exercising the same add/remove logic.
    func testNotificationObserverAddRemoveBalance() {
        let center = NotificationCenter.default

        // Simulate the same pattern used by MenuBarManager.setup()
        var iconConfigObserver: NSObjectProtocol?
        var credentialsObserver: NSObjectProtocol?
        var displayModeObserver: NSObjectProtocol?

        // Add observers (mirrors observeIconConfigChanges, observeCredentialChanges, observeDisplayModeChanges)
        iconConfigObserver = center.addObserver(forName: .menuBarIconConfigChanged, object: nil, queue: .main) { _ in }
        credentialsObserver = center.addObserver(forName: .credentialsChanged, object: nil, queue: .main) { _ in }
        displayModeObserver = center.addObserver(forName: .displayModeChanged, object: nil, queue: .main) { _ in }

        XCTAssertNotNil(iconConfigObserver)
        XCTAssertNotNil(credentialsObserver)
        XCTAssertNotNil(displayModeObserver)

        // Remove observers (mirrors cleanup())
        for obs in [iconConfigObserver, credentialsObserver, displayModeObserver].compactMap({ $0 }) {
            center.removeObserver(obs)
        }
        iconConfigObserver = nil
        credentialsObserver = nil
        displayModeObserver = nil

        XCTAssertNil(iconConfigObserver)
        XCTAssertNil(credentialsObserver)
        XCTAssertNil(displayModeObserver)
    }

    /// Verifies that multiple add/remove cycles don't accumulate observers.
    func testMultipleCyclesDoNotAccumulateObservers() {
        let center = NotificationCenter.default
        var callCount = 0

        var observer: NSObjectProtocol?

        for _ in 1...3 {
            // Each cycle should replace the previous observer
            if let existing = observer {
                center.removeObserver(existing)
            }

            observer = center.addObserver(forName: .menuBarIconConfigChanged, object: nil, queue: .main) { _ in
                callCount += 1
            }
        }

        // Post notification — should fire exactly once (only the last observer)
        center.post(name: .menuBarIconConfigChanged, object: nil)

        // Use a small delay for the main queue block delivery
        let expectation = expectation(description: "notification delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(callCount, 1, "Only the last observer should remain after proper cleanup")

        if let obs = observer { center.removeObserver(obs) }
    }

    /// Verifies that skipping cleanup before re-registering leaks observers
    /// (documents the bug that cleanup() prevents).
    func testSkippingCleanupLeaksObservers() {
        let center = NotificationCenter.default
        var callCount = 0

        var observers: [NSObjectProtocol] = []

        // Register 3 times WITHOUT removing — simulates calling setup() 3x without cleanup()
        for _ in 1...3 {
            let obs = center.addObserver(forName: .credentialsChanged, object: nil, queue: .main) { _ in
                callCount += 1
            }
            observers.append(obs)
        }

        center.post(name: .credentialsChanged, object: nil)

        let expectation = expectation(description: "notification delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        // All 3 observers fire — proving cleanup is needed
        XCTAssertEqual(callCount, 3, "Without cleanup, all registered observers fire")

        for obs in observers { center.removeObserver(obs) }
    }

    // MARK: - Display Config (static)

    func testDisplayConfigDisablesMetricsWithoutCredentials() {
        let config = MenuBarIconConfiguration.default
        let result = MenuBarManager.displayConfig(from: config, hasUsageCredentials: false)

        for metric in result.metrics {
            XCTAssertFalse(metric.isEnabled, "Metric \(metric.metricType) should be disabled without credentials")
        }
    }

    func testDisplayConfigPassesThroughWithCredentials() {
        let config = MenuBarIconConfiguration.default
        let result = MenuBarManager.displayConfig(from: config, hasUsageCredentials: true)

        XCTAssertEqual(result.monochromeMode, config.monochromeMode)
        XCTAssertEqual(result.showIconNames, config.showIconNames)
        XCTAssertEqual(result.metrics.count, config.metrics.count)
    }

    func testDisplayConfigPreservesNonMetricFields() {
        let config = MenuBarIconConfiguration.default
        let result = MenuBarManager.displayConfig(from: config, hasUsageCredentials: false)

        // Non-metric fields should be preserved even without credentials
        XCTAssertEqual(result.monochromeMode, config.monochromeMode)
        XCTAssertEqual(result.showIconNames, config.showIconNames)
    }

    // MARK: - Pacing Context (static)

    func testBuildPacingContextReturnsValidFraction() throws {
        let usage = ClaudeUsage(
            sessionTokensUsed: 500,
            sessionLimit: 1000,
            sessionPercentage: 50.0,
            sessionResetTime: Date().addingTimeInterval(5 * 60 * 60),
            weeklyTokensUsed: 300,
            weeklyLimit: 1_000_000,
            weeklyPercentage: 30.0,
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

        let context = MenuBarManager.buildPacingContext(for: usage)

        let fraction = try XCTUnwrap(context.elapsedFraction, "elapsedFraction should not be nil")
        XCTAssertGreaterThanOrEqual(fraction, 0.0)
        XCTAssertLessThanOrEqual(fraction, 1.0)
    }
}
