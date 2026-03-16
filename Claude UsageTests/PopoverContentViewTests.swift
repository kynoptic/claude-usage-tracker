import XCTest
@testable import Claude_Usage

final class PopoverContentViewTests: XCTestCase {

    // MARK: - countdownText

    func testCountdownText_MoreThanOneMinute_FormatsMinutesAndSeconds() {
        let now = Date()
        let date = now.addingTimeInterval(150) // 2m 30s
        XCTAssertEqual(
            SmartUsageDashboardViewModel.countdownText(until: date, now: now),
            "Rate limited — retrying in 2m 30s"
        )
    }

    func testCountdownText_ExactlyOneMinute_FormatsAsOneMinuteZeroSeconds() {
        let now = Date()
        let date = now.addingTimeInterval(60)
        XCTAssertEqual(
            SmartUsageDashboardViewModel.countdownText(until: date, now: now),
            "Rate limited — retrying in 1m 0s"
        )
    }

    func testCountdownText_FiftyNineSeconds_FormatsAsSeconds() {
        let now = Date()
        let date = now.addingTimeInterval(59)
        XCTAssertEqual(
            SmartUsageDashboardViewModel.countdownText(until: date, now: now),
            "Rate limited — retrying in 59s"
        )
    }

    func testCountdownText_ZeroRemaining_ReturnsRetryingNow() {
        let now = Date()
        XCTAssertEqual(
            SmartUsageDashboardViewModel.countdownText(until: now, now: now),
            "Rate limited — retrying now…"
        )
    }

    func testCountdownText_PastDate_ReturnsRetryingNow() {
        let now = Date()
        let past = now.addingTimeInterval(-5)
        XCTAssertEqual(
            SmartUsageDashboardViewModel.countdownText(until: past, now: now),
            "Rate limited — retrying now…"
        )
    }
}
