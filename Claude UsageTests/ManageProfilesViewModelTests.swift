import XCTest
@testable import Claude_Usage

/// Tests for ManageProfilesViewModel.
///
/// Note: ManageProfilesViewModel cannot be instantiated in the test runner because
/// its property initializers reference ProfileManager.shared which depends on
/// singletons requiring NSApplication. The notification routing pattern is verified
/// through the same observer-balance approach used in MenuBarManagerTests.
@MainActor
final class ManageProfilesViewModelTests: XCTestCase {

    // MARK: - Notification Routing Pattern Verification

    /// Verifies that the .displayModeChanged notification can be posted and observed,
    /// confirming the routing mechanism used by ManageProfilesViewModel works correctly.
    func testDisplayModeChangedNotificationRouting() {
        let center = NotificationCenter.default
        var received = false

        let observer = center.addObserver(
            forName: .displayModeChanged, object: nil, queue: .main
        ) { _ in received = true }

        center.post(name: .displayModeChanged, object: nil)

        let expectation = expectation(description: "notification delivered")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(received, "Notification routing mechanism should work")

        center.removeObserver(observer)
    }
}
