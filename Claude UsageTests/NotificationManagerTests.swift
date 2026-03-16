import XCTest
@testable import Claude_Usage

/// Tests for `NotificationManager` multi-profile state isolation.
///
/// Validates that:
/// 1. Session-reset detection is per-profile (profile B poll doesn't mask profile A reset)
/// 2. Threshold deduplication is per-profile (95% alert for A doesn't suppress B's 95% alert)
/// 3. Clearing lower thresholds is per-profile
@MainActor
final class NotificationManagerTests: XCTestCase {

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        NotificationManager.shared.resetAllState()
    }

    // MARK: - Helpers

    private let profileAId = UUID()
    private let profileBId = UUID()

    private let allEnabled = NotificationSettings(
        enabled: true,
        threshold75Enabled: true,
        threshold90Enabled: true,
        threshold95Enabled: true
    )

    private func makeUsage(sessionPercentage: Double) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPercentage * 100),
            sessionLimit: 10_000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(5 * 60 * 60),
            weeklyTokensUsed: 0,
            weeklyLimit: 1_000_000,
            weeklyPercentage: 0,
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

    // MARK: - Session Reset Detection Per-Profile

    /// Profile A is at 50%, then resets to 0%. Meanwhile Profile B goes from 0% to 30%.
    /// The reset on Profile A must still be detected even though Profile B was polled in between.
    func testSessionResetDetectedPerProfile() {
        let manager = NotificationManager.shared

        // Prime profile A at 50%
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 50),
            profileId: profileAId,
            profileName: "Profile A",
            settings: allEnabled
        )

        // Prime profile B at 0% → 30% (no reset, just ramping up)
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 0),
            profileId: profileBId,
            profileName: "Profile B",
            settings: allEnabled
        )
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 30),
            profileId: profileBId,
            profileName: "Profile B",
            settings: allEnabled
        )

        // Now profile A resets to 0%. With global state this would compare
        // against profile B's 30%, not profile A's 50%, and miss the reset.
        // The test verifies profile A's previous percentage (50) is used.
        let previousForA = manager.previousSessionPercentage(for: profileAId)
        XCTAssertEqual(previousForA, 50, "Profile A's previous percentage should be 50, not contaminated by Profile B")

        // After calling checkAndNotify for profile A at 0%, the previous should update
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 0),
            profileId: profileAId,
            profileName: "Profile A",
            settings: allEnabled
        )
        let updatedForA = manager.previousSessionPercentage(for: profileAId)
        XCTAssertEqual(updatedForA, 0, "Profile A's previous percentage should update to 0 after reset")

        // Profile B should still be at 30
        let previousForB = manager.previousSessionPercentage(for: profileBId)
        XCTAssertEqual(previousForB, 30, "Profile B's previous percentage should remain 30")
    }

    // MARK: - Threshold Deduplication Per-Profile

    /// 95% alert for Profile A must not suppress the 95% alert for Profile B.
    func testThresholdDeduplicationIsPerProfile() {
        let manager = NotificationManager.shared

        // Profile A hits 95%
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 95),
            profileId: profileAId,
            profileName: "Profile A",
            settings: allEnabled
        )

        // Profile B also hits 95% — should NOT be suppressed
        let suppressedBefore = manager.hasSentNotification(
            profileId: profileBId,
            type: .sessionCritical,
            percentage: 95
        )
        XCTAssertFalse(suppressedBefore, "Profile B's 95% alert should not be pre-suppressed by Profile A")

        // After notifying Profile B, it should be marked sent for B
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 95),
            profileId: profileBId,
            profileName: "Profile B",
            settings: allEnabled
        )
        let sentForB = manager.hasSentNotification(
            profileId: profileBId,
            type: .sessionCritical,
            percentage: 95
        )
        XCTAssertTrue(sentForB, "Profile B's 95% alert should be marked as sent after notification")

        // Profile A should still have its own sent notification
        let sentForA = manager.hasSentNotification(
            profileId: profileAId,
            type: .sessionCritical,
            percentage: 95
        )
        XCTAssertTrue(sentForA, "Profile A's 95% alert should still be marked as sent")
    }

    // MARK: - Clear Lower Thresholds Per-Profile

    /// Clearing lower thresholds for Profile A should not affect Profile B.
    func testClearLowerThresholdsIsPerProfile() {
        let manager = NotificationManager.shared

        // Profile A hits 95%, then drops to 50% (should clear 95% for A)
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 95),
            profileId: profileAId,
            profileName: "Profile A",
            settings: allEnabled
        )

        // Profile B also at 95%
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 95),
            profileId: profileBId,
            profileName: "Profile B",
            settings: allEnabled
        )

        // Profile A drops to 50% — should clear A's 95% but NOT B's
        manager.checkAndNotify(
            usage: makeUsage(sessionPercentage: 50),
            profileId: profileAId,
            profileName: "Profile A",
            settings: allEnabled
        )

        let sentForA = manager.hasSentNotification(
            profileId: profileAId,
            type: .sessionCritical,
            percentage: 95
        )
        XCTAssertFalse(sentForA, "Profile A's 95% notification should be cleared after dropping to 50%")

        let sentForB = manager.hasSentNotification(
            profileId: profileBId,
            type: .sessionCritical,
            percentage: 95
        )
        XCTAssertTrue(sentForB, "Profile B's 95% notification should NOT be cleared by Profile A's drop")
    }
}
