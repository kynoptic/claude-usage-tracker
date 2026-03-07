import XCTest
@testable import Claude_Usage

/// Tests for the five-zone flat pacing model.
///
/// Zone thresholds (projected utilisation):
///   grey   < 50%          (opt-in, showGrey: true)
///   green  50–90%
///   yellow 90–110%
///   orange 110–150%
///   red    > 150%
///
/// Projection = usedPercentage / elapsedFraction when elapsed ∈ (0, 1).
/// Falls back to raw usedPercentage when elapsed is nil, 0, or ≥ 1.
final class UsageStatusCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private func zone(
        _ used: Double,
        elapsed: Double? = nil,
        showGrey: Bool = false
    ) -> UsageZone {
        UsageStatusCalculator.calculateStatus(
            usedPercentage: used,
            showRemaining: false,
            elapsedFraction: elapsed,
            showGrey: showGrey
        ).zone
    }

    // MARK: - No elapsed: raw percentage zones

    func testGrey_Under50_ShowGreyEnabled() {
        XCTAssertEqual(zone(0,    showGrey: true), .grey)
        XCTAssertEqual(zone(20,   showGrey: true), .grey)
        XCTAssertEqual(zone(49.9, showGrey: true), .grey)
    }

    func testGreen_Under50_ShowGreyDisabled() {
        XCTAssertEqual(zone(0),    .green)
        XCTAssertEqual(zone(20),   .green)
        XCTAssertEqual(zone(49.9), .green)
    }

    func testGreen_50to90() {
        XCTAssertEqual(zone(50),   .green)
        XCTAssertEqual(zone(70),   .green)
        XCTAssertEqual(zone(89.9), .green)
    }

    func testYellow_90to110() {
        XCTAssertEqual(zone(90),   .yellow)
        XCTAssertEqual(zone(100),  .yellow)
        XCTAssertEqual(zone(109.9),.yellow)
    }

    func testOrange_110to150() {
        XCTAssertEqual(zone(110),  .orange)
        XCTAssertEqual(zone(130),  .orange)
        XCTAssertEqual(zone(150),  .orange)
    }

    func testRed_Over150() {
        XCTAssertEqual(zone(150.1), .red)
        XCTAssertEqual(zone(200),   .red)
    }

    // MARK: - Boundary conditions

    func testBoundary_50_IsGreen() {
        XCTAssertEqual(zone(50), .green)
    }

    func testBoundary_90_IsYellow() {
        XCTAssertEqual(zone(90), .yellow)
    }

    func testBoundary_110_IsOrange() {
        XCTAssertEqual(zone(110), .orange)
    }

    func testBoundary_150_IsOrange() {
        XCTAssertEqual(zone(150), .orange)
    }

    func testBoundary_150point1_IsRed() {
        XCTAssertEqual(zone(150.1), .red)
    }

    // MARK: - Pacing (elapsedFraction fires from first poll)

    func testPacing_Green_ProjectedUnder90() {
        // 60% at 75% elapsed → projected 80% → green
        XCTAssertEqual(zone(60, elapsed: 0.75), .green)
    }

    func testPacing_Yellow_Projected100() {
        // 50% at 50% elapsed → projected 100% → yellow (90–110%)
        XCTAssertEqual(zone(50, elapsed: 0.5), .yellow)
    }

    func testPacing_Yellow_Projected105() {
        // 52.5% at 50% elapsed → projected 105% → yellow
        XCTAssertEqual(zone(52.5, elapsed: 0.5), .yellow)
    }

    func testPacing_Orange_Projected120() {
        // 60% at 50% elapsed → projected 120% → orange (110–150%)
        XCTAssertEqual(zone(60, elapsed: 0.5), .orange)
    }

    func testPacing_Red_Projected160() {
        // 80% at 50% elapsed → projected 160% → red (> 150%)
        XCTAssertEqual(zone(80, elapsed: 0.5), .red)
    }

    func testPacing_Grey_LowProjected_ShowGrey() {
        // 10% at 50% elapsed → projected 20% → grey (with showGrey)
        XCTAssertEqual(zone(10, elapsed: 0.5, showGrey: true), .grey)
    }

    func testPacing_Green_LowProjected_ShowGreyFalse() {
        // 10% at 50% elapsed → projected 20% → green (showGrey off)
        XCTAssertEqual(zone(10, elapsed: 0.5, showGrey: false), .green)
    }

    func testPacing_ZeroUsage_Green() {
        // 0% used → projected 0 → green
        XCTAssertEqual(zone(0, elapsed: 0.5), .green)
    }

    func testPacing_ZeroUsage_Grey_WhenEnabled() {
        XCTAssertEqual(zone(0, elapsed: 0.5, showGrey: true), .grey)
    }

    func testPacing_ZeroElapsed_FallsBackToRaw() {
        // elapsed=0 → guard fires, raw 60% → green (50–90%)
        XCTAssertEqual(zone(60, elapsed: 0.0), .green)
    }

    func testPacing_Elapsed100_FallsBackToRaw() {
        // elapsed=1.0 → session over, raw 80% → green
        XCTAssertEqual(zone(80, elapsed: 1.0), .green)
    }

    func testPacing_NilElapsed_FallsBackToRaw() {
        // nil elapsed → raw 95% → yellow
        XCTAssertEqual(zone(95, elapsed: nil), .yellow)
    }

    func testPacing_EarlySession_1pctElapsed_ProjectionFires() {
        // 1% elapsed, no guard: 45% used / 0.01 = 4500% projected → red
        XCTAssertEqual(zone(45, elapsed: 0.01), .red)
    }

    // MARK: - Action text

    func testActionText_Grey() {
        let s = UsageStatusCalculator.calculateStatus(usedPercentage: 10, showRemaining: false, elapsedFraction: nil, showGrey: true)
        XCTAssertTrue(s.actionText.contains("Underutilized"), "got: \(s.actionText)")
    }

    func testActionText_Green() {
        let s = UsageStatusCalculator.calculateStatus(usedPercentage: 70, showRemaining: false, elapsedFraction: nil)
        XCTAssertTrue(s.actionText.contains("On track"), "got: \(s.actionText)")
    }

    func testActionText_Yellow() {
        let s = UsageStatusCalculator.calculateStatus(usedPercentage: 95, showRemaining: false, elapsedFraction: nil)
        XCTAssertTrue(s.actionText.contains("Maximizing"), "got: \(s.actionText)")
    }

    func testActionText_Orange() {
        let s = UsageStatusCalculator.calculateStatus(usedPercentage: 130, showRemaining: false, elapsedFraction: nil)
        XCTAssertTrue(s.actionText.contains("Overshooting"), "got: \(s.actionText)")
    }

    func testActionText_Red() {
        let s = UsageStatusCalculator.calculateStatus(usedPercentage: 160, showRemaining: false, elapsedFraction: nil)
        XCTAssertTrue(s.actionText.contains("Way over"), "got: \(s.actionText)")
    }

    // MARK: - Display percentage (unchanged helper)

    func testGetDisplayPercentage_UsedMode() {
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 65, showRemaining: false), 65.0)
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 0, showRemaining: false), 0.0)
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 100, showRemaining: false), 100.0)
    }

    func testGetDisplayPercentage_RemainingMode() {
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 65, showRemaining: true), 35.0)
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 0, showRemaining: true), 100.0)
        XCTAssertEqual(UsageStatusCalculator.getDisplayPercentage(usedPercentage: 100, showRemaining: true), 0.0)
    }

    // MARK: - elapsedFraction helper (unchanged)

    func testElapsedFraction_ExpiredSession_Returns1() {
        let resetTime = Date().addingTimeInterval(-60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction, 1.0)
    }

    func testElapsedFraction_ExpiredSession_Returns0_RemainingMode() {
        let resetTime = Date().addingTimeInterval(-60)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: true
        )
        XCTAssertEqual(fraction, 0.0)
    }

    func testElapsedFraction_ZeroDuration_ReturnsNil() {
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: Date().addingTimeInterval(3600),
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

    func testElapsedFraction_HalfwayThrough() {
        let resetTime = Date().addingTimeInterval(Constants.sessionWindow / 2)
        let fraction = UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: Constants.sessionWindow,
            showRemaining: false
        )
        XCTAssertEqual(fraction ?? 0, 0.5, accuracy: 0.01)
    }
}
