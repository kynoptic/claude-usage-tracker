import XCTest
@testable import Claude_Usage

final class UsageStatusCalculatorTests: XCTestCase {

    // MARK: - Used-Based Thresholds (showRemaining = false)
    // New zone semantics: green+approach (0–99%) → .safe; warning (100–150%) → .moderate;
    // critical (>150%) → .critical. approachStart=0.90 (no history), redThr fallback=1.5.

    func testUsedBasedThresholds_Safe() {
        // 0–99% used: both green and approach zones map to .safe via deprecated forwarder
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 0, showRemaining: false),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 50, showRemaining: false),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 89, showRemaining: false),
            .safe
        )
        // Approach zone (90–99%) also resolves to .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 95, showRemaining: false),
            .safe
        )
    }

    func testUsedBasedThresholds_Moderate() {
        // 100–150% used → warning zone → .moderate
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 100, showRemaining: false),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 120, showRemaining: false),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 150, showRemaining: false),
            .moderate
        )
    }

    func testUsedBasedThresholds_Critical() {
        // >150% used → critical zone → .critical (redThr fallback = 1.5)
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 151, showRemaining: false),
            .critical
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 200, showRemaining: false),
            .critical
        )
    }

    // MARK: - Remaining-Based Thresholds (showRemaining = true)
    // showRemaining flips display only; pacing uses raw usedPercentage internally.

    func testRemainingBasedThresholds_Safe() {
        // 0–99% used → .safe regardless of display mode
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 0, showRemaining: true),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 50, showRemaining: true),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 95, showRemaining: true),
            .safe
        )
    }

    func testRemainingBasedThresholds_Moderate() {
        // 100–150% used → .moderate
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 100, showRemaining: true),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 130, showRemaining: true),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 150, showRemaining: true),
            .moderate
        )
    }

    func testRemainingBasedThresholds_Critical() {
        // >150% used → .critical
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 151, showRemaining: true),
            .critical
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 200, showRemaining: true),
            .critical
        )
    }

    // MARK: - Display Percentage Calculation

    func testGetDisplayPercentage_UsedMode() {
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 65, showRemaining: false),
            65.0
        )
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 0, showRemaining: false),
            0.0
        )
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 100, showRemaining: false),
            100.0
        )
    }

    func testGetDisplayPercentage_RemainingMode() {
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 65, showRemaining: true),
            35.0
        )
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 0, showRemaining: true),
            100.0
        )
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 100, showRemaining: true),
            0.0
        )
    }

    // MARK: - Edge Cases

    func testBoundaryConditions_UsedMode() {
        // New boundaries: green→approach at 90%; approach→warning at 100%; warning→critical at 150%
        // green and approach both → .safe via deprecated forwarder
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 89.9, showRemaining: false),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 90.0, showRemaining: false),
            .safe  // approach zone still → .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 99.9, showRemaining: false),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 100.0, showRemaining: false),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 150.0, showRemaining: false),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 150.1, showRemaining: false),
            .critical
        )
    }

    func testBoundaryConditions_RemainingMode() {
        // showRemaining=true does not affect zone calculation; same boundaries as usedMode
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 89, showRemaining: true),
            .safe
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 95, showRemaining: true),
            .safe  // approach
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 100, showRemaining: true),
            .moderate
        )
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 151, showRemaining: true),
            .critical
        )
    }

    func testNegativePercentage() {
        // Should handle negative used percentages gracefully (edge case, shouldn't happen in practice)
        // With -10% used, remaining would be 110%, clamped to 110 (max doesn't apply here)
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: -10, showRemaining: true),
            110.0  // max(0, 100 - (-10)) = max(0, 110) = 110
        )
    }

    func testOverOneHundredPercentage() {
        // Should handle over 100% gracefully
        XCTAssertEqual(
            UsageStatusCalculator.getDisplayPercentage(usedPercentage: 110, showRemaining: true),
            0.0  // max(0, 100 - 110) = 0
        )
    }

    // MARK: - Pacing (elapsedFraction provided)
    // At t=0.5 with no history: redThr = (1 - 0.80*(1-0.5))/0.5 = 1.20, approachStart = 0.90.
    // projected = used / t = used / 0.5. Zones: green<0.90, approach 0.90–1.0, warning 1.0–1.20,
    // critical >1.20. Via deprecated forwarder: green+approach → .safe, warning → .moderate,
    // critical → .critical.

    func testPacing_Safe_LowProjected() {
        // 30% used at 50% elapsed → projected 0.60 < 0.90 → green → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 30, showRemaining: false, elapsedFraction: 0.5),
            .safe
        )
    }

    func testPacing_Safe_MidProjected() {
        // 40% used at 50% elapsed → projected 0.80 < 0.90 → green → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 40, showRemaining: false, elapsedFraction: 0.5),
            .safe
        )
    }

    func testPacing_Safe_ApproachZone() {
        // 46% used at 50% elapsed → projected 0.92 → approach zone → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 46, showRemaining: false, elapsedFraction: 0.5),
            .safe
        )
    }

    func testPacing_Moderate_WarningZone() {
        // 55% used at 50% elapsed → projected 1.10, redThr=1.20 → warning → .moderate
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 55, showRemaining: false, elapsedFraction: 0.5),
            .moderate
        )
    }

    func testPacing_Critical_HighProjected() {
        // 61% used at 50% elapsed → projected 1.22 > redThr 1.20 → critical → .critical
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 61, showRemaining: false, elapsedFraction: 0.5),
            .critical
        )
    }

    func testPacing_HighUsedLateSession_Safe() {
        // 80% used at 90% elapsed → projected 0.889 < 0.90 → green → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 80, showRemaining: false, elapsedFraction: 0.9),
            .safe
        )
    }

    func testPacing_EarlySession_FallsBackToAbsolute() {
        // 60% used at only 10% elapsed (too early for pacing) → fallback → 60% < 90% → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 60, showRemaining: false, elapsedFraction: 0.10),
            .safe
        )
    }

    func testPacing_NilElapsed_FallsBackToAbsolute() {
        // nil elapsed → fallback; 60% < 90% → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 60, showRemaining: false, elapsedFraction: nil),
            .safe
        )
    }

    func testPacing_ZeroUsage_AlwaysSafe() {
        // 0% used at high elapsed → safe (no data to project a rate from)
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 0, showRemaining: false, elapsedFraction: 0.9),
            .safe
        )
    }

    func testPacing_BoundaryAtExactly15Percent_Activates() {
        // Exactly 15% elapsed → pacing activates; 10% used → projected 0.667 → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 10, showRemaining: false, elapsedFraction: 0.15),
            .safe
        )
    }

    func testPacing_JustBelow15Percent_FallsBack() {
        // 14% elapsed → fallback; 60% → absolute green (<90%) → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 60, showRemaining: false, elapsedFraction: 0.14),
            .safe
        )
    }

    func testPacing_ProjectedBoundary_AtRedThreshold_IsModerate() {
        // 60% used at 50% elapsed → projected exactly 1.20 = redThr → warning (not critical)
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 60, showRemaining: false, elapsedFraction: 0.5),
            .moderate
        )
    }

    func testPacing_ShowRemaining_Safe() {
        // display mode does not affect pacing; 30% @ 50% → projected 0.60 → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 30, showRemaining: true, elapsedFraction: 0.5),
            .safe
        )
    }

    func testPacing_ShowRemaining_Moderate() {
        // 55% @ 50% → projected 1.10 → warning → .moderate
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 55, showRemaining: true, elapsedFraction: 0.5),
            .moderate
        )
    }

    func testPacing_ShowRemaining_Critical() {
        // 61% @ 50% → projected 1.22 > 1.20 → critical → .critical
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 61, showRemaining: true, elapsedFraction: 0.5),
            .critical
        )
    }

    func testPacing_FullSession_FallsBackToAbsolute() {
        // t = 1.0 excluded from pacing; 80% used → absolute green (<90%) → .safe
        XCTAssertEqual(
            UsageStatusCalculator.calculateStatus(usedPercentage: 80, showRemaining: false, elapsedFraction: 1.0),
            .safe
        )
    }

    // MARK: - elapsedFraction edge cases

    func testElapsedFraction_ExpiredSession_Returns1() {
        // resetTime in the past → 1.0 (fully elapsed) in used mode
        let resetTime = Date().addingTimeInterval(-60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction, 1.0)
    }

    func testElapsedFraction_ExpiredSession_Returns0_RemainingMode() {
        // resetTime in the past → 0.0 (nothing remaining) in remaining mode
        let resetTime = Date().addingTimeInterval(-60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: true
        )
        XCTAssertEqual(fraction, 0.0)
    }

    func testElapsedFraction_ZeroDuration_ReturnsNil() {
        // duration == 0 → nil (avoid division by zero)
        let resetTime = Date().addingTimeInterval(3600)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: 0,
            showRemaining: false
        )
        XCTAssertNil(fraction)
    }

    func testElapsedFraction_NilResetTime_ReturnsNil() {
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: nil,
            duration: Constants.sessionWindow,
            showRemaining: false
        )
        XCTAssertNil(fraction)
    }

    // MARK: - elapsedFraction with shared period constants

    func testElapsedFraction_SessionPeriod_HalfwayThrough() {
        // 2.5 hours into a 5-hour session = 0.5
        let resetTime = Date().addingTimeInterval(Constants.sessionWindow / 2)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction ?? 0, 0.5, accuracy: 0.01)
    }

    func testElapsedFraction_WeeklyPeriod_HalfwayThrough() {
        // 3.5 days into a 7-day week = 0.5
        let resetTime = Date().addingTimeInterval(Constants.weeklyWindow / 2)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.weeklyWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction ?? 0, 0.5, accuracy: 0.01)
    }

    func testElapsedFraction_WeeklyPeriod_NearStart() {
        // Just started (reset in ~7 days) → ~0% elapsed
        let resetTime = Date().addingTimeInterval(Constants.weeklyWindow - 60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.weeklyWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction ?? 0, 0.0, accuracy: 0.01)
    }

    func testElapsedFraction_WeeklyPeriod_NearEnd() {
        // 60 seconds left → ~1.0 elapsed
        let resetTime = Date().addingTimeInterval(60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.weeklyWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction ?? 0, 1.0, accuracy: 0.01)
    }
}
