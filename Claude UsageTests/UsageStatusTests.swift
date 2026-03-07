import XCTest
@testable import Claude_Usage

final class UsageStatusTests: XCTestCase {

    // MARK: - UsageZone

    func testUsageZone_Equatable() {
        XCTAssertEqual(UsageZone.green, UsageZone.green)
        XCTAssertNotEqual(UsageZone.green, UsageZone.red)
        XCTAssertNotEqual(UsageZone.yellow, UsageZone.orange)
    }

    // MARK: - UsageStatus

    func testUsageStatus_Equatable() {
        let a = UsageStatus(zone: .green, actionText: "On track ✅")
        let b = UsageStatus(zone: .green, actionText: "On track ✅")
        XCTAssertEqual(a, b)
    }

    func testUsageStatus_NotEqual_DifferentZone() {
        let a = UsageStatus(zone: .green, actionText: "On track ✅")
        let b = UsageStatus(zone: .yellow, actionText: "Maximizing 🔥")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - PacingContext

    func testPacingContext_None_ElapsedNil() {
        XCTAssertNil(PacingContext.none.elapsedFraction)
    }

    func testPacingContext_Equatable() {
        let a = PacingContext(elapsedFraction: 0.5)
        let b = PacingContext(elapsedFraction: 0.5)
        XCTAssertEqual(a, b)
    }

    func testPacingContext_NotEqual_DifferentElapsed() {
        let a = PacingContext(elapsedFraction: 0.3)
        let b = PacingContext(elapsedFraction: 0.6)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SessionRecord / WeeklyRecord Codable (dormant history types)

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
