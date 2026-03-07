import XCTest
@testable import Claude_Usage

final class UsageStatusTests: XCTestCase {

    // MARK: - UsageZone

    func testUsageZone_Equatable() {
        XCTAssertEqual(UsageZone.green, UsageZone.green)
        XCTAssertNotEqual(UsageZone.green, UsageZone.critical)
        XCTAssertNotEqual(UsageZone.approach, UsageZone.warning)
    }

    func testUsageZone_asLegacyLevel_GreenIsSafe() {
        XCTAssertEqual(UsageZone.green.asLegacyLevel(), .safe)
    }

    func testUsageZone_asLegacyLevel_ApproachIsSafe() {
        XCTAssertEqual(UsageZone.approach.asLegacyLevel(), .safe)
    }

    func testUsageZone_asLegacyLevel_WarningIsModerate() {
        XCTAssertEqual(UsageZone.warning.asLegacyLevel(), .moderate)
    }

    func testUsageZone_asLegacyLevel_CriticalIsCritical() {
        XCTAssertEqual(UsageZone.critical.asLegacyLevel(), .critical)
    }

    // MARK: - UsageStatus

    func testUsageStatus_Equatable() {
        let a = UsageStatus(zone: .green, severity: 0.2, actionText: "On track ✅")
        let b = UsageStatus(zone: .green, severity: 0.2, actionText: "On track ✅")
        XCTAssertEqual(a, b)
    }

    func testUsageStatus_NotEqual_DifferentSeverity() {
        let a = UsageStatus(zone: .green, severity: 0.2, actionText: "On track ✅")
        let b = UsageStatus(zone: .green, severity: 0.3, actionText: "On track ✅")
        XCTAssertNotEqual(a, b)
    }

    func testUsageStatus_SeverityInRange() {
        let status = UsageStatus(zone: .approach, severity: 0.45, actionText: "Maximizing usage 🔥")
        XCTAssertGreaterThanOrEqual(status.severity, 0.0)
        XCTAssertLessThanOrEqual(status.severity, 1.0)
    }

    // MARK: - PacingContext

    func testPacingContext_None_AllNil() {
        let ctx = PacingContext.none
        XCTAssertNil(ctx.elapsedFraction)
        XCTAssertNil(ctx.weeklyProjected)
        XCTAssertNil(ctx.avgSessionUtilization)
        XCTAssertEqual(ctx.sessionCount, 0)
    }

    func testPacingContext_Equatable() {
        let a = PacingContext(elapsedFraction: 0.5, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        let b = PacingContext(elapsedFraction: 0.5, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        XCTAssertEqual(a, b)
    }

    func testPacingContext_SessionCount() {
        let ctx = PacingContext(elapsedFraction: 0.3, weeklyProjected: 0.85, avgSessionUtilization: 0.75, sessionCount: 10)
        XCTAssertEqual(ctx.sessionCount, 10)
    }

    func testPacingContext_NotEqual_DifferentElapsed() {
        let a = PacingContext(elapsedFraction: 0.3, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        let b = PacingContext(elapsedFraction: 0.6, weeklyProjected: nil, avgSessionUtilization: nil, sessionCount: 0)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SessionRecord / WeeklyRecord Codable

    func testSessionRecord_Codable() throws {
        let record = SessionRecord(endedAt: Date(timeIntervalSince1970: 1_000_000), finalPercentage: 85.0, sessionLimit: 100_000)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(SessionRecord.self, from: data)
        XCTAssertEqual(decoded.finalPercentage, 85.0)
        XCTAssertEqual(decoded.sessionLimit, 100_000)
    }

    func testWeeklyRecord_Codable() throws {
        let record = WeeklyRecord(endedAt: Date(timeIntervalSince1970: 2_000_000), finalPercentage: 72.5, weeklyLimit: 1_000_000, planChangedDuringPeriod: false)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(WeeklyRecord.self, from: data)
        XCTAssertEqual(decoded.finalPercentage, 72.5)
        XCTAssertEqual(decoded.weeklyLimit, 1_000_000)
        XCTAssertFalse(decoded.planChangedDuringPeriod)
    }
}
