import XCTest
@testable import Claude_Usage

/// Tests for UsageStatusCalculator.colorLevel — verifies ANSI level values
/// used by the statusline bash script match the Swift five-zone model.
///
/// Zone → level contract:
///   grey / green  → 3   (projected < 90%)
///   yellow        → 5   (projected 90–110%)
///   orange        → 7   (projected 110–150%)
///   red           → 10  (projected > 150%)
///
/// Projection = utilization / elapsedFraction when elapsed ∈ (0, 1).
/// Falls back to raw utilization when elapsed is nil or ≥ 1.
/// No minimum-elapsed guard — projection fires from first poll.
final class StatuslineColorLevelTests: XCTestCase {

    private func level(_ utilization: Int, elapsed: Double?) -> Int {
        UsageStatusCalculator.colorLevel(utilization: utilization, elapsedFraction: elapsed)
    }

    // MARK: - Pacing mode (t = 0.5)

    func testPacing_Green_LowProjected() {
        // 20% at 50% elapsed → projected 40% → green → 3
        XCTAssertEqual(level(20, elapsed: 0.5), 3)
    }

    func testPacing_Green_UpperGreen() {
        // 40% at 50% elapsed → projected 80% → green → 3
        XCTAssertEqual(level(40, elapsed: 0.5), 3)
    }

    func testPacing_Yellow_AtApproach() {
        // 46% at 50% elapsed → projected 92% → yellow → 5
        XCTAssertEqual(level(46, elapsed: 0.5), 5)
    }

    func testPacing_Yellow_At100Projected() {
        // 50% at 50% elapsed → projected 100% → yellow → 5
        XCTAssertEqual(level(50, elapsed: 0.5), 5)
    }

    func testPacing_Yellow_At105Projected() {
        // 52% at 50% elapsed → projected 104% → yellow → 5
        XCTAssertEqual(level(52, elapsed: 0.5), 5)
    }

    func testPacing_Orange_JustOver110() {
        // 56% at 50% elapsed → projected 112% → orange → 7
        XCTAssertEqual(level(56, elapsed: 0.5), 7)
    }

    func testPacing_Orange_At140Projected() {
        // 70% at 50% elapsed → projected 140% → orange → 7
        XCTAssertEqual(level(70, elapsed: 0.5), 7)
    }

    func testPacing_Red_Over150() {
        // 80% at 50% elapsed → projected 160% → red → 10
        XCTAssertEqual(level(80, elapsed: 0.5), 10)
    }

    func testPacing_Red_VeryHighProjected() {
        // 100% at 50% elapsed → projected 200% → red → 10
        XCTAssertEqual(level(100, elapsed: 0.5), 10)
    }

    // MARK: - Fallback mode (nil elapsed)

    func testFallback_Green_Low() {
        XCTAssertEqual(level(10, elapsed: nil), 3)
    }

    func testFallback_Green_Mid() {
        XCTAssertEqual(level(70, elapsed: nil), 3)
    }

    func testFallback_Green_UpperBoundary() {
        // 89% → green → 3
        XCTAssertEqual(level(89, elapsed: nil), 3)
    }

    func testFallback_Yellow_At90() {
        XCTAssertEqual(level(90, elapsed: nil), 5)
    }

    func testFallback_Yellow_At100() {
        XCTAssertEqual(level(100, elapsed: nil), 5)
    }

    func testFallback_Orange_At110() {
        XCTAssertEqual(level(110, elapsed: nil), 7)
    }

    func testFallback_Orange_At150() {
        XCTAssertEqual(level(150, elapsed: nil), 7)
    }

    func testFallback_Red_At151() {
        XCTAssertEqual(level(151, elapsed: nil), 10)
    }

    func testFallback_Red_At200() {
        XCTAssertEqual(level(200, elapsed: nil), 10)
    }

    // MARK: - Edge cases

