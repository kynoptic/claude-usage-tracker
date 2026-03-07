import XCTest
@testable import Claude_Usage

/// Tests for the new adaptive UsageStatusCalculator.
/// Uses calculateStatus(usedPercentage:showRemaining:context:) → UsageStatus directly.
final class UsageStatusCalculatorNewTests: XCTestCase {

    // MARK: - Helpers

    private func status(
        used: Double,
        showRemaining: Bool = false,
        elapsed: Double? = nil,
        weeklyProjected: Double? = nil,
        avgSession: Double? = nil,
        sessionCount: Int = 0
    ) -> UsageStatus {
        let ctx = PacingContext(
            elapsedFraction: elapsed,
            weeklyProjected: weeklyProjected,
            avgSessionUtilization: avgSession,
            sessionCount: sessionCount
        )
        return UsageStatusCalculator.calculateStatus(
            usedPercentage: used,
            showRemaining: showRemaining,
            context: ctx
        )
    }

    // MARK: - Green zone (no context)

    func testGreen_Zero_Severity0() {
        let s = status(used: 0)
        XCTAssertEqual(s.zone, .green)
        XCTAssertEqual(s.severity, 0.0, accuracy: 0.001)
    }

    func testGreen_45Pct_BelowApproachStart() {
        let s = status(used: 45)
        XCTAssertEqual(s.zone, .green)
        XCTAssertLessThan(s.severity, 0.4)
    }

    func testGreen_89Pct_BelowApproachStart90() {
        // approachStart defaults to 90% → 89% is still green
        let s = status(used: 89)
        XCTAssertEqual(s.zone, .green)
    }

    func testGreen_Severity_Ramps_WithUsage() {
        let s0 = status(used: 0)
        let s45 = status(used: 45)
        let s89 = status(used: 89)
        XCTAssertLessThan(s0.severity, s45.severity)
        XCTAssertLessThan(s45.severity, s89.severity)
    }

    func testGreen_ActionText_LowSeverity_Underutilized() {
        // Very low usage → "Underutilized"
        let s = status(used: 5)
        XCTAssertTrue(s.actionText.contains("Underutilized"), "Expected 'Underutilized' but got '\(s.actionText)'")
    }

    func testGreen_ActionText_HighSeverity_OnTrack() {
        // 60% used (severity > 0.2 threshold) → "On track"
        let s = status(used: 60)
        XCTAssertTrue(s.actionText.contains("On track"), "Expected 'On track' but got '\(s.actionText)'")
    }

    // MARK: - approachStart modulation by weeklyProjected

    func testApproachStart_LowWeekly_94Pct() {
        // weeklyProjected ≤ 0.80 → approachStart = 94%
        // → 93% used should still be green
        let s = status(used: 93, weeklyProjected: 0.75)
        XCTAssertEqual(s.zone, .green)
    }

    func testApproachStart_LowWeekly_94Pct_And94IsApproach() {
        // weeklyProjected ≤ 0.80 → approachStart = 94% → 94% used = approach
        let s = status(used: 94, weeklyProjected: 0.75)
        XCTAssertEqual(s.zone, .approach)
    }

    func testApproachStart_DefaultWeekly_90Pct() {
        // weeklyProjected = nil → approachStart = 90%
        let s90 = status(used: 90)
        XCTAssertEqual(s90.zone, .approach)
        let s89 = status(used: 89)
        XCTAssertEqual(s89.zone, .green)
    }

    func testApproachStart_HighWeekly_85Pct() {
        // weeklyProjected > 1.30 → approachStart = 85%
        let s = status(used: 85, weeklyProjected: 1.35)
        XCTAssertEqual(s.zone, .approach)
        let s84 = status(used: 84, weeklyProjected: 1.35)
        XCTAssertEqual(s84.zone, .green)
    }

