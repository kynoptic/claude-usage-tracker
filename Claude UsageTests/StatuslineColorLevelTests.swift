import XCTest
@testable import Claude_Usage

/// Tests for UsageStatusCalculator.colorLevel — verifies the 10-level ANSI gradient
/// used by the statusline bash script matches the menu bar's pacing-aware severity bands.
///
/// Color band contract (new zone semantics):
///   green  → LEVEL 1–5  (green zone <90%, approach zone 90–100%, both → .safe)
///   orange → LEVEL 6–9  (warning zone 100–150% → .moderate)
///   red    → LEVEL 10   (critical zone >150% → .critical)
///
/// At t=0.5 with no history: redThr = 1.20, approachStart = 0.90.
/// Pacing zone boundaries (projected = used/t):
///   green   projected <0.90 → levels 1–3
///   approach projected 0.90–1.0 → levels 4–5
///   warning  projected 1.0–1.20 → levels 6–9
///   critical projected >1.20 → level 10
final class StatuslineColorLevelTests: XCTestCase {

    // MARK: - Helpers

    private func band(for level: Int) -> String {
        switch level {
        case 1...5:  return "green"
        case 6...9:  return "orange"
        case 10:     return "red"
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

    // MARK: - Pacing mode: specific levels (t=0.5, no history)

    func testPacing_Level1_LowProjected() {
        // 10% used at 50% elapsed → projected 20% < 30% → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 10, elapsedFraction: 0.5), 1)
    }

    func testPacing_Level2_MidLowProjected() {
        // 20% used at 50% elapsed → projected 40% → 30–60% → LEVEL_2
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 20, elapsedFraction: 0.5), 2)
    }