    func testEdge_ZeroUsage_Green() {
        XCTAssertEqual(level(0, elapsed: 0.5), 3)
        XCTAssertEqual(level(0, elapsed: nil), 3)
    }

    func testEdge_ElapsedAt1_FallsBackToRaw() {
        // elapsed=1.0 → session over, raw 80% → green → 3
        XCTAssertEqual(level(80, elapsed: 1.0), 3)
    }

    func testEdge_ZeroElapsed_FallsBackToRaw() {
        // elapsed=0 → guard, raw 60% → green → 3
        XCTAssertEqual(level(60, elapsed: 0.0), 3)
    }

    // MARK: - Zone/level agreement with calculateStatus

    // MARK: - Bash/Swift threshold parity

    /// Verifies the bash statusline script uses the same zone thresholds as
    /// `UsageStatusCalculator.calculateStatus`. A mismatch here means someone
    /// changed the Swift thresholds without updating the bash template (or
    /// vice versa).
    ///
    /// The Swift thresholds are 0.9, 1.1, 1.5 (fractions of full utilization),
    /// which correspond to integer percentages 90, 110, 150 in the bash script.
    func testBashScript_ContainsMatchingThresholds() {
        let script = StatuslineService.shared.bashScript

        // The bash script should contain these comparison patterns twice each
        // (once for pacing mode, once for fallback mode):
        //   -lt 90   → green upper bound   (Swift: ..<0.9)
        //   -lt 110  → yellow upper bound   (Swift: ..<1.1)
        //   -le 150  → orange upper bound   (Swift: ...1.5)

        // Green → yellow boundary at 90
        let lt90Count = script.components(separatedBy: "-lt 90").count - 1
        XCTAssertEqual(lt90Count, 2,
            "Expected '-lt 90' twice (pacing + fallback); found \(lt90Count)")

        // Yellow → orange boundary at 110
        let lt110Count = script.components(separatedBy: "-lt 110").count - 1
        XCTAssertEqual(lt110Count, 2,
            "Expected '-lt 110' twice (pacing + fallback); found \(lt110Count)")

        // Orange → red boundary at 150
        let le150Count = script.components(separatedBy: "-le 150").count - 1
        XCTAssertEqual(le150Count, 2,
            "Expected '-le 150' twice (pacing + fallback); found \(le150Count)")
    }

    // MARK: - Zone/level agreement with calculateStatus

    func testAgreement_Matrix() {
        let scenarios: [(utilization: Int, elapsed: Double?, zone: UsageZone, note: String)] = [
            (20,  0.5,  .green,  "20%@50% → projected 40% → green"),
            (40,  0.5,  .green,  "40%@50% → projected 80% → green"),
            (46,  0.5,  .yellow, "46%@50% → projected 92% → yellow"),
            (50,  0.5,  .yellow, "50%@50% → projected 100% → yellow"),
            (56,  0.5,  .orange, "56%@50% → projected 112% → orange"),
            (80,  0.5,  .red,    "80%@50% → projected 160% → red"),
            (10,  nil,  .green,  "10% fallback → green"),
            (70,  nil,  .green,  "70% fallback → green"),
            (90,  nil,  .yellow, "90% fallback → yellow"),
            (100, nil,  .yellow, "100% fallback → yellow"),
            (110, nil,  .orange, "110% fallback → orange"),
            (150, nil,  .orange, "150% fallback → orange"),
            (151, nil,  .red,    "151% fallback → red"),
        ]

        let expectedLevel: [UsageZone: Int] = [.grey: 3, .green: 3, .yellow: 5, .orange: 7, .red: 10]

        for s in scenarios {
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: Double(s.utilization),
                showRemaining: false,
                elapsedFraction: s.elapsed
            )
            XCTAssertEqual(status.zone, s.zone, s.note)
            XCTAssertEqual(level(s.utilization, elapsed: s.elapsed), expectedLevel[s.zone]!, s.note)
        }
    }
}