    func testApproachStart_MidHighWeekly_87Pct() {
        // weeklyProjected 1.00–1.30 → approachStart = 87%
        let s = status(used: 87, weeklyProjected: 1.15)
        XCTAssertEqual(s.zone, .approach)
        let s86 = status(used: 86, weeklyProjected: 1.15)
        XCTAssertEqual(s86.zone, .green)
    }

    // MARK: - Approach zone

    func testApproach_SeverityBetween04And05() {
        let s = status(used: 95)
        XCTAssertEqual(s.zone, .approach)
        XCTAssertGreaterThanOrEqual(s.severity, 0.4)
        XCTAssertLessThan(s.severity, 0.5)
    }

    func testApproach_ActionText_MaximizingUsage() {
        let s = status(used: 95)
        XCTAssertTrue(s.actionText.contains("Maximizing"), "Expected 'Maximizing' but got '\(s.actionText)'")
    }

    // MARK: - Warning zone (requires projected > 100%)

    func testWarning_ProjectedOver100_WhenPacing() {
        // 60% used at 50% elapsed → projected 120% → warning zone
        let s = status(used: 60, elapsed: 0.5)
        XCTAssertEqual(s.zone, .warning)
        XCTAssertGreaterThanOrEqual(s.severity, 0.5)
        XCTAssertLessThan(s.severity, 1.0)
    }

    func testWarning_ActionText_Overshooting() {
        let s = status(used: 60, elapsed: 0.5)
        XCTAssertTrue(s.actionText.contains("Overshooting"), "Expected 'Overshooting' but got '\(s.actionText)'")
    }

    // MARK: - Critical zone

    func testCritical_Severity1() {
        // Very high projected rate → critical
        // 80% used at 30% elapsed → projected 267% → way above any redThreshold
        let s = status(used: 80, elapsed: 0.3)
        XCTAssertEqual(s.zone, .critical)
        XCTAssertEqual(s.severity, 1.0, accuracy: 0.001)
    }

    func testCritical_ActionText_WayOver() {
        let s = status(used: 80, elapsed: 0.3)
        XCTAssertTrue(s.actionText.contains("Way over"), "Expected 'Way over' but got '\(s.actionText)'")
    }

    // MARK: - redThreshold formula

    func testRedThreshold_DefaultAvgRate_AtT50() {
        // effectiveAvgRate = 0.80 (default), t=0.5
        // redThreshold = (1 - 0.80 * 0.5) / 0.5 = 1.20
        // projected needs > 1.20 for critical
        // At u=60%, t=50%: projected=1.20 → exactly at threshold (warning or critical depending on >=)
        // At u=61%, t=50%: projected=1.22 → critical
        let sAt = status(used: 61, elapsed: 0.5)
        XCTAssertEqual(sAt.zone, .critical)
    }

    func testRedThreshold_DefaultAvgRate_BelowAt50_IsWarning() {
        // projected = 1.10 (55% at 50%) < 1.20 redThreshold → warning
        let s = status(used: 55, elapsed: 0.5)
        XCTAssertEqual(s.zone, .warning)
    }

    func testRedThreshold_HighAvgSession_TightensThreshold() {
        // With 20 sessions, weight = clamp((20-4)/16, 0, 1) = 1.0
        // blendedAvg = 0.95 (historical), no weekly modulator
        // effectiveAvgRate = 0.95
        // redThreshold(t=0.5) = (1 - 0.95*0.5)/0.5 = 1.05
        // projected at 54% @ 50% elapsed = 1.08 → critical
        let s = status(used: 54, elapsed: 0.5, avgSession: 0.95, sessionCount: 20)
        XCTAssertEqual(s.zone, .critical)
    }

    func testRedThreshold_LowSessionCount_BlendedTowardsDefault() {
        // With 0 sessions, weight=0 → blendedAvg = 0.80 (default)
        // redThreshold(t=0.5) = 1.20
        // 55% @ 50% → projected 1.10 < 1.20 → warning
        let s = status(used: 55, elapsed: 0.5, avgSession: 0.95, sessionCount: 0)
        XCTAssertEqual(s.zone, .warning)
    }

