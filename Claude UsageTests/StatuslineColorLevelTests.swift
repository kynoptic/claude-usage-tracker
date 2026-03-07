import XCTest
@testable import Claude_Usage

/// Tests for UsageStatusCalculator.colorLevel — verifies the 10-level ANSI gradient
/// used by the statusline bash script matches the menu bar's pacing-aware severity bands.
///
/// Color band contract:
///   green  → LEVEL 1–3  (safe:     projected < 75%)
///   orange → LEVEL 4–7  (moderate: projected 75–95%)
///   red    → LEVEL 8–10 (critical: projected ≥ 95%)
///
/// Levels are assigned within each band by sub-dividing the projected range evenly.
final class StatuslineColorLevelTests: XCTestCase {

    // MARK: - Helpers

    private func band(for level: Int) -> String {
        switch level {
        case 1...3:  return "green"
        case 4...7:  return "orange"
        case 8...10: return "red"
        default:     return "unknown(\(level))"
        }
    }

    private func expectedBand(for status: UsageStatusLevel) -> String {
        switch status {
        case .safe:     return "green"
        case .moderate: return "orange"
        case .critical: return "red"
        }
    }

    // MARK: - Pacing mode: specific levels

    func testPacing_Level1_LowProjected() {
        // 10% used at 50% elapsed → projected 20% → < 25% → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 10, elapsedFraction: 0.5), 1)
    }

