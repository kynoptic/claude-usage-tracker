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
        DataStore.shared.saveShowGreyZone(false)
        DataStore.shared.saveGreyThreshold(Constants.greyThresholdDefault)
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

        DataStore.shared.saveShowGreyZone(true)
        sut.reload()

        XCTAssertTrue(sut.showGreyZone)
    }

    func testReload_UpdatesShowGreyZone_ToFalse() {
        DataStore.shared.saveShowGreyZone(true)
        sut.reload()
        XCTAssertTrue(sut.showGreyZone, "precondition: starts true")

        DataStore.shared.saveShowGreyZone(false)
        sut.reload()

        XCTAssertFalse(sut.showGreyZone)
    }

    func testReload_UpdatesGreyThreshold() {
        XCTAssertEqual(sut.greyThreshold, Constants.greyThresholdDefault, accuracy: 0.001)

        DataStore.shared.saveGreyThreshold(0.6)
        sut.reload()

        XCTAssertEqual(sut.greyThreshold, 0.6, accuracy: 0.001)
    }

    func testReload_ClampsGreyThreshold_ToMinimum() {
        DataStore.shared.saveGreyThreshold(0.1)
        sut.reload()

        XCTAssertEqual(sut.greyThreshold, 0.1, accuracy: 0.001)
    }
}