    func testRedThreshold_MidSessionCount_PartialBlend() {
        // sessionCount=12 → weight = (12-4)/16 = 0.5
        // blendedAvg = 0.5*0.90 + 0.5*0.80 = 0.85
        // redThreshold(t=0.5) = (1 - 0.85*0.5)/0.5 = (1-0.425)/0.5 = 1.15
        // 58% @ 50% → projected 1.16 > 1.15 → critical
        let s = status(used: 58, elapsed: 0.5, avgSession: 0.90, sessionCount: 12)
        XCTAssertEqual(s.zone, .critical)
    }

    // MARK: - Pacing guard: below 15% elapsed → no pacing

    func testBelowMinElapsed_FallsBackToRawU() {
        // 60% used, elapsed=0.10 (< 0.15 guard) → raw u=0.60, green (below 90%)
        let s = status(used: 60, elapsed: 0.10)
        XCTAssertEqual(s.zone, .green)
    }

    func testExactly15PctElapsed_PacingActivates() {
        // 60% used @ 15% elapsed → projected = 4.0 → critical
        let s = status(used: 60, elapsed: 0.15)
        XCTAssertEqual(s.zone, .critical)
    }

    // MARK: - colorLevel band agreement

    func testColorLevel_GreenZone_Levels1To3() {
        // 45% used, no context → green zone, severity < 0.4 → level 1–3
        let level = UsageStatusCalculator.colorLevel(utilization: 45, context: PacingContext.none)
        XCTAssertGreaterThanOrEqual(level, 1)
        XCTAssertLessThanOrEqual(level, 3)
    }

    func testColorLevel_ApproachZone_Levels4To5() {
        // 95% used, no context → approach zone, severity 0.4–0.5 → level 4–5
        let level = UsageStatusCalculator.colorLevel(utilization: 95, context: PacingContext.none)
        XCTAssertGreaterThanOrEqual(level, 4)
        XCTAssertLessThanOrEqual(level, 5)
    }

    func testColorLevel_WarningZone_Levels6To9() {
        // 55% @ 50% elapsed → warning zone → level 6–9
        let ctx = PacingContext(elapsedFraction: 0.5, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        let level = UsageStatusCalculator.colorLevel(utilization: 55, context: ctx)
        XCTAssertGreaterThanOrEqual(level, 6)
        XCTAssertLessThanOrEqual(level, 9)
    }

    func testColorLevel_CriticalZone_Level10() {
        // 80% @ 30% elapsed → critical → level 10
        let ctx = PacingContext(elapsedFraction: 0.3, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        let level = UsageStatusCalculator.colorLevel(utilization: 80, context: ctx)
        XCTAssertEqual(level, 10)
    }

    // MARK: - Deprecated forwarder backward compat

    func testDeprecatedForwarder_GreenZone_ReturnsSafe() {
        // 65% used no pacing → green → .safe via forwarder
        let legacy = UsageStatusCalculator.calculateStatus(usedPercentage: 65, showRemaining: false, elapsedFraction: nil)
        XCTAssertEqual(legacy, .safe)
    }

    func testDeprecatedForwarder_WarningZone_ReturnsModerate() {
        // 60% @ 50% elapsed → warning → .moderate via forwarder
        let legacy = UsageStatusCalculator.calculateStatus(usedPercentage: 60, showRemaining: false, elapsedFraction: 0.5)
        XCTAssertEqual(legacy, .moderate)
    }

    func testDeprecatedForwarder_CriticalZone_ReturnsCritical() {
        // 80% @ 30% elapsed → critical → .critical via forwarder
        let legacy = UsageStatusCalculator.calculateStatus(usedPercentage: 80, showRemaining: false, elapsedFraction: 0.3)
        XCTAssertEqual(legacy, .critical)
    }
}