    func testPacing_Level2_MidLowProjected() {
        // 15% used at 50% elapsed → projected 30% → 25–50% → LEVEL_2
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 15, elapsedFraction: 0.5), 2)
    }

    func testPacing_Level3_UpperGreenProjected() {
        // 30% used at 50% elapsed → projected 60% → 50–75% → LEVEL_3
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 30, elapsedFraction: 0.5), 3)
    }

    func testPacing_Level4_JustIntoOrange() {
        // 38% used at 50% elapsed → projected 76% → 75–80% → LEVEL_4
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 38, elapsedFraction: 0.5), 4)
    }

    func testPacing_Level5_MidOrange() {
        // 41% used at 50% elapsed → projected 82% → 80–85% → LEVEL_5
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 41, elapsedFraction: 0.5), 5)
    }

    func testPacing_Level6_UpperMidOrange() {
        // 44% used at 50% elapsed → projected 88% → 85–90% → LEVEL_6
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 44, elapsedFraction: 0.5), 6)
    }

    func testPacing_Level7_TopOrange() {
        // 46% used at 50% elapsed → projected 92% → 90–95% → LEVEL_7
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 46, elapsedFraction: 0.5), 7)
    }

    func testPacing_Level8_JustIntoRed() {
        // 50% used at 50% elapsed → projected 100% → 95–115% → LEVEL_8
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 50, elapsedFraction: 0.5), 8)
    }

    func testPacing_Level9_DeeperRed() {
        // 58% used at 50% elapsed → projected 116% → 115–135% → LEVEL_9
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 58, elapsedFraction: 0.5), 9)
    }

    func testPacing_Level10_MaxRed() {
        // 68% used at 50% elapsed → projected 136% → ≥135% → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 68, elapsedFraction: 0.5), 10)
    }

    func testPacing_100PercentUsage_IsLevel10() {
        // 100% used at 50% elapsed → projected 200% → ≥135% → LEVEL_10
        // Verifies no overflow or degenerate result at max utilization in pacing mode.
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 100, elapsedFraction: 0.5), 10)
    }

    // MARK: - Fallback mode: specific levels

    func testFallback_Level1() {
        // 8% used, no pacing → < 17% → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 8, elapsedFraction: nil), 1)
    }

    func testFallback_Level2() {
        // 25% used → 17–34% → LEVEL_2
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 25, elapsedFraction: nil), 2)
    }

    func testFallback_Level3() {
        // 40% used → 34–50% → LEVEL_3
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 40, elapsedFraction: nil), 3)
    }

    func testFallback_Level4() {
        // 55% used → 50–60% → LEVEL_4
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 55, elapsedFraction: nil), 4)
    }

    func testFallback_Level5() {
        // 63% used → 60–67% → LEVEL_5
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 63, elapsedFraction: nil), 5)
    }

    func testFallback_Level6() {
        // 70% used → 67–73% → LEVEL_6
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 70, elapsedFraction: nil), 6)
    }

    func testFallback_Level7() {
        // 76% used → 73–80% → LEVEL_7
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 76, elapsedFraction: nil), 7)
    }

    func testFallback_Level8() {
        // 82% used → 80–87% → LEVEL_8
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 82, elapsedFraction: nil), 8)
    }

    func testFallback_Level9() {
        // 89% used → 87–93% → LEVEL_9
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 89, elapsedFraction: nil), 9)
    }

    func testFallback_Level10() {
        // 95% used → ≥93% → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 95, elapsedFraction: nil), 10)
    }

    // MARK: - Edge cases

    func testEdge_ZeroUsagePacing_IsLevel1() {
        // 0% usage → pacing skipped (u == 0), fallback → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 0, elapsedFraction: 0.5), 1)
    }

    func testEdge_ZeroUsageFallback_IsLevel1() {
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 0, elapsedFraction: nil), 1)
    }

    func testEdge_100PercentFallback_IsLevel10() {
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 100, elapsedFraction: nil), 10)
    }

    func testEdge_EarlySession_FallsBackToAbsolute() {
        // elapsed = 10% (< 15 threshold) → fallback; 60% used → orange (4–7)
        let level = UsageStatusCalculator.colorLevel(utilization: 60, elapsedFraction: 0.10)
        XCTAssertGreaterThanOrEqual(level, 4)
        XCTAssertLessThanOrEqual(level, 7)
    }

    func testEdge_ExactlyAt15Percent_PacingActivates() {
        // 15% elapsed → pacing fires; 10% used → projected 67% → green (1–3)
        let level = UsageStatusCalculator.colorLevel(utilization: 10, elapsedFraction: 0.15)
        XCTAssertLessThanOrEqual(level, 3)
    }

    func testEdge_FullSession_FallsBackToAbsolute() {
        // elapsed = 1.0 → pacing excluded; 80% used → red (8–10)
        let level = UsageStatusCalculator.colorLevel(utilization: 80, elapsedFraction: 1.0)
        XCTAssertGreaterThanOrEqual(level, 8)
    }

    // MARK: - Severity band agreement with UsageStatusCalculator

    /// Verifies that for any (utilization, elapsedFraction) pair the colorLevel band
    /// (green/orange/red) matches the severity returned by calculateStatus.
    func testSeverityAgreement_Matrix() {
        let scenarios: [(utilization: Int, elapsed: Double?, note: String)] = [
            // Pacing: safe
            (10, 0.5,  "10% @ 50% → projected 20% → green"),
            (30, 0.5,  "30% @ 50% → projected 60% → green"),
            // Pacing: moderate
            (38, 0.5,  "38% @ 50% → projected 76% → orange"),
            (44, 0.5,  "44% @ 50% → projected 88% → orange"),
            // Pacing: critical
            (50, 0.5,  "50% @ 50% → projected 100% → red"),
            (50, 0.3,  "50% @ 30% → projected 167% → red"),
            // Fallback: all three bands
            (30, nil,  "30% no pacing → green"),
            (65, nil,  "65% no pacing → orange"),
            (85, nil,  "85% no pacing → red"),
            // Fallback: early session
            (60, 0.10, "60% @ 10% elapsed → fallback → orange"),
            // Fallback: session complete
            (80, 1.0,  "80% @ 100% elapsed → fallback → red"),
        ]

        for scenario in scenarios {
            let level = UsageStatusCalculator.colorLevel(
                utilization: scenario.utilization,
                elapsedFraction: scenario.elapsed
            )
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: Double(scenario.utilization),
                showRemaining: false,
                elapsedFraction: scenario.elapsed
            )
            XCTAssertEqual(
                band(for: level),
                expectedBand(for: status),
                "Mismatch for scenario: \(scenario.note)"
            )
        }
    }

    // MARK: - Fallback boundary values (match UsageStatusCalculator absolute thresholds)

    func testFallbackBoundary_50Pct_IsOrange() {
        // UsageStatusCalculator: 50% used → .moderate → must be in orange band
        let level = UsageStatusCalculator.colorLevel(utilization: 50, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 4)
        XCTAssertLessThanOrEqual(level, 7)
    }

    func testFallbackBoundary_80Pct_IsRed() {
        // UsageStatusCalculator: 80% used → .critical → must be in red band
        let level = UsageStatusCalculator.colorLevel(utilization: 80, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 8)
    }

    func testFallbackBoundary_49Pct_IsGreen() {
        // UsageStatusCalculator: 49% used → .safe → must be in green band
        let level = UsageStatusCalculator.colorLevel(utilization: 49, elapsedFraction: nil)
        XCTAssertLessThanOrEqual(level, 3)
    }

    func testFallbackBoundary_79Pct_IsOrange() {
        // UsageStatusCalculator: 79% used → .moderate → must be in orange band
        let level = UsageStatusCalculator.colorLevel(utilization: 79, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 4)
        XCTAssertLessThanOrEqual(level, 7)
    }
}