    func testPacing_Level3_UpperGreenProjected() {
        // 40% used at 50% elapsed → projected 80% → 60–90% → LEVEL_3
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 40, elapsedFraction: 0.5), 3)
    }

    func testPacing_Level4_ApproachZoneLow() {
        // 46% used at 50% elapsed → projected 92% → approach zone lower half → LEVEL_4
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 46, elapsedFraction: 0.5), 4)
    }

    func testPacing_Level5_ApproachZoneHigh() {
        // 48% used at 50% elapsed → projected 96% → approach zone upper half → LEVEL_5
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 48, elapsedFraction: 0.5), 5)
    }

    func testPacing_Level6_JustIntoWarning() {
        // 51% used at 50% elapsed → projected 102% → warning zone low → LEVEL_6
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 51, elapsedFraction: 0.5), 6)
    }

    func testPacing_Level7_MidWarning() {
        // 54% used at 50% elapsed → projected 108% → LEVEL_7
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 54, elapsedFraction: 0.5), 7)
    }

    func testPacing_Level8_UpperMidWarning() {
        // 57% used at 50% elapsed → projected 114% → LEVEL_8
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 57, elapsedFraction: 0.5), 8)
    }

    func testPacing_Level9_TopWarning() {
        // 60% used at 50% elapsed → projected 120% = redThr (not >, stays warning) → LEVEL_9
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 60, elapsedFraction: 0.5), 9)
    }

    func testPacing_Level10_Critical() {
        // 61% used at 50% elapsed → projected 122% > redThr 120% → critical → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 61, elapsedFraction: 0.5), 10)
    }

    func testPacing_100PercentUsage_IsLevel10() {
        // 100% used at 50% elapsed → projected 200% → critical → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 100, elapsedFraction: 0.5), 10)
    }

    // MARK: - Fallback mode: specific levels (nil elapsed, redThr=1.5, approachStart=0.90)
    // Green band (severity 0–0.4): levels 1–3 map to used 0–90%.
    //   Level 1: 0–30%; Level 2: 30–60%; Level 3: 60–90%.
    // Approach band (severity 0.4–0.5): levels 4–5 map to used 90–100%.
    // Warning band (severity 0.5–0.9): levels 6–9 map to used 100–150%.
    // Critical (severity 1.0): level 10, used >150%.

    func testFallback_Level1() {
        // 10% used → green zone deep → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 10, elapsedFraction: nil), 1)
    }

    func testFallback_Level2() {
        // 40% used → green zone mid → LEVEL_2
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 40, elapsedFraction: nil), 2)
    }

    func testFallback_Level3() {
        // 70% used → green zone upper → LEVEL_3
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 70, elapsedFraction: nil), 3)
    }

    func testFallback_Level4() {
        // 92% used → approach zone lower → LEVEL_4
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 92, elapsedFraction: nil), 4)
    }

    func testFallback_Level5() {
        // 96% used → approach zone upper → LEVEL_5
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 96, elapsedFraction: nil), 5)
    }

    func testFallback_Level6() {
        // 101% used → warning zone low → LEVEL_6
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 101, elapsedFraction: nil), 6)
    }

    func testFallback_Level7() {
        // 130% used → warning zone mid → LEVEL_7
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 130, elapsedFraction: nil), 7)
    }

    func testFallback_Level8() {
        // 140% used → warning zone upper-mid → LEVEL_8
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 140, elapsedFraction: nil), 8)
    }

    func testFallback_Level9() {
        // 148% used → warning zone top → LEVEL_9
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 148, elapsedFraction: nil), 9)
    }

    func testFallback_Level10() {
        // 151% used → critical zone → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 151, elapsedFraction: nil), 10)
    }

    // MARK: - Edge cases

    func testEdge_ZeroUsagePacing_IsLevel1() {
        // 0% usage → pacing skipped (u == 0), fallback → LEVEL_1
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 0, elapsedFraction: 0.5), 1)
    }

    func testEdge_ZeroUsageFallback_IsLevel1() {
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 0, elapsedFraction: nil), 1)
    }

    func testEdge_100PercentFallback_IsLevel6() {
        // 100% used → warning zone start → LEVEL_6 (not level 10 as old test expected)
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 100, elapsedFraction: nil), 6)
    }

    func testEdge_EarlySession_FallsBackToAbsolute() {
        // elapsed = 10% (< 15% threshold) → fallback; 60% used → green zone → LEVEL_3
        let level = UsageStatusCalculator.colorLevel(utilization: 60, elapsedFraction: 0.10)
        XCTAssertLessThanOrEqual(level, 5)  // green band (1–5)
    }

    func testEdge_ExactlyAt15Percent_PacingActivates() {
        // 15% elapsed → pacing fires; 10% used → projected 67% → green (1–5)
        let level = UsageStatusCalculator.colorLevel(utilization: 10, elapsedFraction: 0.15)
        XCTAssertLessThanOrEqual(level, 5)
    }

    func testEdge_FullSession_FallsBackToAbsolute() {
        // elapsed = 1.0 → pacing excluded; 80% used → green zone → LEVEL_3
        let level = UsageStatusCalculator.colorLevel(utilization: 80, elapsedFraction: 1.0)
        XCTAssertLessThanOrEqual(level, 5)  // still green band
    }

    // MARK: - Severity band agreement with UsageStatusCalculator

    /// Verifies that for any (utilization, elapsedFraction) pair the colorLevel band
    /// (green/orange/red) matches the deprecated calculateStatus zone.
    func testSeverityAgreement_Matrix() {
        let scenarios: [(utilization: Int, elapsed: Double?, note: String)] = [
            // Pacing: green
            (10, 0.5,  "10% @ 50% → projected 20% → green"),
            (40, 0.5,  "40% @ 50% → projected 80% → green"),
            // Pacing: approach (still .safe)
            (46, 0.5,  "46% @ 50% → projected 92% → approach → green band"),
            // Pacing: warning → .moderate → orange band
            (55, 0.5,  "55% @ 50% → projected 110% → warning → orange"),
            // Pacing: critical
            (61, 0.5,  "61% @ 50% → projected 122% → critical → red"),
            (80, 0.3,  "80% @ 30% → projected 267% → critical → red"),
            // Fallback: green
            (10,  nil, "10% fallback → green"),
            (70,  nil, "70% fallback → green"),
            // Fallback: approach (still .safe)
            (92,  nil, "92% fallback → approach → green band"),
            // Fallback: warning → .moderate
            (101, nil, "101% fallback → warning → orange"),
            // Fallback: critical
            (151, nil, "151% fallback → critical → red"),
            // Fallback: early session (pacing skipped)
            (60, 0.10, "60% @ 10% elapsed → fallback → green"),
            // Fallback: session complete
            (80, 1.0,  "80% @ 100% elapsed → fallback → green"),
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

    // MARK: - Fallback boundary values (match new zone semantics)

    func testFallbackBoundary_89Pct_IsGreen() {
        // 89% used → green zone → green band (1–5)
        let level = UsageStatusCalculator.colorLevel(utilization: 89, elapsedFraction: nil)
        XCTAssertLessThanOrEqual(level, 5)
    }

    func testFallbackBoundary_90Pct_IsGreenBand() {
        // 90% used → approach zone → still .safe → green band
        let level = UsageStatusCalculator.colorLevel(utilization: 90, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 4)
        XCTAssertLessThanOrEqual(level, 5)
    }

    func testFallbackBoundary_100Pct_IsOrange() {
        // 100% used → warning zone → .moderate → orange band (6–9)
        let level = UsageStatusCalculator.colorLevel(utilization: 100, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 6)
        XCTAssertLessThanOrEqual(level, 9)
    }

    func testFallbackBoundary_150Pct_IsOrange() {
        // 150% used = redThr exactly → still warning → orange band
        let level = UsageStatusCalculator.colorLevel(utilization: 150, elapsedFraction: nil)
        XCTAssertGreaterThanOrEqual(level, 6)
        XCTAssertLessThanOrEqual(level, 9)
    }

    func testFallbackBoundary_151Pct_IsRed() {
        // 151% used → critical → LEVEL_10
        XCTAssertEqual(UsageStatusCalculator.colorLevel(utilization: 151, elapsedFraction: nil), 10)
    }
}
