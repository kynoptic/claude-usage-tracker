import XCTest
@testable import Claude_Usage

final class BoundaryDetectorTests: XCTestCase {

    // MARK: - Helpers

    private func usage(
        sessionPct: Double = 50.0,
        sessionLimit: Int = 100_000,
        sessionResetTime: Date = Date().addingTimeInterval(3_600),
        weeklyPct: Double = 30.0,
        weeklyLimit: Int = 1_000_000,
        weeklyResetTime: Date = Date().addingTimeInterval(86_400),
        lastUpdated: Date = Date()
    ) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPct) * sessionLimit / 100,
            sessionLimit: sessionLimit,
            sessionPercentage: sessionPct,
            sessionResetTime: sessionResetTime,
            weeklyTokensUsed: Int(weeklyPct) * weeklyLimit / 100,
            weeklyLimit: weeklyLimit,
            weeklyPercentage: weeklyPct,
            weeklyResetTime: weeklyResetTime,
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: lastUpdated,
            userTimezone: .current
        )
    }

    // MARK: - Session: No previous

    func testSession_NoPrevious_ReturnsNil() {
        let current = usage(sessionPct: 50)
        XCTAssertNil(BoundaryDetector.detectSession(previous: nil, current: current))
    }

    // MARK: - Session: ResetTime advance (primary detection)

    func testSession_ResetTimeAdvanced_DetectsAndRecordsPreviousPct() {
        let oldReset = Date().addingTimeInterval(0)
        let newReset = Date().addingTimeInterval(3_600)
        let prev = usage(sessionPct: 78.0, sessionLimit: 100_000, sessionResetTime: oldReset)
        let curr = usage(sessionPct: 5.0,  sessionLimit: 100_000, sessionResetTime: newReset)

        let record = BoundaryDetector.detectSession(previous: prev, current: curr)
        XCTAssertNotNil(record)
        XCTAssertEqual(record!.finalPercentage, 78.0)
        XCTAssertEqual(record!.sessionLimit, 100_000)
    }

    func testSession_SameResetTime_NoDetection() {
        let reset = Date().addingTimeInterval(3_600)
        let prev = usage(sessionPct: 50.0, sessionResetTime: reset)
        let curr = usage(sessionPct: 55.0, sessionResetTime: reset)
        XCTAssertNil(BoundaryDetector.detectSession(previous: prev, current: curr))
    }

    // MARK: - Session: Large drop fallback

    func testSession_LargeDrop_26pp_DetectsSession() {
        let reset = Date().addingTimeInterval(3_600)
        let prev = usage(sessionPct: 80.0, sessionResetTime: reset)
        let curr = usage(sessionPct: 54.0, sessionResetTime: reset)

        let record = BoundaryDetector.detectSession(previous: prev, current: curr)
        XCTAssertNotNil(record)
        XCTAssertEqual(record!.finalPercentage, 80.0)
    }

    func testSession_SmallDrop_24pp_NoDetection() {
        let reset = Date().addingTimeInterval(3_600)
        let prev = usage(sessionPct: 70.0, sessionResetTime: reset)
        let curr = usage(sessionPct: 46.0, sessionResetTime: reset)
        XCTAssertNil(BoundaryDetector.detectSession(previous: prev, current: curr))
    }

    func testSession_ExactlyAt25pp_NoDetection() {
        let reset = Date().addingTimeInterval(3_600)
        let prev = usage(sessionPct: 75.0, sessionResetTime: reset)
        let curr = usage(sessionPct: 50.0, sessionResetTime: reset)
        XCTAssertNil(BoundaryDetector.detectSession(previous: prev, current: curr))
    }

    // MARK: - Weekly: No previous

    func testWeekly_NoPrevious_ReturnsNil() {
        let current = usage(weeklyPct: 50)
        XCTAssertNil(BoundaryDetector.detectWeekly(previous: nil, current: current))
    }

    // MARK: - Weekly: ResetTime advance

    func testWeekly_ResetTimeAdvanced_DetectsAndRecordsPreviousPct() {
        let oldReset = Date().addingTimeInterval(0)
        let newReset = Date().addingTimeInterval(86_400)
        let prev = usage(weeklyPct: 92.0, weeklyLimit: 1_000_000, weeklyResetTime: oldReset)
        let curr = usage(weeklyPct: 3.0,  weeklyLimit: 1_000_000, weeklyResetTime: newReset)

        let record = BoundaryDetector.detectWeekly(previous: prev, current: curr)
        XCTAssertNotNil(record)
        XCTAssertEqual(record!.finalPercentage, 92.0)
        XCTAssertEqual(record!.weeklyLimit, 1_000_000)
        XCTAssertFalse(record!.planChangedDuringPeriod)
    }

    func testWeekly_SameResetTime_NoDetection() {
        let reset = Date().addingTimeInterval(86_400)
        let prev = usage(weeklyPct: 50.0, weeklyResetTime: reset)
        let curr = usage(weeklyPct: 55.0, weeklyResetTime: reset)
        XCTAssertNil(BoundaryDetector.detectWeekly(previous: prev, current: curr))
    }

    // MARK: - Weekly: Large drop fallback

    func testWeekly_LargeDrop_26pp_DetectsWeekly() {
        let reset = Date().addingTimeInterval(86_400)
        let prev = usage(weeklyPct: 80.0, weeklyResetTime: reset)
        let curr = usage(weeklyPct: 54.0, weeklyResetTime: reset)

        let record = BoundaryDetector.detectWeekly(previous: prev, current: curr)
        XCTAssertNotNil(record)
        XCTAssertEqual(record!.finalPercentage, 80.0)
    }

    func testWeekly_SmallDrop_24pp_NoDetection() {
        let reset = Date().addingTimeInterval(86_400)
        let prev = usage(weeklyPct: 70.0, weeklyResetTime: reset)
        let curr = usage(weeklyPct: 46.0, weeklyResetTime: reset)
        XCTAssertNil(BoundaryDetector.detectWeekly(previous: prev, current: curr))
    }
}
