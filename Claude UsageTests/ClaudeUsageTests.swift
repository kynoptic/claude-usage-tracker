import XCTest
@testable import Claude_Usage

final class ClaudeUsageTests: XCTestCase {

    // MARK: - Empty Usage Tests

    func testEmptyUsage() {
        let empty = ClaudeUsage.empty
        XCTAssertEqual(empty.sessionTokensUsed, 0)
        XCTAssertEqual(empty.sessionPercentage, 0)
        XCTAssertEqual(empty.weeklyTokensUsed, 0)
        XCTAssertEqual(empty.weeklyPercentage, 0)
        XCTAssertNil(empty.costUsed)
        XCTAssertNil(empty.costLimit)
    }

    // MARK: - Remaining Percentage

    func testRemainingPercentage() {
        XCTAssertEqual(createUsage(sessionPercentage: 0).remainingPercentage, 100.0)
        XCTAssertEqual(createUsage(sessionPercentage: 60).remainingPercentage, 40.0)
        XCTAssertEqual(createUsage(sessionPercentage: 100).remainingPercentage, 0.0)
    }

    // MARK: - Codable

    func testEncodeDecode() throws {
        let original = createUsage(sessionPercentage: 45.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClaudeUsage.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Helpers

    private func createUsage(sessionPercentage: Double) -> ClaudeUsage {
        ClaudeUsage(
            sessionTokensUsed: Int(sessionPercentage * 1000),
            sessionLimit: 100000,
            sessionPercentage: sessionPercentage,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 500000,
            weeklyLimit: 1000000,
            weeklyPercentage: 50,
            weeklyResetTime: Date().addingTimeInterval(86400),
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
}
