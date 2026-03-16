import XCTest
@testable import Claude_Usage

@MainActor
final class SmartUsageDashboardViewModelTests: XCTestCase {

    // MARK: - Properties

    var sut: SmartUsageDashboardViewModel!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Reset DataStore to known defaults before each test
        DataStore.shared.saveAPITrackingEnabled(false)
        AppearanceStore.shared.saveShowGreyZone(false)
        AppearanceStore.shared.saveGreyThreshold(Constants.greyThresholdDefault)
        sut = SmartUsageDashboardViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State reflects DataStore at init time

    func testInit_DefaultAPITrackingEnabled_IsFalse() {
        // DataStore was set to false in setUp before sut was created
        XCTAssertFalse(sut.isAPITrackingEnabled)
    }

    func testInit_DefaultShowGreyZone_IsFalse() {
        XCTAssertFalse(sut.showGreyZone)
    }

    func testInit_DefaultGreyThreshold_EqualsConstant() {
        XCTAssertEqual(sut.greyThreshold, Constants.greyThresholdDefault, accuracy: 0.001)
    }

    // MARK: - reload() picks up DataStore changes

    func testReload_UpdatesIsAPITrackingEnabled_ToTrue() {
        XCTAssertFalse(sut.isAPITrackingEnabled, "precondition: starts false")

        DataStore.shared.saveAPITrackingEnabled(true)
        sut.reload()

        XCTAssertTrue(sut.isAPITrackingEnabled)
    }

    func testReload_UpdatesIsAPITrackingEnabled_ToFalse() {
        DataStore.shared.saveAPITrackingEnabled(true)
        sut.reload()
        XCTAssertTrue(sut.isAPITrackingEnabled, "precondition: starts true")

        DataStore.shared.saveAPITrackingEnabled(false)
        sut.reload()

        XCTAssertFalse(sut.isAPITrackingEnabled)
    }

    func testReload_UpdatesShowGreyZone_ToTrue() {
        XCTAssertFalse(sut.showGreyZone, "precondition: starts false")

        AppearanceStore.shared.saveShowGreyZone(true)
        sut.reload()

        XCTAssertTrue(sut.showGreyZone)
    }

    func testReload_UpdatesShowGreyZone_ToFalse() {
        AppearanceStore.shared.saveShowGreyZone(true)
        sut.reload()
        XCTAssertTrue(sut.showGreyZone, "precondition: starts true")

        AppearanceStore.shared.saveShowGreyZone(false)
        sut.reload()

        XCTAssertFalse(sut.showGreyZone)
    }

    func testReload_UpdatesGreyThreshold() {
        XCTAssertEqual(sut.greyThreshold, Constants.greyThresholdDefault, accuracy: 0.001)

        AppearanceStore.shared.saveGreyThreshold(0.6)
        sut.reload()

        XCTAssertEqual(sut.greyThreshold, 0.6, accuracy: 0.001)
    }

    func testReload_ClampsGreyThreshold_ToMinimum() {
        AppearanceStore.shared.saveGreyThreshold(0.1)
        sut.reload()

        XCTAssertEqual(sut.greyThreshold, 0.1, accuracy: 0.001)
    }

    // MARK: - stalenessLabel(lastSuccessfulFetch:at:)

    func testStalenessLabel_NilFetch_ReturnsNoDataYet() {
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: nil, at: Date())
        XCTAssertEqual(result, "No data yet")
    }

    func testStalenessLabel_Under60Seconds_ReturnsJustNow() {
        let now = Date()
        let fetch = now.addingTimeInterval(-30)
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: fetch, at: now)
        XCTAssertEqual(result, "Updated just now")
    }

    func testStalenessLabel_FiveMinutesAgo_ReturnsMinutes() {
        let now = Date()
        let fetch = now.addingTimeInterval(-300)
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: fetch, at: now)
        XCTAssertEqual(result, "Updated 5m ago")
    }

    func testStalenessLabel_TwoHoursAgo_ReturnsHours() {
        let now = Date()
        let fetch = now.addingTimeInterval(-7200)
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: fetch, at: now)
        XCTAssertEqual(result, "Updated 2h ago")
    }

    func testStalenessLabel_ExactlyOneMinute_ReturnsMinutes() {
        let now = Date()
        let fetch = now.addingTimeInterval(-60)
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: fetch, at: now)
        XCTAssertEqual(result, "Updated 1m ago")
    }

    func testStalenessLabel_ExactlyOneHour_ReturnsHours() {
        let now = Date()
        let fetch = now.addingTimeInterval(-3600)
        let result = SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: fetch, at: now)
        XCTAssertEqual(result, "Updated 1h ago")
    }

    // MARK: - errorBannerText(for:)

    func testErrorBannerText_NilError_ReturnsNil() {
        let result = SmartUsageDashboardViewModel.errorBannerText(for: nil)
        XCTAssertNil(result)
    }

    func testErrorBannerText_RateLimited_ReturnsNil() {
        let error = AppError(code: .apiRateLimited, message: "Rate limited")
        let result = SmartUsageDashboardViewModel.errorBannerText(for: error)
        XCTAssertNil(result)
    }

    func testErrorBannerText_Unauthorized_ReturnsAuthExpired() {
        let error = AppError(code: .apiUnauthorized, message: "Unauthorized")
        let result = SmartUsageDashboardViewModel.errorBannerText(for: error)
        XCTAssertEqual(result, "Auth expired — re-sync in Settings")
    }

    func testErrorBannerText_SessionKeyNotFound_ReturnsNoCredentials() {
        let error = AppError(code: .sessionKeyNotFound, message: "Not found")
        let result = SmartUsageDashboardViewModel.errorBannerText(for: error)
        XCTAssertEqual(result, "No credentials — configure in Settings")
    }

    func testErrorBannerText_GenericError_ReturnsMessage() {
        let error = AppError(code: .networkUnavailable, message: "Network down")
        let result = SmartUsageDashboardViewModel.errorBannerText(for: error)
        XCTAssertEqual(result, "Network down")
    }

    // MARK: - countdownText(until:now:)

    func testCountdownText_ZeroRemaining_ReturnsRetryingNow() {
        let now = Date()
        let result = SmartUsageDashboardViewModel.countdownText(until: now, now: now)
        XCTAssertEqual(result, "Rate limited — retrying now…")
    }

    func testCountdownText_PastDate_ReturnsRetryingNow() {
        let now = Date()
        let past = now.addingTimeInterval(-10)
        let result = SmartUsageDashboardViewModel.countdownText(until: past, now: now)
        XCTAssertEqual(result, "Rate limited — retrying now…")
    }

    func testCountdownText_30Seconds_ReturnsSeconds() {
        let now = Date()
        let future = now.addingTimeInterval(30)
        let result = SmartUsageDashboardViewModel.countdownText(until: future, now: now)
        XCTAssertEqual(result, "Rate limited — retrying in 30s")
    }

    func testCountdownText_90Seconds_ReturnsMinutesAndSeconds() {
        let now = Date()
        let future = now.addingTimeInterval(90)
        let result = SmartUsageDashboardViewModel.countdownText(until: future, now: now)
        XCTAssertEqual(result, "Rate limited — retrying in 1m 30s")
    }

    func testCountdownText_ExactlyOneMinute_ReturnsMinutesAndZeroSeconds() {
        let now = Date()
        let future = now.addingTimeInterval(60)
        let result = SmartUsageDashboardViewModel.countdownText(until: future, now: now)
        XCTAssertEqual(result, "Rate limited — retrying in 1m 0s")
    }
}
